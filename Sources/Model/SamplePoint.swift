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
    /// 0 = no smoothing, 0.95 = very smooth. Exponential moving average coefficient applied to
    /// newly-sampled RGB before it is used for CC output.
    var smoothing: Double
    /// When sending .hue, if the current saturation is below this threshold, hold the last hue
    /// value instead of updating. Prevents chaotic hue jumps on near-grey / near-black regions.
    var hueGateSaturation: Double

    init(id: UUID = UUID(),
         position: CGPoint,
         assignments: [CCAssignment] = [],
         smoothing: Double = 0.0,
         hueGateSaturation: Double = 0.0) {
        self.id = id
        self.position = position
        self.assignments = assignments
        self.smoothing = min(max(smoothing, 0), 1)
        self.hueGateSaturation = min(max(hueGateSaturation, 0), 1)
    }

    private enum CodingKeys: String, CodingKey {
        case id, position, assignments, smoothing, hueGateSaturation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.position = try c.decode(CGPoint.self, forKey: .position)
        self.assignments = try c.decode([CCAssignment].self, forKey: .assignments)
        self.smoothing = (try? c.decode(Double.self, forKey: .smoothing)) ?? 0
        self.hueGateSaturation = (try? c.decode(Double.self, forKey: .hueGateSaturation)) ?? 0
    }

    static func defaultAssignments(startingCC: Int, channel: Int = 1) -> [CCAssignment] {
        [
            CCAssignment(source: .hue, cc: startingCC, channel: channel, enabled: true),
            CCAssignment(source: .saturation, cc: startingCC + 1, channel: channel, enabled: false),
            CCAssignment(source: .brightness, cc: startingCC + 2, channel: channel, enabled: false),
        ]
    }
}
