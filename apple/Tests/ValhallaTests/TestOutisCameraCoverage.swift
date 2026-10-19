import XCTest
@testable import Valhalla

/// Outis camera coverage on iOS, against the real Maine build on the host Mac.
/// The simulator can read the host's files, so this uses the same tiles and
/// coverage.bin as the Mac tests. Skipped when they aren't there.
final class TestOutisCameraCoverage: XCTestCase {

    static let configPath = "/Users/kim/Repositories/outis/data/valhalla/maine/valhalla.json"

    // Kittery, Maine to Hampton, New Hampshire through the I-95 toll plaza.
    static let trip = #"{"lat":43.0880,"lon":-70.7360},{"lat":42.9370,"lon":-70.8390}"#

    var valhalla: Valhalla!

    override func setUpWithError() throws {
        guard FileManager.default.fileExists(atPath: Self.configPath) else {
            throw XCTSkip("no local Maine build at \(Self.configPath)")
        }
        valhalla = try Valhalla(configPath: Self.configPath)
    }

    private func lengthKm(_ cameraOptions: String) throws -> Double {
        let request = """
            {"locations":[\(Self.trip)],"costing":"auto","costing_options":{"auto":\(cameraOptions)},"directions_type":"none"}
            """
        let response = try valhalla.route(rawRequest: request)
        let json = try JSONSerialization.jsonObject(with: Data(response.utf8)) as? [String: Any]
        let summary = (json?["trip"] as? [String: Any])?["summary"] as? [String: Any]
        return try XCTUnwrap(summary?["length"] as? Double, "no route in: \(response.prefix(300))")
    }

    /// Same engine, same data: the same answers as on the Mac
    /// (stock 25.13 km through 3 cameras; avoiding them, 20.85 km).
    func testCameraOptionsChangeTheRouteAsOnTheMac() throws {
        XCTAssertEqual(try lengthKm("{}"), 25.13, accuracy: 0.05)
        XCTAssertEqual(try lengthKm(#"{"camera_penalty":30}"#), 25.13, accuracy: 0.05)
        XCTAssertEqual(try lengthKm(#"{"camera_penalty":600}"#), 20.85, accuracy: 0.05)
        XCTAssertEqual(try lengthKm(#"{"camera_exclude":"all"}"#), 20.85, accuracy: 0.05)
    }

    func testRouteTime() throws {
        // On-device latency matters for zero mode's fallback and unavoidable
        // test (docs/phase0.md); record it.
        let start = Date()
        for _ in 0..<10 { _ = try lengthKm(#"{"camera_penalty":600}"#) }
        let ms = Date().timeIntervalSince(start) * 100
        print("OUTIS route with camera_penalty: \(Int(ms)) ms per route (simulator)")
    }
}
