import Foundation
import SwiftUI
import Combine
import CoreGraphics

@MainActor
final class AppViewModel: ObservableObject {
    let pointStore = PointStore()
    let syphon = SyphonController()
    let midi = MIDIOut()
    let sampler = FrameSampler()
    private let configStore = ConfigStore(fileURL: ConfigStore.defaultURL())

    @Published var sendRateHz: Int = 30 { didSet { restartTimer(); persist() } }
    @Published var lastSampled: [UUID: SampledColor] = [:]

    private var timer: DispatchSourceTimer?
    private var lastSent: [UUID: UInt8] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var pendingSyphonTag: String?

    init() {
        loadConfig()
        restartTimer()
        pointStore.$points
            .dropFirst()
            .sink { [weak self] _ in self?.persist() }
            .store(in: &cancellables)
        syphon.$selected
            .dropFirst()
            .sink { [weak self] sel in
                guard let self = self else { return }
                if let s = sel {
                    self.pendingSyphonTag = "\(s.appName)::\(s.name)"
                } else if self.pendingSyphonTag == nil {
                    // user hasn't chosen anything yet, nothing to remember
                }
                self.persist()
            }
            .store(in: &cancellables)
        syphon.$servers
            .sink { [weak self] _ in self?.tryResumePendingSyphon() }
            .store(in: &cancellables)
    }

    private func tryResumePendingSyphon() {
        guard let tag = pendingSyphonTag else { return }
        let parts = tag.components(separatedBy: "::")
        guard parts.count == 2 else { pendingSyphonTag = nil; return }
        if syphon.selectByName(app: parts[0], name: parts[1]) {
            pendingSyphonTag = nil
        }
    }

    func refreshEndpoints() {
        syphon.refreshServers()
        midi.refreshDestinations()
        objectWillChange.send()
    }

    func selectMIDI(_ dest: MIDIDestination?) {
        midi.select(dest)
        objectWillChange.send()
        persist()
    }

    private func loadConfig() {
        let cfg = (try? configStore.load()) ?? .default
        pointStore.points = cfg.points
        sendRateHz = cfg.sendRateHz
        if let sname = cfg.syphonServer {
            pendingSyphonTag = sname
        }
        syphon.refreshServers()
        midi.refreshDestinations()
        tryResumePendingSyphon()
        if let mname = cfg.midiDestination {
            _ = midi.selectByName(mname)
        }
        pollDiscoveryOnStartup()
    }

    private func pollDiscoveryOnStartup() {
        let tries = [0.2, 0.5, 1.0, 2.0, 4.0]
        for delay in tries {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                self.syphon.refreshServers()
                self.midi.refreshDestinations()
                self.tryResumePendingSyphon()
                if self.midi.selected == nil, let cfg = try? self.configStore.load(),
                   let mname = cfg.midiDestination {
                    _ = self.midi.selectByName(mname)
                }
            }
        }
    }

    private func persist() {
        let cfg = AppConfig(
            points: pointStore.points,
            syphonServer: pendingSyphonTag,
            midiDestination: midi.selected?.name,
            sendRateHz: sendRateHz
        )
        try? configStore.save(cfg)
    }

    private func restartTimer() {
        timer?.cancel()
        let hz = max(1, min(120, sendRateHz))
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + .milliseconds(10),
                   repeating: .milliseconds(Int(1000.0 / Double(hz))))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        guard let tex = syphon.currentTexture else { return }
        let points = pointStore.points
        guard !points.isEmpty else { return }
        let samples = sampler.sample(texture: tex, at: points.map { $0.position })
        guard samples.count == points.count else { return }

        var nextSampled: [UUID: SampledColor] = [:]
        for (i, point) in points.enumerated() {
            let rgb = samples[i]
            nextSampled[point.id] = rgb
            let hsb = ColorMapper.rgbToHSB(r: rgb.r, g: rgb.g, b: rgb.b)
            for a in point.assignments where a.enabled {
                let value01: Double
                switch a.source {
                case .hue: value01 = hsb.h
                case .saturation: value01 = hsb.s
                case .brightness: value01 = hsb.b
                case .red: value01 = rgb.r
                case .green: value01 = rgb.g
                case .blue: value01 = rgb.b
                }
                let midiVal = ColorMapper.toMIDI(value01)
                if lastSent[a.id] != midiVal {
                    lastSent[a.id] = midiVal
                    midi.sendCC(channel: a.channel, cc: a.cc, value: Int(midiVal))
                }
            }
        }
        lastSampled = nextSampled
    }
}
