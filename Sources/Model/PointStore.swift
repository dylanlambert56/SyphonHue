import Foundation
import Combine
import CoreGraphics

final class PointStore: ObservableObject {
    @Published var points: [SamplePoint] = []
    static let maxPoints = 8

    func addPoint() {
        guard points.count < Self.maxPoints else { return }
        let startingCC = 20 + points.count * 3
        let p = SamplePoint(
            position: CGPoint(x: 0.5, y: 0.5),
            assignments: SamplePoint.defaultAssignments(startingCC: startingCC)
        )
        points.append(p)
    }

    func remove(id: UUID) {
        points.removeAll { $0.id == id }
    }

    func move(id: UUID, to position: CGPoint) {
        guard let idx = points.firstIndex(where: { $0.id == id }) else { return }
        points[idx].position = CGPoint(
            x: min(max(position.x, 0), 1),
            y: min(max(position.y, 0), 1)
        )
    }

    func updateAssignment(pointID: UUID, assignmentID: UUID, transform: (inout CCAssignment) -> Void) {
        guard let pi = points.firstIndex(where: { $0.id == pointID }) else { return }
        guard let ai = points[pi].assignments.firstIndex(where: { $0.id == assignmentID }) else { return }
        transform(&points[pi].assignments[ai])
    }
}
