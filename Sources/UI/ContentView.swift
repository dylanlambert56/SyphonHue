import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = AppViewModel()
    @State private var showHelp = false

    var body: some View {
        NavigationSplitView {
            InspectorView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 400, ideal: 440, max: 560)
        } detail: {
            ZStack(alignment: .top) {
                PreviewView(
                    pointStore: viewModel.pointStore,
                    texture: viewModel.syphon.currentTexture,
                    lastSampled: viewModel.lastSampled
                )
                if viewModel.isFrozen {
                    HStack(spacing: 8) {
                        Image(systemName: "pause.circle.fill")
                        Text("MIDI output paused")
                            .font(.callout).bold()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.orange.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: viewModel.isFrozen)
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
        ToolbarItem(placement: .primaryAction) {
            RateControl(viewModel: viewModel)
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                viewModel.isFrozen.toggle()
            } label: {
                if viewModel.isFrozen {
                    Label("Resume Output", systemImage: "play.fill")
                        .foregroundStyle(.orange)
                } else {
                    Label("Pause Output", systemImage: "pause.fill")
                }
            }
            .help(viewModel.isFrozen
                  ? "MIDI output is paused — click to resume sending CC messages"
                  : "Pause MIDI output (sampling keeps running). Useful while setting up the target app.")
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
