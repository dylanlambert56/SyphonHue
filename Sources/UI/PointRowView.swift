import SwiftUI

struct PointRowView: View {
    let index: Int
    @Binding var point: SamplePoint
    var lastSampled: SampledColor?
    var onRemove: () -> Void

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
            HStack {
                Text(String(format: "x %.2f", point.position.x))
                Text(String(format: "y %.2f", point.position.y))
                if let s = lastSampled {
                    Text(String(format: "RGB %.2f %.2f %.2f", s.r, s.g, s.b))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }.font(.caption)
            ForEach($point.assignments) { $a in
                AssignmentRow(assignment: $a)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.controlBackgroundColor)))
    }
}

private struct AssignmentRow: View {
    @Binding var assignment: CCAssignment

    var body: some View {
        HStack(spacing: 6) {
            Toggle("", isOn: $assignment.enabled).labelsHidden()
            Picker("", selection: $assignment.source) {
                ForEach(ColorValue.allCases) { cv in
                    Text(cv.label).tag(cv)
                }
            }.labelsHidden().frame(width: 80)
            Text("CC")
            Stepper(value: $assignment.cc, in: 0...127) {
                Text("\(assignment.cc)").frame(width: 32, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
            }.labelsHidden()
            Text("Ch")
            Stepper(value: $assignment.channel, in: 1...16) {
                Text("\(assignment.channel)").frame(width: 24, alignment: .trailing)
                    .font(.system(.body, design: .monospaced))
            }.labelsHidden()
        }
        .font(.caption)
    }
}
