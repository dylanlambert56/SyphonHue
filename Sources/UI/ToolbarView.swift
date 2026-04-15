import SwiftUI

struct ToolbarView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            Text("Syphon:")
            Menu(syphonLabel) {
                Button("Refresh") { viewModel.refreshEndpoints() }
                Divider()
                if viewModel.syphon.servers.isEmpty {
                    Text("No servers running").foregroundColor(.secondary)
                }
                ForEach(viewModel.syphon.servers) { s in
                    Button("\(s.appName) — \(s.name)") { viewModel.syphon.connect(to: s) }
                }
            }
            .frame(minWidth: 220)

            Text("MIDI:")
            Menu(midiLabel) {
                Button("Refresh") { viewModel.refreshEndpoints() }
                Divider()
                if viewModel.midi.destinations.isEmpty {
                    Text("No destinations").foregroundColor(.secondary)
                }
                ForEach(viewModel.midi.destinations) { d in
                    Button(d.name) { viewModel.selectMIDI(d) }
                }
            }
            .frame(minWidth: 180)

            Text("Rate:")
            Slider(value: Binding(
                get: { Double(viewModel.sendRateHz) },
                set: { viewModel.sendRateHz = Int($0) }
            ), in: 5...60, step: 1)
            .frame(width: 120)
            Text("\(viewModel.sendRateHz) Hz").font(.system(.body, design: .monospaced)).frame(width: 55)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var syphonLabel: String {
        if let s = viewModel.syphon.selected {
            return "\(s.appName) — \(s.name)"
        }
        return "Select…"
    }

    private var midiLabel: String {
        viewModel.midi.selected?.name ?? "Select…"
    }
}
