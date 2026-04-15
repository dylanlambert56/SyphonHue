import Metal
import CoreGraphics

struct SampledColor {
    var r: Double
    var g: Double
    var b: Double
}

final class FrameSampler {
    static let tileSize = 16

    func sample(texture: MTLTexture, at points: [CGPoint]) -> [SampledColor] {
        let w = texture.width
        let h = texture.height
        guard w > 0, h > 0, !points.isEmpty else { return [] }

        let tile = Self.tileSize
        let bytesPerPixel = 4
        var buffer = [UInt8](repeating: 0, count: tile * tile * bytesPerPixel)

        return points.map { p in
            let cx = Int((p.x * CGFloat(w)).rounded())
            let cy = Int((p.y * CGFloat(h)).rounded())
            let x0 = max(0, min(w - tile, cx - tile / 2))
            let y0 = max(0, min(h - tile, cy - tile / 2))
            let region = MTLRegionMake2D(x0, y0, tile, tile)
            buffer.withUnsafeMutableBytes { raw in
                texture.getBytes(raw.baseAddress!,
                                 bytesPerRow: tile * bytesPerPixel,
                                 from: region,
                                 mipmapLevel: 0)
            }

            var rSum: UInt64 = 0, gSum: UInt64 = 0, bSum: UInt64 = 0
            let pixels = tile * tile
            for i in 0..<pixels {
                let o = i * 4
                bSum += UInt64(buffer[o])
                gSum += UInt64(buffer[o + 1])
                rSum += UInt64(buffer[o + 2])
            }
            let n = Double(pixels) * 255.0
            return SampledColor(r: Double(rSum) / n,
                                g: Double(gSum) / n,
                                b: Double(bSum) / n)
        }
    }
}
