import AppKit

struct VideoQuality {
    let title:String
    let height:Int
    static let choices=[VideoQuality(title:"1080p（フルHD）",height:1080),VideoQuality(title:"720p（HD）",height:720),VideoQuality(title:"360p（軽量）",height:360)]
    static func height(at index:Int)->Int { choices.indices.contains(index) ? choices[index].height : choices[0].height }
}
final class CompletionCue {
    private var played=false
    private let playback:()->Bool
    private(set) var attempts=0
    init(playback:@escaping ()->Bool) { self.playback=playback }
    func reset() { played=false; attempts=0 }
    @discardableResult func finish(saved:Int,cancelled:Bool,quitting:Bool)->Bool {
        guard saved>0,!cancelled,!quitting,!played else { return false }
        played=true;attempts+=1
        return playback()
    }
}
func completionSelfTests() {
    precondition(VideoQuality.choices.map(\.height)==[1080,720,360])
    precondition(VideoQuality.height(at:0)==1080 && VideoQuality.height(at:1)==720 && VideoQuality.height(at:2)==360)
    var calls=0;let cue=CompletionCue { calls+=1;return true }
    precondition(calls==0 && cue.attempts==0) // Startup never plays.
    precondition(!cue.finish(saved:0,cancelled:false,quitting:false) && calls==0)
    precondition(!cue.finish(saved:1,cancelled:true,quitting:false) && calls==0)
    precondition(!cue.finish(saved:1,cancelled:false,quitting:true) && calls==0)
    precondition(cue.finish(saved:1,cancelled:false,quitting:false) && calls==1)
    precondition(!cue.finish(saved:2,cancelled:false,quitting:false) && calls==1)
    cue.reset();precondition(cue.finish(saved:2,cancelled:false,quitting:false) && calls==2)
    print("PASS: explicit1080/720/360 mapping, cue once per successful batch, no startup/all-failed/cancel/quit cue")
}
