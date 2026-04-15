import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = AppViewModel()
    @State private var showHelp = false

    var body: some View {
        NavigationSplitView {
            InspectorView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 520)
        } detail: {
            PreviewView(
                pointStore: viewModel.pointStore,
                texture: viewModel.syphon.currentTexture,
                lastSampled: viewModel.lastSampled
            )
            .frame(minWidth: 420, minHeight: 320)
            .toolbar {
                toolbarContent
            }
            .navigationTitle("SyphonHue")
            .navigationSubtitle(statusLine)
        }
        .frame(minWidth: 960, minHeight: 600)
        .sheet(isPresented: $showHelp) {
            HelpSheet { showHelp = false }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            SyphonMenu(viewModel: viewModel)
        }
        ToolbarItem(placement: .primaryAction) {
            MIDIMenu(viewModel: viewModel)
        }
        ToolbarItem(placement: .primaryAction) {
            RateControl(viewModel: viewModel)
        }
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $viewModel.isFrozen) {
                Label(viewModel.isFrozen ? "Frozen" : "Live",
                      systemImage: viewModel.isFrozen ? "pause.circle.fill" : "waveform")
            }
            .toggleStyle(.button)
            .help("Stop sending CC output while setting up the target app")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                showHelp = true
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
            .help("Connection instructions")
        }
    }

    private var statusLine: String {
        let syph = viewModel.syphon.selected.map { "\($0.appName) — \($0.name)" } ?? "No Syphon source"
        let midi = viewModel.midi.selected?.name ?? "No MIDI destination"
        let n = viewModel.pointStore.points.count
        return "\(syph) · \(midi) · \(n) point\(n == 1 ? "" : "s")"
    }
}

private struct SyphonMenu: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Menu {
            Button("Refresh") { viewModel.refreshEndpoints() }
            Divider()
            if viewModel.syphon.servers.isEmpty {
                Text("No Syphon sources available")
            } else {
                ForEach(viewModel.syphon.servers) { s in
                    Button {
                        viewModel.syphon.connect(to: s)
                    } label: {
                        if viewModel.syphon.selected?.id == s.id {
                            Label("\(s.appName) — \(s.name)", systemImage: "checkmark")
                        } else {
                            Text("\(s.appName) — \(s.name)")
                        }
                    }
                }
            }
        } label: {
            Label(label, systemImage: "video.fill")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Select Syphon source")
    }

    private var label: String {
        viewModel.syphon.selected.map { "\($0.appName) — \($0.name)" } ?? "Syphon"
    }
}

private struct MIDIMenu: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Menu {
            Button("Refresh") { viewModel.refreshEndpoints() }
            Divider()
            if viewModel.midi.destinations.isEmpty {
                Text("No MIDI destinations available")
            } else {
                ForEach(viewModel.midi.destinations) { d in
                    Button {
                        viewModel.selectMIDI(d)
                    } label: {
                        if viewModel.midi.selected?.id == d.id {
                            Label(d.name, systemImage: "checkmark")
                        } else {
                            Text(d.name)
                        }
                    }
                }
            }
        } label: {
            Label(label, systemImage: "pianokeys")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Select MIDI destination")
    }

    private var label: String {
        viewModel.midi.selected?.name ?? "MIDI"
    }
}

private struct RateControl: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .foregroundStyle(.secondary)
            Slider(value: Binding(
                get: { Double(viewModel.sendRateHz) },
                set: { viewModel.sendRateHz = Int($0) }
            ), in: 10...120, step: 1)
            .frame(width: 110)
            Text("\(viewModel.sendRateHz) Hz")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
        }
        .help("CC send rate")
    }
}
