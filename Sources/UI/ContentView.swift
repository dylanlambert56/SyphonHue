import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = AppViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(viewModel: viewModel)
            Divider()
            HSplitView {
                PreviewView(
                    pointStore: viewModel.pointStore,
                    texture: viewModel.syphon.currentTexture,
                    lastSampled: viewModel.lastSampled
                )
                .frame(minWidth: 400)

                SidebarView(
                    pointStore: viewModel.pointStore,
                    lastSampled: viewModel.lastSampled,
                    midiValues: viewModel.lastMIDIValues,
                    onSweep: { a in viewModel.sweep(channel: a.channel, cc: a.cc) }
                )
                .frame(minWidth: 380, idealWidth: 440)
            }
            Divider()
            HStack {
                Text(statusLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    private var statusLine: String {
        let syph = viewModel.syphon.selected.map { "\($0.appName) — \($0.name)" } ?? "none"
        let midi = viewModel.midi.selected?.name ?? "none"
        let n = viewModel.pointStore.points.count
        return "Syphon: \(syph) · MIDI: \(midi) · Points: \(n)"
    }
}
