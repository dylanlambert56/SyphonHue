import SwiftUI

struct ConnectionsRow: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Video source", systemImage: "video")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
                    .frame(width: 130, alignment: .leading)

                Picker("", selection: syphonBinding) {
                    if viewModel.syphon.servers.isEmpty {
                        Text("No Syphon sources available").tag(SyphonServerInfo?.none)
                    } else {
                        Text("Choose a source…").tag(SyphonServerInfo?.none)
                        ForEach(viewModel.syphon.servers) { s in
                            Text("\(s.appName) — \(s.name)").tag(Optional(s))
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)

                Button {
                    viewModel.refreshEndpoints()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Rescan for Syphon sources")
            }

            HStack(spacing: 8) {
                Label("MIDI destination", systemImage: "pianokeys")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
                    .frame(width: 130, alignment: .leading)

                Picker("", selection: midiBinding) {
                    if viewModel.midi.destinations.isEmpty {
                        Text("No MIDI destinations available").tag(MIDIDestination?.none)
                    } else {
                        Text("Choose a destination…").tag(MIDIDestination?.none)
                        ForEach(viewModel.midi.destinations) { d in
                            Text(d.name).tag(Optional(d))
                        }
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)

                Button {
                    viewModel.refreshEndpoints()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Rescan for MIDI destinations")
            }

            if viewModel.syphon.servers.isEmpty || viewModel.midi.destinations.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var syphonBinding: Binding<SyphonServerInfo?> {
        Binding(
            get: { viewModel.syphon.selected },
            set: { new in
                if let new {
                    viewModel.syphon.connect(to: new)
                } else {
                    viewModel.syphon.disconnect()
                }
            }
        )
    }

    private var midiBinding: Binding<MIDIDestination?> {
        Binding(
            get: { viewModel.midi.selected },
            set: { new in
                viewModel.selectMIDI(new)
            }
        )
    }

    private var hint: String {
        var tips: [String] = []
        if viewModel.syphon.servers.isEmpty {
            tips.append("Start the app publishing the Syphon feed (e.g. enable Syphon output in ProPresenter).")
        }
        if viewModel.midi.destinations.isEmpty {
            tips.append("Enable the IAC bus in Audio MIDI Setup, or connect a MIDI device.")
        }
        return tips.joined(separator: " ")
    }
}
