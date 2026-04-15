import XCTest
@testable import SyphonHue

final class ColorMapperTests: XCTestCase {
    func testRGBToHSBPureRed() {
        let hsb = ColorMapper.rgbToHSB(r: 1.0, g: 0.0, b: 0.0)
        XCTAssertEqual(hsb.h, 0.0, accuracy: 0.001)
        XCTAssertEqual(hsb.s, 1.0, accuracy: 0.001)
        XCTAssertEqual(hsb.b, 1.0, accuracy: 0.001)
    }

    func testRGBToHSBPureGreen() {
        let hsb = ColorMapper.rgbToHSB(r: 0.0, g: 1.0, b: 0.0)
        XCTAssertEqual(hsb.h, 1.0/3.0, accuracy: 0.001)
        XCTAssertEqual(hsb.s, 1.0, accuracy: 0.001)
    }

    func testRGBToHSBPureBlue() {
        let hsb = ColorMapper.rgbToHSB(r: 0.0, g: 0.0, b: 1.0)
        XCTAssertEqual(hsb.h, 2.0/3.0, accuracy: 0.001)
    }

    func testRGBToHSBGrey() {
        let hsb = ColorMapper.rgbToHSB(r: 0.5, g: 0.5, b: 0.5)
        XCTAssertEqual(hsb.s, 0.0, accuracy: 0.001)
        XCTAssertEqual(hsb.b, 0.5, accuracy: 0.001)
    }

    func testToMIDIClampsLow() {
        XCTAssertEqual(ColorMapper.toMIDI(-0.1), 0)
    }

    func testToMIDIClampsHigh() {
        XCTAssertEqual(ColorMapper.toMIDI(1.5), 127)
    }

    func testToMIDIMidpoint() {
        XCTAssertEqual(ColorMapper.toMIDI(0.5), 64)
    }

    func testToMIDIOne() {
        XCTAssertEqual(ColorMapper.toMIDI(1.0), 127)
    }

    func testToMIDIZero() {
        XCTAssertEqual(ColorMapper.toMIDI(0.0), 0)
    }
}
