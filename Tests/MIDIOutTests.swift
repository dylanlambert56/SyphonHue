import XCTest
@testable import SyphonHue

final class MIDIOutTests: XCTestCase {
    func testCCBytesChannel1() {
        let bytes = MIDIOut.ccBytes(channel: 1, cc: 20, value: 64)
        XCTAssertEqual(bytes, [0xB0, 20, 64])
    }

    func testCCBytesChannel16() {
        let bytes = MIDIOut.ccBytes(channel: 16, cc: 7, value: 127)
        XCTAssertEqual(bytes, [0xBF, 7, 127])
    }

    func testCCBytesClampsValue() {
        let bytes = MIDIOut.ccBytes(channel: 1, cc: 0, value: 200)
        XCTAssertEqual(bytes, [0xB0, 0, 127])
    }

    func testCCBytesClampsChannel() {
        let bytes = MIDIOut.ccBytes(channel: 0, cc: 0, value: 0)
        XCTAssertEqual(bytes, [0xB0, 0, 0])
    }
}
