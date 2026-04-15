import SwiftUI
import MetalKit

struct PreviewView: View {
    @ObservedObject var pointStore: PointStore
    var texture: MTLTexture?
    var lastSampled: [UUID: SampledColor]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                MetalTextureView(texture: texture)
                ForEach(pointStore.points.indices, id: \.self) { idx in
                    let point = pointStore.points[idx]
                    PointMarker(
                        index: idx + 1,
                        color: uiColor(for: point.id),
                        normalizedPosition: point.position,
                        viewSize: geo.size,
                        onDrag: { newPos in
                            pointStore.move(id: point.id, to: newPos)
                        }
                    )
                }
            }
        }
    }

    private func uiColor(for id: UUID) -> Color {
        guard let s = lastSampled[id] else { return .white }
        return Color(red: s.r, green: s.g, blue: s.b)
    }
}

struct PointMarker: View {
    let index: Int
    let color: Color
    let normalizedPosition: CGPoint
    let viewSize: CGSize
    let onDrag: (CGPoint) -> Void

    var body: some View {
        let x = normalizedPosition.x * viewSize.width
        let y = normalizedPosition.y * viewSize.height
        ZStack {
            Circle().fill(color).frame(width: 26, height: 26)
            Circle().stroke(Color.white, lineWidth: 2).frame(width: 26, height: 26)
            Text("\(index)").font(.caption).bold().foregroundColor(.black)
        }
        .position(x: x, y: y)
        .gesture(DragGesture().onChanged { value in
            let nx = value.location.x / max(1, viewSize.width)
            let ny = value.location.y / max(1, viewSize.height)
            onDrag(CGPoint(x: nx, y: ny))
        })
    }
}

struct MetalTextureView: NSViewRepresentable {
    var texture: MTLTexture?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: MetalContext.shared.device)
        v.framebufferOnly = false
        v.enableSetNeedsDisplay = false
        v.isPaused = false
        v.colorPixelFormat = .bgra8Unorm
        v.delegate = context.coordinator
        context.coordinator.commandQueue = MetalContext.shared.commandQueue
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.texture = texture
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var texture: MTLTexture?
        var commandQueue: MTLCommandQueue?

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let cq = commandQueue,
                  let cmd = cq.makeCommandBuffer() else {
                return
            }
            let dst = drawable.texture
            if let src = texture,
               let blit = cmd.makeBlitCommandEncoder() {
                let minW = min(src.width, dst.width)
                let minH = min(src.height, dst.height)
                if minW > 0 && minH > 0 {
                    blit.copy(from: src,
                              sourceSlice: 0, sourceLevel: 0,
                              sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                              sourceSize: MTLSize(width: minW, height: minH, depth: 1),
                              to: dst,
                              destinationSlice: 0, destinationLevel: 0,
                              destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                }
                blit.endEncoding()
            }
            cmd.present(drawable)
            cmd.commit()
        }
    }
}
