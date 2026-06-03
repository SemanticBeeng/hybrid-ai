import XCTest
@testable import HybridAI

final class HybridAITests: XCTestCase {
    func testStatus() {
        XCTAssertEqual(HybridAI().status(), "hybrid-ai swift module ready")
    }
}
