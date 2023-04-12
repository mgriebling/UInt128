import XCTest
@testable import UInt128

final class UInt128Tests: XCTestCase {
    
    func testUInt128() throws {
        // Basic go/nogo test to verify the basic operations
        #if canImport(StaticBigInt)
        let x = UInt128(123_456_789_012_345_678_901_234_567_890)
        #else
        let x = UInt128("123_456_789_012_345_678_901_234_567_890")
        #endif
        let y = UInt128(100_000_000)
        let z = x + y
        let v = x - y
        let a = x / y
        let b = x % y
        let c = x * y
        let d = x & y
        let e = x | y
        let f = x ^ y
        let g = ~x
        let h = UInt128(0x1234567890ABCDEF).byteSwapped
        print("x = \(x); y = \(y)")
        print("x + y = \(z)")
        print("x - y = \(v)")
        print("x / y = \(a)")
        print("x % y = \(b)")
        print("x * y = \(c)")
        print("x & y = \(d)")
        print("x | y = \(e)")
        print("x ^ y = \(f)")
        print("~x = \(g)")
        print("0x1234567890ABCDEF byte swapped = \(String(h, radix:16, uppercase: true))")
        XCTAssertEqual(UInt128.max.description, "340282366920938463463374607431768211455")
        XCTAssertEqual(x.description, "123456789012345678901234567890")
        XCTAssertEqual(y.description, "100000000")
        XCTAssertEqual(z.description, "123456789012345678901334567890")
        XCTAssertEqual(v.description, "123456789012345678901134567890")
        XCTAssertEqual(a.description, "1234567890123456789012")
        XCTAssertEqual(b.description, "34567890")
        XCTAssertEqual(c.description, "1234567890123456789123456789000000000")
        XCTAssertEqual(d.description, "70582272")
        XCTAssertEqual(e.description, "123456789012345678901263985618")
        XCTAssertEqual(f.description, "123456789012345678901193403346")
        XCTAssertEqual(g.description, "340282366797481674451028928530533643565")
        XCTAssertEqual(String(h, radix:16, uppercase: true), "EFCDAB90785634120000000000000000")
    }
}
