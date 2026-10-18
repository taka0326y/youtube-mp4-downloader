import AppKit
import Foundation
import Darwin

struct DownloadOptions {
    let height: Int
    let folder: String
    var section: String? = nil
    func arguments(url: String, hls: Bool, ffmpeg: String) -> [String] {
        let p = hls ? "[protocol^=m3u8]" : ""
        let audio = hls ? "ba\(p)" : "ba[ext=m4a]"
        let format = "bv[height<=\(height)][ext=mp4][vcodec^=avc1]\(p)+\(audio)/b[height<=\(height)][ext=mp4]\(p)/bv[height<=\(height)][ext=mp4]\(p)+\(audio)"
        var a = ["--ignore-config", "--no-playlist", "--newline", "--no-color", "--no-overwrites", "--socket-timeout", "20", "--retries", "2", "--fragment-retries", "2", "--abort-on-unavailable-fragments", "--ffmpeg-location", ffmpeg, "-f", format, "--merge-output-format", "mp4", "--remux-video", "mp4", "--print", "after_move:保存完了: %(filepath)s", "--progress", "--progress-delta", "0.25", "--print", "before_dl:__PLAN__%(format_id)s", "--print", "post_process:__MERGE__%(id)s", "--progress-template", "download:__PROGRESS__%(info.format_id)s\t%(progress.status)s\t%(progress.downloaded_bytes)s\t%(progress.total_bytes)s\t%(progress.total_bytes_estimate)s\t%(progress.fragment_index)s\t%(progress.fragment_count)s\t%(progress._percent_str)s", "-P", folder, "-o", "%(title).150B [%(id)s].%(ext)s"]
        if let node=findNode() { a += ["--js-runtimes", "node:"+node] }
        if let section = section { a += ["--download-sections", section] }
        return a + ["--", url]
    }
}
func validURLs(_ text: String) throws -> [String] {
    let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    guard !lines.isEmpty else { throw NSError(domain: "URLを入力してください。", code: 1) }
    for line in lines {
        guard let u = URLComponents(string: line), ["https", "http"].contains(u.scheme ?? ""), let host = u.host?.lowercased(), ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be"].contains(host) else {
            throw NSError(domain: "YouTubeのURLを1行に1つ入力してください: \(line)", code: 2)
        }
    }
    return Array(NSOrderedSet(array: lines)) as! [String]
}
func signalTree(_ pid: Int32, signal: Int32) {
    let ps = Process(), pipe = Pipe(); ps.executableURL = URL(fileURLWithPath:"/bin/ps"); ps.arguments = ["-axo","pid=,ppid="]; ps.standardOutput = pipe
    var children: [Int32:[Int32]] = [:]
    if (try? ps.run()) != nil { let data = pipe.fileHandleForReading.readDataToEndOfFile(); ps.waitUntilExit(); for line in String(decoding:data,as:UTF8.self).split(separator:"\n") { let v=line.split(whereSeparator: { $0.isWhitespace }).compactMap { Int32($0) }; if v.count == 2 { children[v[1],default:[]].append(v[0]) } } }
    func send(_ id:Int32) { for child in children[id] ?? [] { send(child) }; kill(id,signal) }
    send(pid)
}
final class Downloader {
    private let lock = NSLock()
    private var active: Process?
    private var stopped = false
    let tool: String
    let ffmpeg: String
    init(tool: String, ffmpeg: String) { self.tool = tool; self.ffmpeg = ffmpeg }
    func cancel() {
        lock.lock(); stopped = true; let p = active; lock.unlock()
        if let p = p, p.isRunning {
            signalTree(p.processIdentifier, signal: SIGINT)
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                if p.isRunning { signalTree(p.processIdentifier, signal: SIGTERM) }
            }
        }
    }
    var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func run(urls: [String], options: DownloadOptions, progress: @escaping (BatchProgress) -> Void = { _ in }, report: @escaping (String) -> Void) -> (Int, Int) {
        var success = 0, failures = 0
        for (index,url) in urls.enumerated() {
            if cancelled { break }
            report("\n［\(index+1)/\(urls.count)］\(url)")
            var result: Int32 = 1
            var tracker=VideoProgress()
            func update() { progress(BatchProgress(index:index+1,total:urls.count,current:tracker.fraction,processed:success+failures,saved:success,failed:failures,phase:tracker.phase)) }
            func consume(_ line:String) { if ProcessInfo.processInfo.environment["TEST_TRACE_PROGRESS"] == "1" && line.hasPrefix("__") { report(line) }; if tracker.consume(line) { update() } else { report(line) } }
            update()
            for hls in (ProcessInfo.processInfo.environment["TEST_HLS_ONLY"] == "1" ? [true] : [false,true]) {
                if cancelled { break }
                if hls { report("別の配信方式で再試行しています…") }
                let p = Process(), pipe = Pipe()
                p.executableURL = URL(fileURLWithPath: tool)
                p.arguments = options.arguments(url: url, hls: hls, ffmpeg: ffmpeg)
                p.standardOutput = pipe; p.standardError = pipe
                var environment = ProcessInfo.processInfo.environment
                environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
                p.environment = environment
                lock.lock(); active = p; let shouldStop = stopped; lock.unlock()
                if shouldStop { break }
                do {
                    try p.run()
                    if cancelled { p.interrupt() }
                    var buffer = Data()
                    while true {
                        let data = pipe.fileHandleForReading.availableData
                        if data.isEmpty { break }
                        buffer.append(data)
                        while let range = buffer.range(of: Data([10])) {
                            let line = String(decoding: buffer[..<range.lowerBound], as: UTF8.self)
                            buffer.removeSubrange(..<range.upperBound); consume(line)
                        }
                    }
                    if !buffer.isEmpty { consume(String(decoding: buffer, as: UTF8.self)) }
                    p.waitUntilExit(); result = p.terminationStatus
                } catch { report("起動エラー: \(error.localizedDescription)") }
                lock.lock(); active = nil; lock.unlock()
                if result == 0 { break }
            }
            if cancelled { break }
            if result == 0 { success += 1 } else { failures += 1; report("この動画は保存できませんでした。次へ進みます。") }
            progress(BatchProgress(index:index+1,total:urls.count,current:result == 0 ? 1:tracker.fraction,processed:success+failures,saved:success,failed:failures,phase:result == 0 ? "保存完了" : "取得失敗・次の動画へ進みます"))
        }
        return (success, failures)
    }
}
final class App: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let input = NSTextView(), log = NSTextView(), quality = NSPopUpButton(), status = NSTextField(labelWithString: "URLを貼り付けて開始してください")
    let path = NSTextField(labelWithString: ""), progress = NSProgressIndicator(), batchBar=NSProgressIndicator()
    let currentLabel=NSTextField(labelWithString:"現在の動画 0%"), batchLabel=NSTextField(labelWithString:"全体 0% — 処理済み0/0件"), elapsedLabel=NSTextField(labelWithString:"経過時間 0分00秒")
    var timer:Timer?, startedAt:TimeInterval?
    var start: NSButton!, stop: NSButton!, choose: NSButton!
    var downloader: Downloader?
    var quitting = false
    private var completionSound:NSSound?
    private lazy var completionCue=CompletionCue { [weak self] in
        guard let self=self else { return false }
        if self.completionSound==nil { self.completionSound=NSSound(contentsOfFile:Bundle.main.resourcePath!+"/completion-marimba.wav",byReference:false) }
        return self.completionSound?.play() ?? false
    }
    var folder = UserDefaults.standard.string(forKey: "folder") ?? NSHomeDirectory()+"/Downloads"
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x:0,y:0,width:780,height:820), styleMask:[.titled,.closable,.miniaturizable,.resizable], backing:.buffered,defer:false)
        window.title = "YouTube MP4 Downloader"; window.minSize = NSSize(width:650,height:740)
        let root = NSStackView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 14; root.edgeInsets = NSEdgeInsets(top:24,left:24,bottom:24,right:24)
        root.translatesAutoresizingMaskIntoConstraints = false; window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor),root.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor),root.topAnchor.constraint(equalTo:window.contentView!.topAnchor),root.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor)])
        let title = NSTextField(labelWithString:"動画を、MP4で保存。"); title.font = .systemFont(ofSize:27,weight:.bold); root.addArrangedSubview(title)
        let subtitle = NSTextField(labelWithString:"YouTubeのURLを1行に1つ。複数の動画も順番にダウンロードします。"); subtitle.textColor = .secondaryLabelColor; root.addArrangedSubview(subtitle)
        root.addArrangedSubview(NSTextField(labelWithString:"動画のURL"))
        let urls = scroll(input); urls.heightAnchor.constraint(equalToConstant:120).isActive = true; root.addArrangedSubview(urls)
        input.font = .systemFont(ofSize:14); input.isAutomaticQuoteSubstitutionEnabled = false; input.isRichText = false
        quality.addItems(withTitles:VideoQuality.choices.map(\.title))
        let row = NSStackView(views:[NSTextField(labelWithString:"画質"),quality]); row.spacing=12; root.addArrangedSubview(row)
        root.addArrangedSubview(NSTextField(labelWithString:"指定した画質以下で、利用できる最高画質を保存します。"))
        path.stringValue = folder; path.lineBreakMode = .byTruncatingMiddle
        choose = NSButton(title:"保存先を選ぶ…",target:self,action:#selector(selectFolder))
        let location = NSStackView(views:[path,choose]); location.spacing=10; root.addArrangedSubview(location)
        start = NSButton(title:"ダウンロード開始",target:self,action:#selector(begin)); start.bezelStyle = .rounded; start.keyEquivalent = "\r"
        stop = NSButton(title:"中止",target:self,action:#selector(cancel)); stop.isEnabled = false
        let open = NSButton(title:"保存フォルダを開く",target:self,action:#selector(openFolder)); open.bezelStyle = .rounded
        let actions = NSStackView(views:[start,stop,open]); actions.spacing=12; root.addArrangedSubview(actions)
        for bar in [progress,batchBar] { bar.style = .bar; bar.isIndeterminate=false; bar.minValue=0; bar.maxValue=100; bar.doubleValue=0; bar.isDisplayedWhenStopped=true }
        currentLabel.font = .systemFont(ofSize:13,weight:.semibold); batchLabel.font = .systemFont(ofSize:13,weight:.semibold)
        root.addArrangedSubview(currentLabel); root.addArrangedSubview(progress)
        root.addArrangedSubview(batchLabel); root.addArrangedSubview(batchBar)
        let note=NSTextField(labelWithString:"進捗は目安です。全体は件数基準で、失敗も処理済みに含みます。"); note.font = .systemFont(ofSize:11); note.textColor = .secondaryLabelColor; root.addArrangedSubview(note)
        elapsedLabel.font = .monospacedDigitSystemFont(ofSize:13,weight:.medium); root.addArrangedSubview(elapsedLabel)
        root.addArrangedSubview(status)
        log.isEditable = false; log.font = .monospacedSystemFont(ofSize:11,weight:.regular); log.isRichText = false
        let logs = scroll(log); logs.heightAnchor.constraint(greaterThanOrEqualToConstant:140).isActive=true; root.addArrangedSubview(logs)
        for view in [urls,location,logs,progress,batchBar] { view.widthAnchor.constraint(equalTo:root.widthAnchor,constant:-48).isActive=true }
        if let icon=NSImage(contentsOfFile:Bundle.main.resourcePath!+"/AppIcon.icns") { NSApp.applicationIconImage=icon }
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        if CommandLine.arguments.contains("--preview-progress") {
            input.string="https://youtu.be/4D5rVl-H2Qc\nhttps://youtu.be/another-video"
            startedAt=ProcessInfo.processInfo.systemUptime-93
            show(BatchProgress(index:2,total:3,current:0.64,processed:1,saved:1,failed:0,phase:"映像・音声をダウンロードしています…")); updateElapsed()
        }
        if CommandLine.arguments.contains("--test-gui-download") { input.string="https://youtu.be/4D5rVl-H2Qc"; folder=ProcessInfo.processInfo.environment["TEST_GUI_FOLDER"]!; path.stringValue=folder; quality.selectItem(at:2); begin() }
        if CommandLine.arguments.contains("--test-gui-quit") { input.string="https://youtu.be/4D5rVl-H2Qc"; folder=NSHomeDirectory()+"/Downloads"; begin(); DispatchQueue.main.asyncAfter(deadline:.now()+5) { NSApp.terminate(nil) } }
    }
    func scroll(_ text: NSTextView) -> NSScrollView {
        let s = NSScrollView(); s.hasVerticalScroller = true; s.borderType = .bezelBorder; s.documentView = text
        text.frame=NSRect(x:0,y:0,width:600,height:120); text.minSize=NSSize(width:0,height:120); text.isVerticallyResizable=true; text.isHorizontallyResizable=false; text.autoresizingMask=[.width]; text.textContainer?.widthTracksTextView=true
        return s
    }
    @objc func selectFolder() { let p = NSOpenPanel(); p.canChooseDirectories=true; p.canChooseFiles=false; p.canCreateDirectories=true; p.directoryURL=URL(fileURLWithPath:folder); if p.runModal() == .OK, let url=p.url { folder=url.path; path.stringValue=folder; UserDefaults.standard.set(folder,forKey:"folder") } }
    @objc func openFolder() { NSWorkspace.shared.open(URL(fileURLWithPath:folder)) }
    @objc func cancel() { downloader?.cancel(); status.stringValue="中止しています…"; stop.isEnabled=false }
    func append(_ line:String) { log.textStorage?.append(NSAttributedString(string:line+"\n")); if log.string.count > 90000 { log.textStorage?.deleteCharacters(in:NSRange(location:0,length:30000)) }; log.scrollToEndOfDocument(nil); if line.contains("[download]") { status.stringValue=String(line.prefix(110)) } }
    func show(_ value:BatchProgress) {
        progress.doubleValue=value.current*100; batchBar.doubleValue=value.overall*100
        currentLabel.stringValue="現在の動画 \(value.index)/\(value.total) — \(Int(value.current*100))%"+(value.current<1 ? "（目安）":"・保存完了")
        batchLabel.stringValue="全体 \(Int(value.overall*100))% — 処理済み\(value.processed)/\(value.total)件（保存\(value.saved)・失敗\(value.failed)）"
        status.stringValue=value.phase
    }
    func updateElapsed() { if let began=startedAt { elapsedLabel.stringValue="経過時間 "+elapsedText(ProcessInfo.processInfo.systemUptime-began) } }
    @objc func begin() {
        do {
            let urls = try validURLs(input.string)
            try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
            guard FileManager.default.isWritableFile(atPath:folder) else { throw NSError(domain:"保存先に書き込めません。",code:3) }
            let ffmpeg = findFFmpeg()
            guard let ffmpeg = ffmpeg else { throw NSError(domain:"ffmpegが見つかりません。Homebrewでffmpegをインストールしてください。",code:4) }
            let d = Downloader(tool:Bundle.main.resourcePath!+"/yt-dlp",ffmpeg:ffmpeg); downloader=d
            var opts=DownloadOptions(height:VideoQuality.height(at:quality.indexOfSelectedItem),folder:folder)
            if CommandLine.arguments.contains("--test-gui-download") { opts.section="*0-5" }
            completionCue.reset()
            log.string=""; start.isEnabled=false; stop.isEnabled=true; choose.isEnabled=false; quality.isEnabled=false; input.isEditable=false; progress.doubleValue=0; batchBar.doubleValue=0; currentLabel.stringValue="現在の動画 0%"; batchLabel.stringValue="全体 0% — 処理済み0/\(urls.count)件（保存0・失敗0）"; timer?.invalidate(); startedAt=ProcessInfo.processInfo.systemUptime; updateElapsed(); timer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in self?.updateElapsed() }; status.stringValue="動画情報を取得しています…"
            DispatchQueue.global(qos:.userInitiated).async {
                let result=d.run(urls:urls,options:opts,progress: { value in RunLoop.main.perform(inModes:[.default,.modalPanel,.eventTracking]) { self.show(value) } }) { line in RunLoop.main.perform(inModes:[.default,.modalPanel,.eventTracking]) { self.append(line) } }
                RunLoop.main.perform(inModes:[.default,.modalPanel,.eventTracking]) { self.status.stringValue="\(d.cancelled ? "中止" : "完了") — 保存 \(result.0)件 / 失敗 \(result.1)件"; self.start.isEnabled=true; self.stop.isEnabled=false; self.choose.isEnabled=true; self.quality.isEnabled=true; self.input.isEditable=true; self.timer?.invalidate(); self.timer=nil; self.updateElapsed(); self.downloader=nil;
                    let played=self.completionCue.finish(saved:result.0,cancelled:d.cancelled,quitting:self.quitting)
                    if CommandLine.arguments.contains("--test-gui-download") { print("GUI cue attempted=\(self.completionCue.attempts) accepted=\(played)"); fflush(stdout) }
                    if CommandLine.arguments.contains("--test-gui-download") {
                        let frozen=self.elapsedLabel.stringValue
                        Timer.scheduledTimer(withTimeInterval:2,repeats:false) { _ in
                            precondition(self.elapsedLabel.stringValue==frozen && self.timer==nil)
                            precondition(result.0==1 && result.1==0 && self.progress.doubleValue==100 && self.batchBar.doubleValue==100)
                            precondition(self.completionCue.attempts==1 && played && VideoQuality.height(at:self.quality.indexOfSelectedItem)==360)
                            if let target=ProcessInfo.processInfo.environment["TEST_SCREENSHOT_PATH"],let view=self.window.contentView,let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds) { view.cacheDisplay(in:view.bounds,to:rep); try? rep.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:target)) }
                            print("PASS GUI finished100%, saved1, timer frozen: \(frozen)"); fflush(stdout); NSApp.terminate(nil)
                        }
                    }
                    if self.quitting { NSApp.reply(toApplicationShouldTerminate:true) } }
            }
        } catch { let alert=NSAlert(); alert.messageText=(error as NSError).domain; alert.runModal() }
    }
    func applicationShouldTerminate(_ sender:NSApplication) -> NSApplication.TerminateReply { if let d = downloader { quitting=true; d.cancel(); return .terminateLater }; return .terminateNow }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
}
func findFFmpeg()->String? { [Bundle.main.resourcePath!+"/ffmpeg","/opt/homebrew/bin/ffmpeg","/usr/local/bin/ffmpeg"].first { FileManager.default.isExecutableFile(atPath:$0) } }
func findNode()->String? { [Bundle.main.resourcePath!+"/node","/opt/homebrew/bin/node","/usr/local/bin/node"].first { FileManager.default.isExecutableFile(atPath:$0) } }
let args=CommandLine.arguments
if args.contains("--self-test") {
    progressSelfTests()
    completionSelfTests()
    precondition((try! validURLs("https://youtu.be/abc\nhttps://youtu.be/abc")).count == 1)
    precondition((try? validURLs("https://youtube.com.evil.example/x")) == nil)
    precondition((try? validURLs("--exec touch /tmp/no")) == nil)
    for h in [360,720,1080] { for hls in [false,true] { let a=DownloadOptions(height:h,folder:"/tmp/a b").arguments(url:"https://youtu.be/x",hls:hls,ffmpeg:"/usr/local/bin/ffmpeg"); precondition(a[a.firstIndex(of:"-f")!+1].contains("height<=\(h)")); precondition(a.suffix(2).first == "--") } }
    print("PASS: URL validation, deduplication, resolution caps, argv isolation")
} else if args.contains("--test-sound-play") {
    let sound=NSSound(contentsOfFile:Bundle.main.resourcePath!+"/completion-marimba.wav",byReference:false)!
    precondition(sound.play())
    RunLoop.current.run(until:Date().addingTimeInterval(0.15))
    precondition(sound.isPlaying)
    RunLoop.current.run(until:Date().addingTimeInterval(1.2))
    precondition(!sound.isPlaying)
    print("PASS: NSSound playing during cue and stopped after its duration")
} else if args.contains("--test-sound-load") {
    let sound=NSSound(contentsOfFile:Bundle.main.resourcePath!+"/completion-marimba.wav",byReference:false)
    precondition(sound != nil && abs(sound!.duration-1.12)<0.01)
    print("PASS: bundled original sound decodes as1.12seconds; no playback in this test")
} else if args.count == 3 && args[1] == "--test-progress-file" {
    let lines=try String(contentsOfFile:args[2]).components(separatedBy:.newlines)
    var tracker=VideoProgress(); var matched=0; var previous=0.0
    for line in lines where line.hasPrefix("__") { if tracker.consume(line) { precondition(tracker.fraction>=previous && tracker.fraction<1); previous=tracker.fraction; matched+=1 } }
    precondition(matched>=2); precondition(previous>0)
    print("PASS: parsed \(matched) real yt-dlp progress lines, monotonic fraction=\(previous), withheld 100% until process success")
} else if args.count >= 6 && args[1] == "--test-download" {
    let d=Downloader(tool:Bundle.main.resourcePath!+"/yt-dlp",ffmpeg:findFFmpeg()!)
    var o=DownloadOptions(height:Int(args[2])!,folder:args[3]); o.section=args[4] == "full" ? nil : args[4]
    if let c=ProcessInfo.processInfo.environment["TEST_CANCEL_SECONDS"], let seconds=Double(c) { DispatchQueue.global().asyncAfter(deadline:.now()+seconds) { d.cancel() } }
    let r=d.run(urls:Array(args.dropFirst(5)),options:o,progress:{ v in print("STATE index=\(v.index) current=\(v.current) overall=\(v.overall) processed=\(v.processed) saved=\(v.saved) failed=\(v.failed)"); fflush(stdout) }) { print($0); fflush(stdout) }
    print("RESULT success=\(r.0) failures=\(r.1) cancelled=\(d.cancelled)"); exit(d.cancelled ? 130 : r.1 == 0 ? 0:1)
} else {
    let app=NSApplication.shared; let delegate=App(); app.delegate=delegate; app.setActivationPolicy(.regular)
    let menu=NSMenu(); let item=NSMenuItem(); menu.addItem(item); let submenu=NSMenu(); submenu.addItem(withTitle:"終了",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); item.submenu=submenu; let editItem=NSMenuItem(title:"編集",action:nil,keyEquivalent:""); let edit=NSMenu(title:"編集")
    edit.addItem(withTitle:"元に戻す",action:Selector(("undo:")),keyEquivalent:"z")
    edit.addItem(withTitle:"切り取り",action:#selector(NSText.cut(_:)),keyEquivalent:"x")
    edit.addItem(withTitle:"コピー",action:#selector(NSText.copy(_:)),keyEquivalent:"c")
    edit.addItem(withTitle:"貼り付け",action:#selector(NSText.paste(_:)),keyEquivalent:"v")
    edit.addItem(withTitle:"すべて選択",action:#selector(NSText.selectAll(_:)),keyEquivalent:"a")
    editItem.submenu=edit; menu.addItem(editItem); app.mainMenu=menu; app.run()
}
