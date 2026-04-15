import SwiftUI

struct HelpPopoverView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Connecting SyphonHue")
                    .font(.title3).bold()

                section(title: "1. Syphon source") {
                    Text("Any application publishing a Syphon feed will show up here (ProPresenter, Resolume, OBS, VDMX, etc.). Enable Syphon output in that application, then pick the server from the Syphon dropdown. Your saved points and connection auto-restore on next launch.")
                }

                section(title: "2. MIDI destination") {
                    Text("SyphonHue sends CC messages to any CoreMIDI destination. To route to another app on the same machine, enable the IAC bus:")
                    Text("Applications → Utilities → Audio MIDI Setup → Window → Show MIDI Studio → double-click ‘IAC Driver’ → check ‘Device is online’.")
                    Text("Back in SyphonHue, pick ‘IAC Driver Bus 1’ (or whichever bus) from the MIDI dropdown. External hardware MIDI ports also appear automatically.")
                }

                section(title: "3. Your MIDI target") {
                    Text("Any software that accepts MIDI CC can consume SyphonHue's output — lighting controllers, DAWs, VJ tools, modular synths, etc.")
                    Text("In the target app, enable the IAC bus (or external port) as a MIDI input and use its MIDI-learn flow on the control you want driven. Press the sweep button (waveform icon) next to a CC in SyphonHue to fire a 0→127→0 ramp on demand so the target can learn it.")
                }

                section(title: "4. Sample points") {
                    Text("Click Add to create a point. Drag it on the preview to place it over the region of the video you want to follow.")
                    Text("Each point exposes up to three CCs: Hue, Saturation, Brightness (or R/G/B). Enable the ones you want to send; set CC # and channel to match whatever the target learns.")
                    Text("Values are sampled from a 16×16 area under the point and sent at the rate shown in the toolbar.")
                }

                section(title: "5. Per-point tuning") {
                    Text("Smooth — exponential smoothing (0 off, up to 0.95) reduces frame-to-frame jitter; useful on busy footage.")
                    Text("Sat gate — when saturation drops below this threshold, hue is held instead of jumping. Prevents random hue chasing on grey or near-black regions.")
                    Text("Freeze (toolbar) — stops all CC output while keeping sampling active; use while setting cues in the target without SyphonHue overwriting them.")
                }

                section(title: "Troubleshooting") {
                    Text("• If no Syphon server appears, click ‘Refresh’ in the dropdown and confirm Syphon output is enabled in the source app.")
                    Text("• If the target isn't receiving anything, confirm the IAC bus is online and selected as input on both sides.")
                    Text("• Preview upside down or black on first run? Quit and relaunch — the shader library compiles on first run.")
                    Text("• Output feels stepped even with smoothing on — raise the target's own transition/crossfade time so it interpolates between CC updates.")
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
