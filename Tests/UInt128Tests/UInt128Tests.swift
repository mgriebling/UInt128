import XCTest
@testable import UInt128

final class UInt128Tests: XCTestCase {
    func testUInt128() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        #if canImport(StaticBigInt)
        let x = UInt128(123_456_789_012_345_678_901_234_567_890)
        #else
        let x = UInt128("123_456_789_012_345_678_901_234_567_890")
        #endif
        let y = UInt128(100_000_000)
        let z = x + y
        let v = x - y
        let a = x / y
        print(x, y, z, v, a)
        // XCTAssertEqual(UInt128().text, "Hello, World!")
    }
}
