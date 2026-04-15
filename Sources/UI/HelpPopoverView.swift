import SwiftUI

struct HelpSheet: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Connecting SyphonHue")
                    .font(.title2).bold()
                Spacer()
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section(title: "1. Syphon source") {
                        Text("Any application publishing a Syphon feed will show up here (ProPresenter, Resolume, OBS, VDMX, etc.). Enable Syphon output in that application, then pick the server from the Syphon menu. Your saved points and connection auto-restore on next launch.")
                    }

                    section(title: "2. MIDI destination") {
                        Text("SyphonHue sends CC messages to any CoreMIDI destination. To route to another app on the same machine, enable the IAC bus:")
                        Text("Applications → Utilities → Audio MIDI Setup → Window → Show MIDI Studio → double-click IAC Driver → check “Device is online.”")
                        Text("Back in SyphonHue, pick “IAC Driver Bus 1” (or whichever bus) from the MIDI menu. External hardware MIDI ports also appear automatically.")
                    }

                    section(title: "3. Your MIDI target") {
                        Text("Any software that accepts MIDI CC can consume SyphonHue's output — lighting controllers, DAWs, VJ tools, modular synths, etc.")
                        Text("In the target app, enable the IAC bus (or external port) as a MIDI input and use its MIDI-learn flow on the control you want driven. Press the waveform button next to a CC in SyphonHue to fire a 0 → 127 → 0 ramp on demand so the target can learn it.")
                    }

                    section(title: "4. Sample points") {
                        Text("Click + in the sidebar to create a point. Drag it on the preview to place it over the region of the video you want to follow.")
                        Text("Each point exposes up to three CCs: Hue, Saturation, Brightness (or R / G / B). Enable the ones you want to send, then set CC # and channel to match whatever the target learned.")
                        Text("Values are sampled from a 16 × 16 area under the point and sent at the rate set in the toolbar.")
                    }

                    section(title: "5. Per-point tuning") {
                        Text("Smoothing — exponential moving average (0 off, up to 0.95) reduces frame-to-frame jitter; useful on busy footage.")
                        Text("Sat gate — when saturation drops below this threshold, hue is held instead of jumping. Prevents random hue chasing on grey or near-black regions.")
                        Text("Freeze (toolbar) — stops all CC output while sampling continues; use while setting cues in the target without SyphonHue overwriting them.")
                    }

                    section(title: "Troubleshooting") {
                        Text("• If no Syphon server appears, click Refresh next to Video source and confirm Syphon output is enabled in the source app.")
                        Text("• If the target isn't receiving anything, confirm the IAC bus is online and selected as input on both sides.")
                        Text("• Output feels stepped even with smoothing on — raise the target's own transition / crossfade time so it interpolates between CC updates.")
                    }

                    section(title: "License & notices") {
                        Text("SyphonHue is released under the MIT License. © 2026 Dylan Lambert.")
                        Text("The software is provided AS-IS, without warranty of any kind. There is no support, no maintenance commitment, and no guarantee of fitness for any purpose. Use at your own risk.")
                        Text("Bundles the Syphon Framework (Tom Butterworth, Anton Marini, Maxime Touroute, Philippe Chaurand) under a 2-clause BSD license.")
                        Button("View full license") {
                            if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
                .padding()
            }
        }
        .frame(width: 560, height: 720)
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            content()
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
