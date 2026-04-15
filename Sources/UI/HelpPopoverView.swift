import SwiftUI

struct HelpPopoverView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Connecting SyphonHue")
                    .font(.title3).bold()

                section(title: "1. Syphon source (ProPresenter)") {
                    Text("In ProPresenter, open Preferences → General and enable Syphon output.")
                    Text("Start the presentation — ProPresenter will publish a Syphon server.")
                    Text("In SyphonHue, pick the server from the Syphon dropdown. The preview and your saved points auto-reconnect next launch.")
                }

                section(title: "2. MIDI destination") {
                    Text("SyphonHue sends CC messages to any CoreMIDI destination. To route to LightKey on the same machine, enable the IAC bus:")
                    Text("Applications → Utilities → Audio MIDI Setup → Window → Show MIDI Studio → double-click ‘IAC Driver’ → check ‘Device is online’.")
                    Text("Back in SyphonHue, pick ‘IAC Driver Bus 1’ (or whichever bus) from the MIDI dropdown.")
                }

                section(title: "3. LightKey") {
                    Text("In LightKey: Preferences → Connections → MIDI → enable the same IAC bus as input.")
                    Text("Add an assignable external control (e.g. a hue dial). Right-click → ‘Assign to MIDI’ → move something in SyphonHue so the CC fires — LightKey learns it.")
                    Text("Repeat for each point / value you want driven.")
                }

                section(title: "4. Sample points") {
                    Text("Click Add to create a point. Drag it on the preview to place it over the region of the video you want to follow.")
                    Text("Each point exposes up to three CCs: Hue, Saturation, Brightness (or R/G/B). Enable the ones you want to send; set CC # and channel to match whatever LightKey learns.")
                    Text("Values are sampled from a 16×16 area under the point and sent at the rate shown in the toolbar.")
                }

                section(title: "Troubleshooting") {
                    Text("• If no Syphon server appears, click ‘Refresh’ in the dropdown and confirm Syphon output is enabled in ProPresenter.")
                    Text("• If LightKey doesn't receive anything, confirm the IAC bus is online and selected as input on both sides.")
                    Text("• Preview upside down or black? Quit and relaunch — the shader library compiles on first run.")
                }
            }
            .padding(20)
            .frame(width: 480, alignment: .leading)
        }
        .frame(maxHeight: 640)
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            content()
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}
