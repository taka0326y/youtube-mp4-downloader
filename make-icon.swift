import AppKit
import Foundation
let root=CommandLine.arguments[1]
let set=root+"/AppIcon.iconset"
try FileManager.default.createDirectory(atPath:set,withIntermediateDirectories:true)
for size in [16,32,64,128,256,512,1024] {
    let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
    let context=NSGraphicsContext.current!.cgContext; context.scaleBy(x:CGFloat(size)/1024,y:CGFloat(size)/1024)
    let tile=NSBezierPath(roundedRect:NSRect(x:84,y:84,width:856,height:856),xRadius:190,yRadius:190)
    let shadow=NSShadow(); shadow.shadowColor=NSColor.black.withAlphaComponent(0.23); shadow.shadowBlurRadius=30; shadow.shadowOffset=NSSize(width:0,height:-10); shadow.set()
    NSGradient(starting:NSColor(calibratedRed:1,green:0.23,blue:0.23,alpha:1),ending:NSColor(calibratedRed:0.76,green:0.03,blue:0.13,alpha:1))!.draw(in:tile,angle:-90)
    NSShadow().set()
    let triangle=NSBezierPath(); triangle.move(to:NSPoint(x:409,y:398)); triangle.line(to:NSPoint(x:409,y:724)); triangle.line(to:NSPoint(x:676,y:561)); triangle.close(); NSColor.white.setFill(); triangle.fill()
    let arrow=NSBezierPath(); arrow.move(to:NSPoint(x:512,y:340)); arrow.line(to:NSPoint(x:512,y:244)); arrow.move(to:NSPoint(x:466,y:290)); arrow.line(to:NSPoint(x:512,y:244)); arrow.line(to:NSPoint(x:558,y:290)); arrow.lineWidth=23; arrow.lineCapStyle = .round; arrow.lineJoinStyle = .round; NSColor.white.withAlphaComponent(0.95).setStroke(); arrow.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let data=rep.representation(using:.png,properties:[:])!
    let names:[String]
    switch size {
    case 16:names=["icon_16x16.png"]
    case 32:names=["icon_16x16@2x.png","icon_32x32.png"]
    case 64:names=["icon_32x32@2x.png"]
    case 128:names=["icon_128x128.png"]
    case 256:names=["icon_128x128@2x.png","icon_256x256.png"]
    case 512:names=["icon_256x256@2x.png","icon_512x512.png"]
    default:names=["icon_512x512@2x.png"]
    }
    for name in names { try data.write(to:URL(fileURLWithPath:set+"/"+name)) }
    if size==1024 { try data.write(to:URL(fileURLWithPath:root+"/AppIcon.png")) }
}
