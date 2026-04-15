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
                let fitted = fittedSize(for: geo.size)
                ZStack {
                    MetalTextureView(texture: texture)
                    ForEach(pointStore.points.indices, id: \.self) { idx in
                        let point = pointStore.points[idx]
                        PointMarker(
                            index: idx + 1,
                            color: uiColor(for: point.id),
                            normalizedPosition: point.position,
                            viewSize: fitted,
                            onDrag: { newPos in
                                pointStore.move(id: point.id, to: newPos)
                            }
                        )
                    }
                }
                .frame(width: fitted.width, height: fitted.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func fittedSize(for container: CGSize) -> CGSize {
        let aspect: CGFloat = {
            if let t = texture, t.width > 0, t.height > 0 {
                return CGFloat(t.width) / CGFloat(t.height)
            }
            return 16.0 / 9.0
        }()
        let containerAspect = container.width / max(container.height, 1)
        if containerAspect > aspect {
            return CGSize(width: container.height * aspect, height: container.height)
        } else {
            return CGSize(width: container.width, height: container.width / aspect)
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
        v.framebufferOnly = true
        v.enableSetNeedsDisplay = false
        v.isPaused = false
        v.colorPixelFormat = .bgra8Unorm
        v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        v.delegate = context.coordinator
        context.coordinator.configure(
            device: MetalContext.shared.device,
            commandQueue: MetalContext.shared.commandQueue,
            colorPixelFormat: v.colorPixelFormat
        )
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.texture = texture
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var texture: MTLTexture?
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?

        func configure(device: MTLDevice,
                       commandQueue: MTLCommandQueue,
                       colorPixelFormat: MTLPixelFormat) {
            self.device = device
            self.commandQueue = commandQueue
            guard let library = try? device.makeDefaultLibrary(bundle: Bundle.main),
                  let vfn = library.makeFunction(name: "preview_vs"),
                  let ffn = library.makeFunction(name: "preview_fs") else {
                NSLog("SyphonHue: failed to load preview Metal library")
                return
            }
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vfn
            desc.fragmentFunction = ffn
            desc.colorAttachments[0].pixelFormat = colorPixelFormat
            do {
                pipeline = try device.makeRenderPipelineState(descriptor: desc)
            } catch {
                NSLog("SyphonHue: pipeline build failed: \(error)")
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let cq = commandQueue,
                  let cmd = cq.makeCommandBuffer() else {
                return
            }

            if let src = texture, let pipe = pipeline,
               let rpd = view.currentRenderPassDescriptor,
               let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) {
                enc.setRenderPipelineState(pipe)
                enc.setFragmentTexture(src, index: 0)
                enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
                enc.endEncoding()
            } else if let rpd = view.currentRenderPassDescriptor,
                      let enc = cmd.makeRenderCommandEncoder(descriptor: rpd) {
                enc.endEncoding()
            }

            cmd.present(drawable)
            cmd.commit()
        }
    }
}
