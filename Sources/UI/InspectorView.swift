import SwiftUI

struct InspectorView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var pointStore: PointStore

    init(viewModel: AppViewModel) {
        self.viewModel = viewModel
        self.pointStore = viewModel.pointStore
    }

    var body: some View {
        List {
            Section("Connections") {
                ConnectionsRow(viewModel: viewModel)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            }

            Section {
                if pointStore.points.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No sample points")
                            .font(.headline)
                        Text("Click the + button above to add a point, then drag it on the preview.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(pointStore.points.enumerated()), id: \.element.id) { pair in
                        let idx = pair.offset
                        PointRow(
                            index: idx + 1,
                            point: $pointStore.points[idx],
                            sampled: viewModel.lastSampled[pair.element.id],
                            midiValues: viewModel.lastMIDIValues,
                            duplicateCCs: duplicateCCs,
                            onRemove: { pointStore.remove(id: pair.element.id) },
                            onSweep: { a in viewModel.sweep(channel: a.channel, cc: a.cc) }
                        )
                    }
                }
            } header: {
                HStack {
                    Text("Sample Points")
                    Spacer()
                    Button {
                        pointStore.addPoint()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(pointStore.points.count >= PointStore.maxPoints)
                    .help("Add sample point")
                }
            }
        }
        .listStyle(.sidebar)
    }

    /// Returns the set of (channel, cc) pairs used by 2+ enabled assignments across all points.
    private var duplicateCCs: Set<CCKey> {
        var counts: [CCKey: Int] = [:]
        for point in pointStore.points {
            for a in point.assignments where a.enabled {
                counts[CCKey(channel: a.channel, cc: a.cc), default: 0] += 1
            }
        }
        return Set(counts.filter { $0.value > 1 }.keys)
    }
}

struct CCKey: Hashable {
    let channel: Int
    let cc: Int
}

private struct PointRow: View {
    let index: Int
    @Binding var point: SamplePoint
    var sampled: SampledColor?
    var midiValues: [UUID: UInt8]
    var duplicateCCs: Set<CCKey>
    var onRemove: () -> Void
    var onSweep: (CCAssignment) -> Void

    @State private var expanded: Bool = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Smoothing")
                                .frame(width: 90, alignment: .leading)
                            Slider(value: $point.smoothing, in: 0...0.95)
                            Text(String(format: "%.2f", point.smoothing))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 38, alignment: .trailing)
                        }
                        HStack {
                            Text("Sat gate")
                                .frame(width: 90, alignment: .leading)
                            Slider(value: $point.hueGateSaturation, in: 0...1)
                            Text(String(format: "%.2f", point.hueGateSaturation))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 38, alignment: .trailing)
                        }
                        .help("Hue is held when saturation falls below this threshold — prevents hue jitter on near-grey regions.")
                    }
                    .font(.caption)
                }

                GroupBox {
                    VStack(spacing: 6) {
                        ForEach($point.assignments) { $a in
                            AssignmentRow(
                                assignment: $a,
                                currentMIDI: midiValues[a.id],
                                isDuplicate: duplicateCCs.contains(CCKey(channel: a.channel, cc: a.cc)),
                                onSweep: { onSweep(a) }
                            )
                            if a.id != point.assignments.last?.id {
                                Divider()
                            }
                        }
                    }
                } label: {
                    Text("CC Output").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(sampled.map { Color(red: $0.r, green: $0.g, blue: $0.b) } ?? Color.gray)
                    Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 0.5)
                }
                .frame(width: 18, height: 18)

                Text("Point \(index)")
                    .font(.headline)

                Spacer()

                Text(String(format: "(%.2f, %.2f)", point.position.x, point.position.y))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove this point")
            }
        }
    }
}

private struct AssignmentRow: View {
    @Binding var assignment: CCAssignment
    var currentMIDI: UInt8?
    var isDuplicate: Bool
    var onSweep: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $assignment.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)

            Picker("", selection: $assignment.source) {
                ForEach(ColorValue.allCases) { cv in
                    Text(cv.label).tag(cv)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 88)

            LabeledNumber(label: "CC", value: $assignment.cc, range: 0...127, width: 30)
            LabeledNumber(label: "Ch", value: $assignment.channel, range: 1...16, width: 22)

            if isDuplicate && assignment.enabled {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help("This CC/channel is also used by another point — the target will see both values.")
            }

            Spacer(minLength: 4)

            Text(currentMIDI.map { String(format: "%3d", $0) } ?? "—")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(assignment.enabled ? .primary : .secondary)
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)
                .help("Current CC value being sent")

            Button(action: onSweep) {
                Image(systemName: "waveform")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Sweep 0→127→0 to trigger MIDI-learn in the target app")
        }
        .font(.caption)
    }
}

private struct LabeledNumber: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let width: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .frame(width: width, alignment: .trailing)
            Stepper("", value: $value, in: range)
                .labelsHidden()
                .controlSize(.mini)
        }
    }
}
