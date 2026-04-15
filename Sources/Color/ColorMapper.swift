import Foundation
import CoreGraphics

struct HSB {
    var h: Double
    var s: Double
    var b: Double
}

struct RGB {
    var r: Double
    var g: Double
    var b: Double
}

enum ColorMapper {
    static func rgbToHSB(r: Double, g: Double, b: Double) -> HSB {
        let maxV = max(r, max(g, b))
        let minV = min(r, min(g, b))
        let delta = maxV - minV

        var h: Double = 0
        if delta > 0 {
            if maxV == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6.0)
            } else if maxV == g {
                h = (b - r) / delta + 2.0
            } else {
                h = (r - g) / delta + 4.0
            }
            h /= 6.0
            if h < 0 { h += 1.0 }
        }
        let s = maxV == 0 ? 0 : delta / maxV
        return HSB(h: h, s: s, b: maxV)
    }

    static func toMIDI(_ value: Double) -> UInt8 {
        let clamped = min(max(value, 0.0), 1.0)
        return UInt8(round(clamped * 127.0))
    }
}
