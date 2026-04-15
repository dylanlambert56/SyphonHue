#!/usr/bin/env swift
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

let rect = CGRect(x: 0, y: 0, width: size, height: size)
let cornerRadius: CGFloat = size * 0.2235
ctx.saveGState()
let roundedPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
ctx.addPath(roundedPath)
ctx.clip()

let space = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    CGColor(colorSpace: space, components: [0.09, 0.08, 0.14, 1])!,
    CGColor(colorSpace: space, components: [0.02, 0.02, 0.05, 1])!,
]
let bgGrad = CGGradient(colorsSpace: space,
                         colors: bgColors as CFArray,
                         locations: [0.0, 1.0])!
ctx.drawLinearGradient(bgGrad,
                       start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: size, y: 0),
                       options: [])

let center = CGPoint(x: size / 2, y: size / 2)
let outerRadius: CGFloat = size * 0.38
let innerRadius: CGFloat = size * 0.26
let steps = 720
for i in 0..<steps {
    let t = CGFloat(i) / CGFloat(steps)
    let startAngle = CGFloat(i) * .pi * 2 / CGFloat(steps) - .pi / 2
    let endAngle = CGFloat(i + 1) * .pi * 2 / CGFloat(steps) - .pi / 2 + 0.003
    let color = NSColor(hue: t, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor
    ctx.setFillColor(color)
    ctx.beginPath()
    ctx.move(to: center)
    ctx.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
    ctx.closePath()
    ctx.fillPath()
}

ctx.setFillColor(CGColor(colorSpace: space, components: [0.04, 0.03, 0.07, 1])!)
ctx.beginPath()
ctx.addArc(center: center, radius: innerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.fillPath()

ctx.setStrokeColor(CGColor(colorSpace: space, components: [1, 1, 1, 0.85])!)
ctx.setLineWidth(size * 0.014)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: center.x - innerRadius * 0.58, y: center.y))
ctx.addLine(to: CGPoint(x: center.x + innerRadius * 0.58, y: center.y))
ctx.move(to: CGPoint(x: center.x, y: center.y - innerRadius * 0.58))
ctx.addLine(to: CGPoint(x: center.x, y: center.y + innerRadius * 0.58))
ctx.strokePath()

ctx.setFillColor(CGColor(colorSpace: space, components: [1, 1, 1, 1])!)
ctx.beginPath()
ctx.addArc(center: center, radius: size * 0.026, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.fillPath()

ctx.setStrokeColor(CGColor(colorSpace: space, components: [1, 1, 1, 0.12])!)
ctx.setLineWidth(size * 0.006)
ctx.beginPath()
ctx.addArc(center: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
ctx.strokePath()

ctx.restoreGState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}

let outURL = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png")
try! png.write(to: outURL)
print("Wrote \(outURL.path) (\(Int(size))x\(Int(size)))")
