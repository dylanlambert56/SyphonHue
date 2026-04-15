import XCTest
@testable import SyphonHue

final class ConfigStoreTests: XCTestCase {
    var tmpURL: URL!

    override func setUp() {
        super.setUp()
        tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("syphonhue-test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpURL)
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() throws {
        let store = ConfigStore(fileURL: tmpURL)
        let config = AppConfig(
            points: [SamplePoint(position: .init(x: 0.1, y: 0.2))],
            syphonServer: "ProPresenter",
            midiDestination: "IAC Bus 1",
            sendRateHz: 30
        )
        try store.save(config)
        let loaded = try store.load()
        XCTAssertEqual(loaded.points.count, 1)
        XCTAssertEqual(loaded.syphonServer, "ProPresenter")
        XCTAssertEqual(loaded.midiDestination, "IAC Bus 1")
        XCTAssertEqual(loaded.sendRateHz, 30)
    }

    func testLoadMissingFileReturnsDefault() throws {
        let store = ConfigStore(fileURL: tmpURL)
        let loaded = try store.load()
        XCTAssertTrue(loaded.points.isEmpty)
        XCTAssertNil(loaded.syphonServer)
        XCTAssertNil(loaded.midiDestination)
        XCTAssertEqual(loaded.sendRateHz, 30)
    }
}
