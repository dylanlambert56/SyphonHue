import AppKit

enum AboutPanel {
    static func show() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        let creditsPlain = """
        Samples colors from a Syphon video feed and streams them as MIDI CC to any CoreMIDI destination.

        Released under the MIT License. Provided AS-IS, without warranty of any kind. No support, no guarantees — use at your own risk.

        Bundles the Syphon Framework (Tom Butterworth, Anton Marini, Maxime Touroute, Philippe Chaurand) under a 2-clause BSD license.
        """

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let credits = NSAttributedString(string: creditsPlain, attributes: attrs)

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "SyphonHue",
            .applicationVersion: version,
            .version: build,
            .credits: credits,
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
