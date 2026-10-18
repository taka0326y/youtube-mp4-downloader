import Foundation

struct VideoProgress {
    private(set) var fraction = 0.0
    private var streams: [String: Double] = [:]
    private(set) var phase = "動画情報を取得しています…"
    mutating func consume(_ line: String) -> Bool {
        if line.hasPrefix("__PLAN__") {
            let ids = line.dropFirst("__PLAN__".count).split(separator:"+").map(String.init)
            streams = Dictionary(ids.map { ($0,0.0) }, uniquingKeysWith:max)
            phase = "取得中 — 映像・音声をダウンロードしています…"
            return true
        }
        if line.hasPrefix("__MERGE__") {
            fraction = max(fraction,0.98); phase = "結合中 — 映像と音声を結合・保存しています…"
            return true
        }
        guard line.hasPrefix("__PROGRESS__") else { return false }
        let fields = line.dropFirst("__PROGRESS__".count).components(separatedBy:"\t")
        guard fields.count >= 7 else { return true }
        let id=fields[0], status=fields[1]
        func number(_ s:String)->Double? { guard let n=Double(s.trimmingCharacters(in:.whitespacesAndNewlines)), n.isFinite, n>=0 else { return nil }; return n }
        var value = 0.0
        if status == "finished" { value=1 }
        else if let downloaded=number(fields[2]),let total=number(fields[3]),total>0 { value=downloaded/total }
        else if let downloaded=number(fields[2]),let estimate=number(fields[4]),estimate>0 { value=downloaded/estimate }
        else if let index=number(fields[5]),let count=number(fields[6]),count>0 { value=index/count }
        else if fields.count>7,let percent=number(fields[7].replacingOccurrences(of:"%",with:"")) { value=percent/100 }
        value=min(1,max(0,value))
        if streams.isEmpty { streams[id]=value }
        else if streams[id] != nil { streams[id]=max(streams[id]!,value) }
        else if id.contains("+") { for key in Array(streams.keys) { streams[key]=max(streams[key]!,value) } }
        else { streams[id]=value }
        let aggregate=streams.values.reduce(0,+)/Double(max(1,streams.count))
        fraction=max(fraction,min(0.95,aggregate*0.95))
        phase = status == "finished" ? "取得済み — 結合を準備しています…" : "取得中 — 映像・音声をダウンロードしています…"
        return true
    }
}
struct BatchProgress {
    let index: Int
    let total: Int
    let current: Double
    let processed: Int
    let saved: Int
    let failed: Int
    let phase: String
    var overall: Double { guard total>0 else { return 0 }; return min(1,max(0,(Double(processed)+(processed<index ? current:0))/Double(total))) }
}
func elapsedText(_ interval:TimeInterval)->String { let seconds=max(0,Int(interval)); return "\(seconds/60)分\(String(format:"%02d",seconds%60))秒" }

func progressSelfTests() {
    var p=VideoProgress()
    precondition(p.consume("__PLAN__312+140"))
    precondition(p.consume("__PROGRESS__312\tdownloading\t50\t100\tNA\tNA\tNA\t50.0%"))
    precondition(abs(p.fraction-0.2375)<0.0001)
    _=p.consume("__PROGRESS__312\tfinished\t100\t100\tNA\tNA\tNA\t100%")
    precondition(abs(p.fraction-0.475)<0.0001)
    _=p.consume("__PROGRESS__140\tdownloading\t50\t100\tNA\tNA\tNA\t50%")
    precondition(abs(p.fraction-0.7125)<0.0001)
    let before=p.fraction
    _=p.consume("__PLAN__311+234-0")
    _=p.consume("__PROGRESS__311\tdownloading\t1\t100\tNA\tNA\tNA\t1%")
    precondition(p.fraction>=before)
    _=p.consume("__PROGRESS__311\tfinished\t100\t100\tNA\tNA\tNA\t100%")
    _=p.consume("__PROGRESS__234-0\tfinished\t100\t100\tNA\tNA\tNA\t100%")
    precondition(p.fraction==0.95)
    _=p.consume("__MERGE__"); precondition(p.fraction==0.98)
    _=p.consume("__PROGRESS__bad\tdownloading\tnan\tinf\t0\tNA\tNA\tNA")
    precondition(p.fraction==0.98)
    precondition(!p.consume("ordinary log")); precondition(p.consume("__PROGRESS__malformed"))
    let partial=BatchProgress(index:2,total:3,current:0.5,processed:1,saved:0,failed:1,phase:"")
    precondition(partial.overall==0.5)
    precondition(BatchProgress(index:3,total:3,current:1,processed:3,saved:2,failed:1,phase:"").overall==1)
    precondition(BatchProgress(index:3,total:3,current:0.98,processed:2,saved:2,failed:0,phase:"").overall<1)
    precondition(elapsedText(125.9)=="2分05秒"); precondition(elapsedText(0)=="0分00秒")
    print("PASS: stream aggregation, HLS retry monotonicity, merge cap, failure counts, partial cancellation, elapsed formatting")
}
