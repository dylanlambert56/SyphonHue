import Foundation
import CoreGraphics

enum ColorValue: String, Codable, CaseIterable, Identifiable {
    case hue, saturation, brightness, red, green, blue
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hue: return "Hue"
        case .saturation: return "Sat"
        case .brightness: return "Bri"
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        }
    }
}

struct CCAssignment: Codable, Identifiable, Equatable {
    var id: UUID
    var source: ColorValue
    var cc: Int
    var channel: Int
    var enabled: Bool

    init(id: UUID = UUID(),
         source: ColorValue,
         cc: Int,
         channel: Int,
         enabled: Bool) {
        self.id = id
        self.source = source
        self.cc = max(0, min(127, cc))
        self.channel = max(1, min(16, channel))
        self.enabled = enabled
    }
}

struct SamplePoint: Codable, Identifiable, Equatable {
    var id: UUID
    var position: CGPoint
    var assignments: [CCAssignment]

    init(id: UUID = UUID(),
         position: CGPoint,
         assignments: [CCAssignment] = []) {
        self.id = id
        self.position = position
        self.assignments = assignments
    }

    static func defaultAssignments(startingCC: Int, channel: Int = 1) -> [CCAssignment] {
        [
            CCAssignment(source: .hue, cc: startingCC, channel: channel, enabled: true),
            CCAssignment(source: .saturation, cc: startingCC + 1, channel: channel, enabled: false),
            CCAssignment(source: .brightness, cc: startingCC + 2, channel: channel, enabled: false),
        ]
    }
}
