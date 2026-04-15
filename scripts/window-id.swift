#!/usr/bin/env swift
import Foundation
import CoreGraphics

let target = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "SyphonHue"

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    if let name = w[kCGWindowOwnerName as String] as? String,
       name == target,
       let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
       let wid = w[kCGWindowNumber as String] as? UInt32,
       let bounds = w[kCGWindowBounds as String] as? [String: Any] {
        let x = (bounds["X"] as? Double) ?? 0
        let y = (bounds["Y"] as? Double) ?? 0
        let wi = (bounds["Width"] as? Double) ?? 0
        let he = (bounds["Height"] as? Double) ?? 0
        // output: wid x y w h
        print("\(wid) \(Int(x)) \(Int(y)) \(Int(wi)) \(Int(he))")
        exit(0)
    }
}
FileHandle.standardError.write("No window found for \(target)\n".data(using: .utf8)!)
exit(1)
