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
                            onNudge: { a in viewModel.nudge(assignment: a) }
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
    var onNudge: (CCAssignment) -> Void

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
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                        GridRow {
                            headerCell("On", align: .center)
                            headerCell("Source")
                            headerCell("CC")
                            headerCell("Ch")
                            headerCell("Value", align: .trailing).gridColumnAlignment(.trailing)
                            headerCell("", align: .center)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                        Divider().gridCellColumns(6)

                        ForEach($point.assignments) { $a in
                            AssignmentRow(
                                assignment: $a,
                                currentMIDI: midiValues[a.id],
                                isDuplicate: duplicateCCs.contains(CCKey(channel: a.channel, cc: a.cc)),
                                onNudge: { onNudge(a) }
                            )
                            if a.id != point.assignments.last?.id {
                                Divider().gridCellColumns(6)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pianokeys")
                            .foregroundStyle(.secondary)
                        Text("CC Output")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

private func headerCell(_ text: String, align: Alignment = .leading) -> some View {
    Text(text)
        .frame(maxWidth: .infinity, alignment: align)
}

private struct AssignmentRow: View {
    @Binding var assignment: CCAssignment
    var currentMIDI: UInt8?
    var isDuplicate: Bool
    var onNudge: () -> Void

    var body: some View {
        GridRow {
            Toggle("", isOn: $assignment.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .gridColumnAlignment(.center)
                .help(assignment.enabled ? "Enabled" : "Disabled")

            Picker("", selection: $assignment.source) {
                ForEach(ColorValue.allCases) { cv in
                    Text(cv.label).tag(cv)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: 96)

            NumberField(value: $assignment.cc, range: 0...127, width: 28)

            NumberField(value: $assignment.channel, range: 1...16, width: 22)

            HStack(spacing: 4) {
                if isDuplicate && assignment.enabled {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .help("This CC/channel is also used by another point — the target will see both values.")
                }
                Text(currentMIDI.map { String(format: "%3d", $0) } ?? "—")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(assignment.enabled ? .primary : .secondary)
                    .monospacedDigit()
            }
            .gridColumnAlignment(.trailing)
            .help("Last CC value the target received")

            Button(action: onNudge) {
                Image(systemName: "bolt.fill")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .gridColumnAlignment(.center)
            .help("Nudge this CC ±1 — triggers MIDI-learn in the target, even while paused")
        }
        .font(.caption)
    }
}

private struct NumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let width: CGFloat

    var body: some View {
        HStack(spacing: 2) {
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

