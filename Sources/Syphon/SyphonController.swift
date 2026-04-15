import Foundation
import Metal
import Combine

struct SyphonServerInfo: Identifiable, Hashable {
    var id: String
    var name: String
    var appName: String
    var description: [String: Any]

    static func == (lhs: SyphonServerInfo, rhs: SyphonServerInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

final class SyphonController: ObservableObject {
    @Published private(set) var servers: [SyphonServerInfo] = []
    @Published private(set) var currentTexture: MTLTexture?
    @Published private(set) var selected: SyphonServerInfo?

    private let directory = SyphonServerDirectory.shared()
    private var client: SyphonMetalClient?
    private var observers: [NSObjectProtocol] = []
    private var frameCount: Int = 0

    init() {
        refreshServers()
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .init("SyphonServerAnnounceNotification"),
                                        object: nil, queue: .main) { [weak self] _ in
            self?.refreshServers()
        })
        observers.append(nc.addObserver(forName: .init("SyphonServerRetireNotification"),
                                        object: nil, queue: .main) { [weak self] _ in
            self?.refreshServers()
        })
        observers.append(nc.addObserver(forName: .init("SyphonServerUpdateNotification"),
                                        object: nil, queue: .main) { [weak self] _ in
            self?.refreshServers()
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        client?.stop()
    }

    func refreshServers() {
        let raw = (directory.servers as? [[String: Any]]) ?? []
        servers = raw.compactMap { d in
            guard let uuid = d["SyphonServerDescriptionUUIDKey"] as? String else { return nil }
            let name = (d["SyphonServerDescriptionNameKey"] as? String) ?? ""
            let app = (d["SyphonServerDescriptionAppNameKey"] as? String) ?? ""
            return SyphonServerInfo(id: uuid, name: name, appName: app, description: d)
        }
        if let sel = selected, !servers.contains(where: { $0.id == sel.id }) {
            disconnect()
        }
    }

    func connect(to info: SyphonServerInfo) {
        disconnect()
        selected = info
        frameCount = 0
        NSLog("SyphonHue: connecting to \(info.appName) — \(info.name)")
        let device = MetalContext.shared.device
        client = SyphonMetalClient(serverDescription: info.description,
                                   device: device,
                                   options: nil,
                                   newFrameHandler: { [weak self] c in
            guard let self = self else { return }
            guard let tex = c.newFrameImage() else {
                NSLog("SyphonHue: newFrameImage returned nil")
                return
            }
            self.frameCount += 1
            if self.frameCount == 1 || self.frameCount % 120 == 0 {
                NSLog("SyphonHue: frame \(self.frameCount) \(tex.width)x\(tex.height) fmt=\(tex.pixelFormat.rawValue)")
            }
            DispatchQueue.main.async {
                self.currentTexture = tex
            }
        })
        if client == nil {
            NSLog("SyphonHue: SyphonMetalClient init returned nil")
        }
    }

    func disconnect() {
        client?.stop()
        client = nil
        currentTexture = nil
        selected = nil
    }

    @discardableResult
    func selectByName(app: String, name: String) -> Bool {
        if let match = servers.first(where: { $0.appName == app && $0.name == name }) {
            connect(to: match)
            return true
        }
        return false
    }
}
