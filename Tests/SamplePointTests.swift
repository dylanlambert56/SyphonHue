import XCTest
@testable import SyphonHue

final class SamplePointTests: XCTestCase {
    func testSamplePointCodableRoundTrip() throws {
        let p = SamplePoint(
            id: UUID(),
            position: CGPoint(x: 0.25, y: 0.75),
            assignments: [
                CCAssignment(source: .hue, cc: 20, channel: 1, enabled: true),
                CCAssignment(source: .saturation, cc: 21, channel: 1, enabled: false),
            ]
        )
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(SamplePoint.self, from: data)
        XCTAssertEqual(decoded.id, p.id)
        XCTAssertEqual(decoded.position.x, 0.25)
        XCTAssertEqual(decoded.position.y, 0.75)
        XCTAssertEqual(decoded.assignments.count, 2)
        XCTAssertEqual(decoded.assignments[0].source, .hue)
        XCTAssertEqual(decoded.assignments[0].cc, 20)
        XCTAssertEqual(decoded.assignments[1].enabled, false)
    }

    func testCCAssignmentValidatesCCRange() {
        let a = CCAssignment(source: .hue, cc: 200, channel: 1, enabled: true)
        XCTAssertEqual(a.cc, 127)
    }

    func testCCAssignmentValidatesChannelRange() {
        let a = CCAssignment(source: .hue, cc: 20, channel: 20, enabled: true)
        XCTAssertEqual(a.channel, 16)
    }

    func testColorValueRawValues() {
        XCTAssertEqual(ColorValue.hue.rawValue, "hue")
        XCTAssertEqual(ColorValue.red.rawValue, "red")
    }
}
