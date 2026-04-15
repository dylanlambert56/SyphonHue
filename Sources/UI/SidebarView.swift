import SwiftUI

struct SidebarView: View {
    @ObservedObject var pointStore: PointStore
    var lastSampled: [UUID: SampledColor]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sample Points").font(.title3)
                    Spacer()
                    Button {
                        pointStore.addPoint()
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(pointStore.points.count >= PointStore.maxPoints)
                }
                if pointStore.points.isEmpty {
                    Text("No points yet. Click Add to create one.")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                }
                ForEach(pointStore.points.indices, id: \.self) { idx in
                    PointRowView(
                        index: idx + 1,
                        point: $pointStore.points[idx],
                        lastSampled: lastSampled[pointStore.points[idx].id],
                        onRemove: { pointStore.remove(id: pointStore.points[idx].id) }
                    )
                }
            }
            .padding(10)
        }
    }
}
