import SwiftUI

struct PointRowView: View {
    let index: Int
    @Binding var point: SamplePoint
    var lastSampled: SampledColor?
    var midiValues: [UUID: UInt8]
    var onRemove: () -> Void
    var onSweep: (CCAssignment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Point \(index)").font(.headline)
                Spacer()
                if let s = lastSampled {
                    Rectangle()
                        .fill(Color(red: s.r, green: s.g, blue: s.b))
                        .frame(width: 28, height: 16)
                        .overlay(Rectangle().stroke(Color.secondary, lineWidth: 0.5))
                }
                Button(action: onRemove) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            HStack(spacing: 10) {
                Text(String(format: "x %.2f", point.position.x))
                Text(String(format: "y %.2f", point.position.y))
                if let s = lastSampled {
                    Text(String(format: "RGB %.2f %.2f %.2f", s.r, s.g, s.b))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }.font(.caption)

            HStack(spacing: 6) {
                Text("Smooth").frame(width: 50, alignment: .leading)
                Slider(value: $point.smoothing, in: 0...0.95)
                Text(String(format: "%.2f", point.smoothing))
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
            }.font(.caption)

            HStack(spacing: 6) {
                Text("Sat gate").frame(width: 50, alignment: .leading)
                Slider(value: $point.hueGateSaturation, in: 0...1)
                Text(String(format: "%.2f", point.hueGateSaturation))
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 36, alignment: .trailing)
            }.font(.caption)
            .help("When saturation is below this value, hue is held — prevents random hue flicker on grey regions.")

            ForEach($point.assignments) { $a in
                AssignmentRow(
                    assignment: $a,
                    currentMIDI: midiValues[a.id],
                    onSweep: { onSweep(a) }
                )
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
    }
}

private struct AssignmentRow: View {
    @Binding var assignment: CCAssignment
    var currentMIDI: UInt8?
    var onSweep: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: $assignment.enabled).labelsHidden()
            Picker("", selection: $assignment.source) {
                ForEach(ColorValue.allCases) { cv in
                    Text(cv.label).tag(cv)
                }
            }.labelsHidden().frame(width: 80)

            Text("CC")
            Text("\(assignment.cc)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 30, alignment: .trailing)
            Stepper("", value: $assignment.cc, in: 0...127)
                .labelsHidden()

            Text("Ch")
            Text("\(assignment.channel)")
                .font(.system(.body, design: .monospaced))
                .frame(width: 22, alignment: .trailing)
            Stepper("", value: $assignment.channel, in: 1...16)
                .labelsHidden()

            Spacer(minLength: 4)

            Text(currentMIDI.map { String(format: "%3d", $0) } ?? "—")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .trailing)
                .help("Current CC value being sent")

            Button(action: onSweep) {
                Image(systemName: "waveform.path")
            }
            .buttonStyle(.borderless)
            .help("Sweep 0→127→0 on this CC — use to MIDI-learn in LightKey")
        }
        .font(.caption)
    }
}
