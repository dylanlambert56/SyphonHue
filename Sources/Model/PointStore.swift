import Foundation
import Combine
import CoreGraphics

final class PointStore: ObservableObject {
    @Published var points: [SamplePoint] = []
    static let maxPoints = 8

    func addPoint() {
        guard points.count < Self.maxPoints else { return }
        let usedCCs: Set<Int> = Set(points.flatMap { $0.assignments.map { $0.cc } })
        let startingCC = nextFreeStartingCC(avoiding: usedCCs)
        let p = SamplePoint(
            position: CGPoint(x: 0.5, y: 0.5),
            assignments: SamplePoint.defaultAssignments(startingCC: startingCC)
        )
        points.append(p)
    }

    /// Find the smallest `start` (≥ 20) such that `start`, `start+1`, and `start+2`
    /// are all free and all ≤ 127. Falls back to 20 if nothing fits (user will resolve by editing).
    private func nextFreeStartingCC(avoiding used: Set<Int>) -> Int {
        for start in stride(from: 20, through: 125, by: 1) {
            let triplet = [start, start + 1, start + 2]
            if triplet.allSatisfy({ $0 <= 127 && !used.contains($0) }) {
                return start
            }
        }
        return 20
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
