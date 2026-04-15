import Metal

final class MetalContext {
    static let shared = MetalContext()

    let device: MTLDevice
    let commandQueue: MTLCommandQueue

    private init() {
        guard let d = MTLCreateSystemDefaultDevice(),
              let q = d.makeCommandQueue() else {
            fatalError("Metal not available on this system — SyphonHue requires a Metal-capable GPU.")
        }
        self.device = d
        self.commandQueue = q
    }
}
