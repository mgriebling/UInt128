//
//  TestInt128Tests.swift
//  TestInt128Tests
//
//  Created by Mike Griebling on 14.04.2023.
//
//
// Int128UnitTests.swift
//
// Int128 unit test cases.
//
// Copyright 2016 Joel Gerber
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Thanks to Joel for providing these test cases.  Mine are at the
// very end and very basic.  Portions of the tests have been changed
// to work with my version of Int128
// 13 Apr 2023 - Michael Griebling

import XCTest

// Import Int128 module and mark as testable so we can, y'know, test it.
@testable import UInt128

// A Int128 with a decently complicated bit pattern
let bizarreInt128 = Int128(0xf1f3_f5f7_f9fb_fdff_fefc_faf0_f8f6_f4f2)

/// User tests that act as a basic smoke test on library functionality.
class SystemInt128Tests : XCTestCase {
  func testCanReceiveAnInt() {
    let expectedResult = Int128((high: 0, low: 1))
    let testResult = Int128(Int(1))
    XCTAssertEqual(testResult, expectedResult)
  }
  
  func testCanBeSentToAnInt() {
    let expectedResult: Int = 1
    let uint = Int128((high: 0, low: 1))
    let testResult = Int(uint)
    XCTAssertEqual(testResult, expectedResult)
  }
  
  func testIntegerLiteralInput() {
    let expectedResult = Int128((high: 0, low: 1))
    let testResult: Int128 = 1
    XCTAssertEqual(testResult, expectedResult)
  }
  
  func testCanReceiveAString() {
    let expectedResult = Int128((high: 0, low: 1))
    let testResult = Int128(String("1"))
    XCTAssertEqual(testResult, expectedResult)
  }
  
  func testStringLiteralInput() {
    let expectedResult = Int128((high: 0, low: 1))
    let testResult = Int128("1")
    XCTAssertEqual(testResult, expectedResult)
  }
  
  func testCanBeSentToAFloat() {
    let expectedResult: Float = 1
    let testResult = Float(Int128((high: 0, low: 1)))
    XCTAssertEqual(testResult, expectedResult)
  }
}

/// Test properties and methods that are not tied to protocol conformance.
class BaseTypeInt128Tests : XCTestCase {
  
  func testDesignatedInitializerProperlySetsInternalValue() {
    var tests = [(input: (high: Int64.min, low: UInt64.min),
                  output: (high: Int64.min, low: UInt64.min))]
    tests.append((input: (high: Int64.max, low: UInt64.max),
                  output: (high: Int64.max, low: UInt64.max)))
    
    tests.forEach { test in
      let result = Int128((high: test.input.high,
                           low: test.input.low))
      
      XCTAssertEqual(result._high, test.output.high)
      XCTAssertEqual(result._low, test.output.low)
    }
  }
  
  func testDefaultInitializerSetsUpperAndLowerBitsToZero() {
    let result = Int128()
    
    XCTAssertEqual(result._high, 0)
    XCTAssertEqual(result._low, 0)
  }
  
  func testInitWithInt128() {
    var tests = [Int128()]
    tests.append(Int128((high: 0, low: 1)))
    tests.append(Int128((high: 0, low: UInt64.max)))
    tests.append(Int128.max)
    
    tests.forEach { test in
      XCTAssertEqual(Int128(test), test)
    }
  }
  
  func testStringInitializerWithEmptyString() {
    XCTAssertNil(Int128("" as String))
  }
  
  func testStringInitializerWithSupportedNumberFormats() {
    var tests = ["0b2"]
    tests.append("0o8")
    tests.append("0xG")
    
    tests.forEach { test in
      XCTAssertNil(Int128(test))
    }
  }
}

class FixedWidthInteger128Tests : XCTestCase {
  func testNonzeroBitCount() {
    var tests = [(input: Int128(0), result: 0)]
    tests.append((input: Int128(1), result: 1))
    tests.append((input: Int128(3), result: 2))
    tests.append((input: Int128(UInt64.max), result: 64))
    tests.append((input: Int128((high: 1, low: 0)), result: 1))
    tests.append((input: Int128((high: 3, low: 0)), result: 2))
    tests.append((input: Int128.max, result: 127))
    
    tests.forEach { test in
      XCTAssertEqual(test.input.nonzeroBitCount, test.result)
    }
  }
  
  func testLeadingZeroBitCount() {
    var tests = [(input: Int128(0), result: 128)]
    tests.append((input: Int128(1), result: 127))
    tests.append((input: Int128(UInt64.max), result: 64))
    tests.append((input: Int128((high: 1, low: 0)), result: 63))
    tests.append((input: Int128.max, result: 1))
    
    tests.forEach { test in
      XCTAssertEqual(test.input.leadingZeroBitCount, test.result)
    }
  }
  
  func endianTests() -> [(input: Int128, byteSwapped: Int128)] {
    var tests = [(input: Int128(), byteSwapped: Int128())]
      tests.append((input: Int128(1),
                    byteSwapped: Int128((high: 0x100000000000000, low: 0))))
      tests.append((input: Int128((high: 0x71F3F5F7F9FBFDFF, low: 0xFEFCFAF0F8F6F472)),
                    byteSwapped: Int128((high: 0x72F4F6F8F0FAFCFE, low: 0xFFFDFBF9F7F5F371))))
    return tests
  }
  
  func testBigEndianProperty() {
    endianTests().forEach { test in
#if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
      let expectedResult = test.byteSwapped
#else
      let expectedResult = test.input
#endif
      XCTAssertEqual(test.input.bigEndian, expectedResult)
    }
  }
  
  func testBigEndianInitializer() {
    endianTests().forEach { test in
#if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
      let expectedResult = test.byteSwapped
#else
      let expectedResult = test.input
#endif
      
      XCTAssertEqual(Int128(bigEndian: test.input), expectedResult)
    }
  }
  
  func testLittleEndianProperty() {
    endianTests().forEach { test in
#if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
      let expectedResult = test.input
#else
      let expectedResult = test.byteSwapped
#endif
      
      XCTAssertEqual(test.input.littleEndian, expectedResult)
    }
  }
  
  func testLittleEndianInitializer() {
    endianTests().forEach { test in
#if arch(i386) || arch(x86_64) || arch(arm) || arch(arm64)
      let expectedResult = test.input
#else
      let expectedResult = test.byteSwapped
#endif
      
      XCTAssertEqual(Int128(littleEndian: test.input), expectedResult)
    }
  }
  
  func testByteSwappedProperty() {
    endianTests().forEach { test in
      XCTAssertEqual(test.input.byteSwapped, test.byteSwapped)
    }
  }
  
  func testInitWithTruncatingBits() {
    let testResult = Int128(_truncatingBits: UInt.max)
    XCTAssertEqual(testResult, Int128((high: 0, low: UInt64(UInt.max))))
  }
  
  func testAddingReportingOverflow() {
    // 0 + 0 = 0
    var tests = [(augend: Int128.zero, addend: Int128.zero,
                  sum: (partialValue: Int128.zero, overflow: false))]
    // Int128.max + 0 = Int128.max
    tests.append((augend: Int128.max, addend: Int128.zero,
                  sum: (partialValue: Int128.max, overflow: false)))
    // Int128.max + 1 = Int128.min, with overflow
    tests.append((augend: Int128.max, addend: Int128(1),
                  sum: (partialValue: Int128.min, overflow: true)))
    // Int128.max + 2 = Int128.min + 1 , with overflow
    tests.append((augend: Int128.max, addend: Int128(2),
                  sum: (partialValue: Int128.min+1, overflow: true)))
    // UInt64.max + 1 = UInt64.max + 1
    tests.append((augend: Int128(Int64.max), addend: Int128(1),
                  sum: (partialValue: Int128((high: 0, low: UInt64(Int64.max)+1)), overflow: false)))
    
    tests.forEach { test in
      let sum = test.augend.addingReportingOverflow(test.addend)
      XCTAssertEqual(sum.partialValue, test.sum.partialValue)
      XCTAssertEqual(sum.overflow, test.sum.overflow)
    }
  }
  
  func testSubtractingReportingOverflow() {
    // 0 - 0 = 0
    var tests = [(minuend: Int128(0), subtrahend: Int128(0),
                  difference: (partialValue: Int128(0), overflow: false))]
    // Int128.max - 0 = Int128.max
    tests.append((minuend: Int128.max, subtrahend: Int128(0),
                  difference: (partialValue: Int128.max, overflow: false)))
    // Int128.max - 1 = Int128.max - 1
    tests.append((minuend: Int128.max, subtrahend: Int128(1),
                  difference: (partialValue: Int128((high: Int64.max, low: (UInt64.max >> 1) << 1)), overflow: false)))
    // UInt64.max + 1 - 1 = UInt64.max
    tests.append((minuend: Int128((high: 1, low: 0)), subtrahend: Int128(1),
                  difference: (partialValue: Int128(UInt64.max), overflow: false)))
    // 0 - 1 = -1
    tests.append((minuend: Int128(0), subtrahend: Int128(1),
                  difference: (partialValue: Int128(-1), overflow: false)))
    // 0 - 2 = Int128.max - 1, with overflow
    tests.append((minuend: Int128(0), subtrahend: Int128(2),
                  difference: (partialValue: Int128(-2), overflow: false)))
    
    tests.forEach { test in
      let difference = test.minuend.subtractingReportingOverflow(test.subtrahend)
      XCTAssertEqual(difference.partialValue, test.difference.partialValue)
      XCTAssertEqual(difference.overflow, test.difference.overflow)
    }
  }
  
  func testMultipliedReportingOverflow() {
    // 0 * 0 = 0
    var tests = [(multiplier: Int128(0), multiplicator: Int128(0),
                  product: (partialValue: Int128(0), overflow: false))]
    // UInt64.max * UInt64.max = UInt128.max - UInt64.max - 1
    tests.append((multiplier: Int128(UInt64.max), multiplicator: Int128(UInt64.max),
                  product: (partialValue: Int128((high: Int64(bitPattern: UInt64.max-1), low: 1)), overflow: true)))
    // Int128.max * 0 = 0
    tests.append((multiplier: Int128.max, multiplicator: Int128(0),
                  product: (partialValue: Int128.zero, overflow: false)))
    // Int128.max * 1 = Int128.max
    tests.append((multiplier: Int128.max, multiplicator: Int128(1),
                  product: (partialValue: Int128.max, overflow: false)))
    // Int128.max * 2 = Int128.max - 1, with overflow
    tests.append((multiplier: Int128.max, multiplicator: Int128(2),
                  product: (partialValue: Int128((high: Int64(bitPattern: UInt64.max), low: UInt64.max-1)), overflow: true)))
    // Int128.max * Int128.max = 1, with overflow
    tests.append((multiplier: Int128.max, multiplicator: Int128.max,
                  product: (partialValue: Int128(1), overflow: true)))
    
    tests.forEach { test in
      let product = test.multiplier.multipliedReportingOverflow(by: test.multiplicator)
      XCTAssertEqual(product.partialValue, test.product.partialValue)
      XCTAssertEqual(product.overflow, test.product.overflow)
    }
  }
  
  func testMultipliedFullWidth() {
    var tests : [(multiplier:Int128, multiplicator:Int128, product: (high:Int128, low:UInt128))] =
    [(multiplier: Int128.zero, multiplicator: Int128.zero,
      product: (high: Int128.zero, low: UInt128.zero))]
    tests.append((multiplier: Int128(1), multiplicator: Int128(1),
                  product: (high: Int128.zero, low: UInt128(1))))
    tests.append((multiplier: Int128(Int64.max), multiplicator: Int128(Int64.max),
                  product: (high: Int128.zero, low: UInt128((high: UInt64.max >> 2, low: 1)))))
    tests.append((multiplier: Int128.max, multiplicator: Int128.max,
                  product: (high: (Int128.max - 1) >> 1, low: UInt128(1))))
    
    tests.forEach { test in
      let product = test.multiplier.multipliedFullWidth(by: test.multiplicator)
      XCTAssertEqual(
        product.high, test.product.high,
        "\n\(test.multiplier) * \(test.multiplicator) == (high: \(test.product.high), low: \(test.product.low)) != (high: \(product.high), low: \(product.low))\n")
      XCTAssertEqual(
        product.low, test.product.low,
        "\n\(test.multiplier) * \(test.multiplicator) == (high: \(test.product.high), low: \(test.product.low)) != (high: \(product.high), low: \(product.low))\n")
    }
  }
  
  func divisionTests() -> [(dividend: Int128, divisor: Int128, quotient: (partialValue: Int128, overflow: Bool), remainder: (partialValue: Int128, overflow: Bool))] {
    // 0 / 0 = 0, remainder 0, with overflow
    var tests = [(dividend: Int128.zero, divisor: Int128.zero,
                  quotient: (partialValue: Int128.zero, overflow: true),
                  remainder: (partialValue: Int128.zero, overflow: true))]
    // 0 / 1 = 0, remainder 0
    tests.append((dividend: Int128.zero, divisor: Int128(1),
                  quotient: (partialValue: Int128.zero, overflow: false),
                  remainder: (partialValue: Int128.zero, overflow: false)))
    // 0 / Int128.max = 0, remainder 0
    tests.append((dividend: Int128.zero, divisor: Int128.max,
                  quotient: (partialValue: Int128.zero, overflow: false),
                  remainder: (partialValue: Int128.zero, overflow: false)))
    // 1 / 0 = 1, remainder 1, with overflow
    tests.append((dividend: Int128(1), divisor: Int128.zero,
                  quotient: (partialValue: Int128(1), overflow: true),
                  remainder: (partialValue: Int128(1), overflow: true)))
    // Int128.max / Int64.max = Int128((high: 1, low: 2), remainder 1
    tests.append((dividend: Int128.max, divisor: Int128(Int64.max),
                  quotient: (partialValue: Int128((high: 1, low: UInt64(2))), overflow: false),
                  remainder: (partialValue: 1, overflow: false)))
    // Int128.max / Int128.max = 1, remainder 0
    tests.append((dividend: Int128.max, divisor: Int128.max,
                  quotient: (partialValue: Int128(1), overflow: false),
                  remainder: (partialValue: Int128.zero, overflow: false)))
    // UInt64.max / Int128.max = 0, remainder UInt64.max
    tests.append((dividend: Int128(UInt64.max), divisor: Int128.max,
                  quotient: (partialValue: Int128.zero, overflow: false),
                  remainder: (partialValue: Int128(UInt64.max), overflow: false)))
    return tests
  }
  
  func testDividedReportingOverflow() {
    divisionTests().forEach { test in
      let quotient = test.dividend.dividedReportingOverflow(by: test.divisor)
      XCTAssertEqual(
        quotient.partialValue, test.quotient.partialValue,
        "\(test.dividend) / \(test.divisor) == \(test.quotient.partialValue)")
      XCTAssertEqual(
        quotient.overflow, test.quotient.overflow,
        "\(test.dividend) / \(test.divisor) has overflow? \(test.remainder.overflow)")
    }
  }
  
  func testDividingFullWidth() throws {
    // (0, 1) / 1 = 1r0
    var tests: [(dividend:(high:Int128, low:UInt128), divisor:Int128, result: (quotient: Int128, remainder: Int128))] =
    [(dividend: (high: 0, low: UInt128(1)),
      divisor: Int128(1),
      result: (quotient: Int128(1), remainder: 0))]
    // (1, 0) / 1 = 0r0
    tests.append((dividend: (high: Int128(1), low: 0),
                  divisor: Int128(1),
                  result: (quotient: 0, remainder: 0)))
    // (1, 0) / 4 = 170141183460469231731687303715884105728r0
      tests.append((dividend: (high: Int128(1), low: UInt128.zero),
                    divisor: Int128(4),
                    result: (quotient: try XCTUnwrap(Int128(85_070_591_730_234_615_865_843_651_857_942_052_864)),
                             remainder: 0)))
    
    tests.forEach { test in
      let result = test.divisor.dividingFullWidth(test.dividend)
      XCTAssertEqual(
        result.quotient, test.result.quotient,
        "\n\(test.dividend) / \(test.divisor) == \(test.result)")
      XCTAssertEqual(
        result.remainder, test.result.remainder,
        "\n\(test.dividend) / \(test.divisor) == \(test.result)")
    }
  }
  
  func testRemainderReportingOverflow() {
    divisionTests().forEach { test in
      let remainder = test.dividend.remainderReportingOverflow(dividingBy: test.divisor)
      XCTAssertEqual(
        remainder.partialValue, test.remainder.partialValue,
        "\(test.dividend) / \(test.divisor) has a remainder of \(test.remainder.partialValue)")
      XCTAssertEqual(
        remainder.overflow, test.remainder.overflow,
        "\(test.dividend) / \(test.divisor) has overflow? \(test.remainder.overflow)")
    }
  }
  
  func testQuotientAndRemainder() {
    divisionTests().forEach { test in
      guard test.divisor != 0 else { return }
      
      let result = test.dividend.quotientAndRemainder(dividingBy: test.divisor)
      XCTAssertEqual(
        result.quotient, test.quotient.partialValue,
        "\(test.dividend) / \(test.divisor) == \(test.quotient.partialValue)")
      XCTAssertEqual(
        result.remainder, test.remainder.partialValue,
        "\(test.dividend) / \(test.divisor) has a remainder of \(test.remainder.partialValue)")
    }
  }
}

class BinaryInteger128Tests : XCTestCase {
  func testBitWidthEquals128() {
    XCTAssertEqual(Int128.bitWidth, 128)
  }
  
  func testTrailingZeroBitCount() {
    var tests = [(input: Int128.zero, expected: 128)]
    tests.append((input: Int128(1), expected: 0))
    tests.append((input: Int128((high: 1, low: 0)), expected: 64))
    tests.append((input: Int128.max, expected: 0))
    
    tests.forEach { test in
      XCTAssertEqual(test.input.trailingZeroBitCount, test.expected)}
  }
  
  func testInitFailableFloatingPointExactlyExpectedSuccesses() {
    var tests = [(input: Float(), result: Int128())]
    tests.append((input: Float(1), result: Int128(1)))
    tests.append((input: Float(1.0), result: Int128(1)))
    
    tests.forEach { test in
      XCTAssertEqual(Int128(exactly: test.input), test.result)
    }
  }
  
  func testInitFailableFloatingPointExactlyExpectedFailures() {
    var tests = [Float(1.1)]
    tests.append(Float(0.1))
    
    tests.forEach { test in
      XCTAssertEqual(Int128(exactly: test), nil)
    }
  }
  
  func testInitFloatingPoint() {
#if arch(x86_64)
    var tests = [(input: Float80(), result: Int128())]
    tests.append((input: Float80(0.1), result: Int128()))
    tests.append((input: Float80(1.0), result: Int128(1)))
    tests.append((input: Float80(UInt64.max), result: Int128(UInt64.max)))
#else
    var tests = [(input: 0.0, result: Int128())]
    tests.append((input: 0.1, result: Int128()))
    tests.append((input: 1.0, result: Int128(1)))
    tests.append((input: Double(UInt32.max), result: Int128(UInt32.max)))
#endif
    
    tests.forEach { test in
      XCTAssertEqual(Int128(test.input), test.result)
    }
  }
  
  func test_word() {
    let lowerBits = UInt64(0b100000000000000000000000000000001)
    let upperBits = Int64(0b100000000000000000000000000000001)
    let testResult = Int128((high: upperBits, low: lowerBits))
    
    testResult.words.forEach { (currentWord) in
      if UInt.bitWidth == 64 {
        XCTAssertEqual(currentWord, 4294967297)
      }
    }
  }
  
  func divisionTests() -> [(dividend: Int128, divisor: Int128, quotient: Int128, remainder: Int128)] {
    // 0 / 1 = 0, remainder 0
    var tests: [(dividend: Int128, divisor: Int128, quotient: Int128, remainder: Int128)]  =
    [(dividend: Int128.zero, divisor: Int128(1),
      quotient: Int128.zero, remainder: Int128.zero)]
    // 2 / 1 = 2, remainder 0
    tests.append((dividend: Int128(2), divisor: Int128(1),
                  quotient: Int128(2), remainder: Int128.zero))
    // 1 / 2 = 0, remainder 1
    tests.append((dividend: Int128(1), divisor: Int128(2),
                  quotient: Int128(0), remainder: Int128(1)))
    // Int128.max / UInt64.max = Int128((high: 1, low: 1), remainder 0
    tests.append((dividend: Int128.max, divisor: Int128(UInt64.max),
                  quotient: Int128((high: 0, low: UInt64(Int64.max)))+1, remainder: Int128.zero))
    // Int128.max / Int128.max = 1, remainder 0
    tests.append((dividend: Int128.max, divisor: Int128.max,
                  quotient: Int128(1), remainder: Int128.zero))
    // UInt64.max / Int128.max = 0, remainder UInt64.max
    tests.append((dividend: Int128(UInt64.max), divisor: Int128.max,
                  quotient: Int128.zero, remainder: Int128(UInt64.max)))
    return tests
  }
  
  func testDivideOperator() {
    divisionTests().forEach { test in
      let quotient = test.dividend / test.divisor
      XCTAssertEqual(
        quotient, test.quotient,
        "\(test.dividend) / \(test.divisor) == \(test.quotient)")
    }
  }
  
  func testDivideEqualOperator() {
    divisionTests().forEach { test in
      var quotient = test.dividend
      quotient /= test.divisor
      XCTAssertEqual(
        quotient, test.quotient,
        "\(test.dividend) /= \(test.divisor) == \(test.quotient)")
    }
  }
  
  func moduloTests() -> [(dividend: Int128, divisor: Int128, remainder: Int128)] {
    // 0 % 1 = 0
    var tests: [(dividend: Int128, divisor: Int128, remainder: Int128)] =
    [(dividend: Int128.zero, divisor: Int128(1), remainder: Int128.zero)]
    // 1 % 2 = 1
    tests.append((dividend: Int128(1), divisor: Int128(2),
                  remainder: Int128(1)))
    // 0 % Int128.max = 0
    tests.append((dividend: Int128.zero, divisor: Int128.max,
                  remainder: Int128.zero))
    // Int128.max % Int64.max = 0
    tests.append((dividend: Int128.max, divisor: Int128(Int64.max),
                  remainder: Int128(1)))
    // Int128.max % Int128.max = 0
    tests.append((dividend: Int128.max, divisor: Int128.max,
                  remainder: Int128.zero))
    // UInt64.max % Int128.max = UInt64.max
    tests.append((dividend: Int128(UInt64.max), divisor: Int128.max,
                  remainder: Int128(UInt64.max)))
    return tests
  }
  
  func testModuloOperator() {
    moduloTests().forEach { test in
      let remainder = test.dividend % test.divisor
      XCTAssertEqual(
        remainder, test.remainder,
        "\(test.dividend) % \(test.divisor) == \(test.remainder)")
    }
  }
  
  func testModuloEqualOperator() {
    moduloTests().forEach { test in
      var remainder = test.dividend
      remainder %= test.divisor
      XCTAssertEqual(
        remainder, test.remainder,
        "\(test.dividend) %= \(test.divisor) == \(test.remainder)")
    }
  }
  
  func testBooleanAndEqualOperator() {
    var tests: [(lhs: Int128, rhs: Int128, result: Int128)] =
    [(lhs: Int128.zero, rhs: Int128.zero, result: Int128.zero)]
    tests.append((lhs: Int128(1), rhs: Int128(1), result: Int128(1)))
    tests.append((lhs: Int128.zero, rhs: Int128.max, result: Int128.zero))
    tests.append((lhs: Int128((high: Int64.min, low: UInt64.max)),
                  rhs: Int128((high: Int64.max, low: UInt64.min)),
                  result: Int128.zero))
      tests.append((lhs: Int128((high: 0x71F3F5F7F9FBFDFF, low: 0xFEFCFAF0F8F6F4F2)),
                    rhs: Int128((high: 0x72F4F6F8F0FAFCFE, low: 0xFFFDFBF9F7F5F3F1)),
                    result: Int128((high: 0x70F0F4F0F0FAFCFE, low: 0xFEFCFAF0F0F4F0F0))))
    tests.append((lhs: Int128.max, rhs: Int128.max, result: Int128.max))
    
    tests.forEach { test in
      var result = test.lhs
      result &= test.rhs
      XCTAssertEqual(result, test.result)
    }
  }
  
  func testBooleanOrEqualOperator() {
    var tests: [(lhs: Int128, rhs: Int128, result: Int128)] =
    [(lhs: Int128.zero, rhs: Int128.zero, result: Int128.zero)]
    tests.append((lhs: Int128(1), rhs: Int128(1), result: Int128(1)))
    tests.append((lhs: Int128.zero, rhs: Int128.max, result: Int128.max))
    tests.append((lhs: Int128((high: Int64.zero, low: UInt64.max)),
                  rhs: Int128((high: Int64.max, low: UInt64.min)),
                  result: Int128.max))
      tests.append((lhs: Int128((high: 0x71F3F5F7F9FBFDFF, low: 0xFEFCFAF0F8F6F4F2)),
                    rhs: Int128((high: 0x72F4F6F8F0FAFCFE, low: 0xFFFDFBF9F7F5F3F1)),
                    result: Int128((high: 0x73F7F7FFF9FBFDFF, low: 18446176699939289075))))
    tests.append((lhs: Int128.max, rhs: Int128.max, result: Int128.max))
    
    tests.forEach { test in
      var result = test.lhs
      result |= test.rhs
      XCTAssertEqual(result, test.result)
    }
  }
  
  func testBooleanXorEqualOperator() {
    var tests: [(lhs: Int128, rhs: Int128, result: Int128)] =
    [(lhs: Int128.zero, rhs: Int128.zero, result: Int128.zero)]
    tests.append((lhs: Int128(1), rhs: Int128(1), result: Int128.zero))
    tests.append((lhs: Int128.zero, rhs: Int128.max, result: Int128.max))
    tests.append((lhs: Int128((high: Int64.zero, low: UInt64.max)),
                  rhs: Int128((high: Int64.max, low: UInt64.min)),
                  result: Int128.max))
      tests.append((lhs: Int128((high: 0x71F3F5F7F9FBFDFF, low: 0xFEFCFAF0F8F6F4F2)),
                    rhs: Int128((high: 0x72F4F6F8F0FAFCFE, low: 0xFFFDFBF9F7F5F3F1)),
                    result: Int128((high: 218146470061211905, low: 72340207432828675))))
    tests.append((lhs: Int128.max, rhs: Int128.max, result: Int128.zero))
    
    tests.forEach { test in
      var result = test.lhs
      result ^= test.rhs
      XCTAssertEqual(result, test.result)
    }
  }
  
  func testMaskingRightShiftEqualOperatorStandardCases() {
    var tests = [(input: Int128((high: Int64.max, low: 0)),
                  shiftWidth: UInt64(126),
                  expected: Int128((high: 0, low: 1)))]
    tests.append((input: Int128((high: 1, low: 0)),
                  shiftWidth: UInt64(64),
                  expected: Int128((high: 0, low: 1))))
    tests.append((input: Int128((high: 0, low: 1)),
                  shiftWidth: UInt64(1),
                  expected: Int128()))
    
    tests.forEach { test in
      var testValue = test.input
      testValue &>>= Int128((high: 0, low: test.shiftWidth))
      XCTAssertEqual(testValue, test.expected)
    }
  }
  
  func testMaskingRightShiftEqualOperatorEdgeCases() {
    var tests = [(input: Int128((high: 0, low: 2)),
                  shiftWidth: UInt64(129),
                  expected: Int128((high: 0, low: 1)))]
    tests.append((input: Int128((high: Int64.max, low: 0)),
                  shiftWidth: UInt64(128),
                  expected: Int128((high: Int64.max, low: 0))))
    tests.append((input: Int128((high: 0, low: 1)),
                  shiftWidth: UInt64(0),
                  expected: Int128((high: 0, low: 1))))
    
    tests.forEach { test in
      var testValue = test.input
      testValue &>>= Int128((high: 0, low: test.shiftWidth))
      XCTAssertEqual(testValue, test.expected)
    }
  }
  
  func testMaskingLeftShiftEqualOperatorStandardCases() {
    let int64_1_in_msb: Int64 = 2 << 62
    var tests = [(input: Int128((high: 0, low: 1)),
                  shiftWidth: UInt64(127),
                  expected: Int128((high: int64_1_in_msb, low: 0)))]
    tests.append((input: Int128((high: 0, low: 1)),
                  shiftWidth: UInt64(64),
                  expected: Int128((high: 1, low: 0))))
    tests.append((input: Int128((high: 0, low: 1)),
                  shiftWidth: UInt64(1),
                  expected: Int128((high: 0, low: 2))))
    
    tests.forEach { test in
      var testValue = test.input
      testValue &<<= Int128((high: 0, low: test.shiftWidth))
      XCTAssertEqual(testValue, test.expected)
    }
  }
  
  func testMaskingLeftShiftEqualOperatorEdgeCases() {
    var tests = [(input: Int128((high: 0, low: 2)),
                  shiftWidth: UInt64(129),
                  expected: Int128((high: 0, low: 4)))]
    tests.append((input: Int128((high: 0, low: 2)),
                  shiftWidth: UInt64(128),
                  expected: Int128((high: 0, low: 2))))
    tests.append((input: Int128((high: 0, low: 1)),
                  shiftWidth: UInt64(0),
                  expected: Int128((high: 0, low: 1))))
    
    tests.forEach { test in
      var testValue = test.input
      testValue &<<= Int128((high: 0, low: test.shiftWidth))
      XCTAssertEqual(testValue, test.expected)
    }
  }
}

class NumericInt128Tests : XCTestCase {
  func additionTests() -> [(augend: Int128, addend: Int128, sum: Int128)] {
    // 0 + 0 = 0
    var tests: [(augend: Int128, addend: Int128, sum: Int128)] = [(augend: 0, addend: 0, sum: 0)]
    // 1 + 1 = 2
    tests.append((augend: Int128(1), addend: Int128(1), sum: Int128(2)))
    // Int128.max + 0 = Int128.max
    tests.append((augend: Int128.max, addend: 0, sum: Int128.max))
    // UInt64.max + 1 = UInt64.max + 1
    tests.append((augend: Int128(UInt64.max), addend: Int128(1),
                  sum: Int128((high: 1, low: 0))))
    return tests
  }
  
  func testAdditionOperator() {
    additionTests().forEach { test in
      let sum = test.augend + test.addend
      XCTAssertEqual(
        sum, test.sum,
        "\(test.augend) + \(test.addend) == \(test.sum)")
    }
  }
  
  func testAdditionEqualOperator() {
    additionTests().forEach { test in
      var sum = test.augend
      sum += test.addend
      XCTAssertEqual(
        sum, test.sum,
        "\(test.augend) += \(test.addend) == \(test.sum)")
    }
  }
  
  func subtractionTests() -> [(minuend: Int128, subtrahend: Int128, difference: Int128)] {
    // 0 - 0 = 0
    var tests: [(minuend: Int128, subtrahend: Int128, difference: Int128)] =
    [(minuend: 0, subtrahend: 0, difference: 0)]
    // Uint128.max - 0 = Int128.max
    tests.append((minuend: Int128.max, subtrahend: 0, difference: Int128.max))
    // Int128.max - 1 = Int128.max - 1
    tests.append((minuend: Int128.max, subtrahend: Int128(1),
                  difference: Int128((high: Int64.max, low: (UInt64.max >> 1) << 1))))
    // UInt64.max + 1 - 1 = UInt64.max
    tests.append((minuend: Int128((high: 1, low: 0)), subtrahend: Int128(1),
                  difference: Int128(UInt64.max)))
    return tests
  }
  
  func testSubtractionOperator() {
    subtractionTests().forEach { test in
      let difference = test.minuend - test.subtrahend
      XCTAssertEqual(
        difference, test.difference,
        "\(test.minuend) - \(test.subtrahend) == \(test.difference)")
    }
  }
  
  func testSubtractionEqualOperator() {
    subtractionTests().forEach { test in
      var difference = test.minuend
      difference -= test.subtrahend
      XCTAssertEqual(
        difference, test.difference,
        "\(test.minuend) -= \(test.subtrahend) == \(test.difference)")
    }
  }
  
  func multiplicationTests() -> [(multiplier: Int128, multiplicator: Int128, product: Int128)] {
    // 0 * 0 = 0
    var tests: [(multiplier: Int128, multiplicator: Int128, product: Int128)] =
    [(multiplier: Int128.zero, multiplicator: Int128.zero, product: Int128.zero)]
    // Int64.max * Int64.max = Int128.max - UInt64.max - 1
    tests.append((multiplier: Int128(Int64.max), multiplicator: Int128(Int64.max),
                  product: Int128((high: Int64.max >> 1, low: 1))))
    // Int128.max * 0 = 0
    tests.append((multiplier: Int128.max, multiplicator: 0,
                  product: Int128.zero))
    // Int128.max * 1 = Int128.max
    tests.append((multiplier: Int128.max, multiplicator: Int128(1),
                  product: Int128.max))
    return tests
  }
  
  func testMultiplicationOperator() {
    multiplicationTests().forEach { test in
      let product = test.multiplier * test.multiplicator
      XCTAssertEqual(
        product, test.product,
        "\(test.multiplier) * \(test.multiplicator) == \(test.product)")
    }
  }
  
  func testMultiplicationEqualOperator() {
    multiplicationTests().forEach { test in
      var product = test.multiplier
      product *= test.multiplicator
      XCTAssertEqual(
        product, test.product,
        "\(test.multiplier) *= \(test.multiplicator) == \(test.product)")
    }
  }
}

class EquatableInt128Tests : XCTestCase {
  func testBooleanEqualsOperator() {
    var tests = [(lhs: Int128.zero,
                  rhs: Int128.zero, result: true)]
    tests.append((lhs: Int128.zero,
                  rhs: Int128(1), result: false))
    tests.append((lhs: Int128.max,
                  rhs: Int128.max, result: true))
    tests.append((lhs: Int128(UInt64.max),
                  rhs: Int128((high: Int64.max, low: UInt64.min)), result: false))
    tests.append((lhs: Int128((high: 1, low: 0)),
                  rhs: Int128((high: 1, low: 0)), result: true))
    tests.append((lhs: Int128((high: 1, low: 0)),
                  rhs: Int128(), result: false))
    
    tests.forEach { test in
      XCTAssertEqual(test.lhs == test.rhs, test.result)
    }
  }
}

class ExpressibleByInteger128LiteralTests : XCTestCase {
  func testInitWithIntegerLiteral() {
    var tests: [(input: Int64, result: Int128)]
    tests = [(input: 0, result: Int128())]
    tests.append((input: 1, result: Int128((high: 0, low: 1))))
    tests.append((input: 9223372036854775807, result: Int128((high: 0, low: UInt64(Int.max)))))
    
    tests.forEach { test in
      XCTAssertEqual(Int128(test.input), test.result)
    }
  }
}

class CustomStringConvertibleInt128Tests : XCTestCase {
  func stringTests() -> [(input: Int128, result: [Int: String])] {
    var tests = [(input: Int128(), result:[
      2: "0", 8: "0", 10: "0", 16: "0", 18: "0", 36: "0"])]
    tests.append((input: Int128(1), result: [
      2: "1", 8: "1", 10: "1", 16: "1", 18: "1", 36: "1"]))
    tests.append((input: Int128(UInt64.max), result: [
      2: "1111111111111111111111111111111111111111111111111111111111111111",
      8: "1777777777777777777777",
      10: "18446744073709551615",
      16: "ffffffffffffffff",
      18: "2d3fgb0b9cg4bd2f",
      36: "3w5e11264sgsf"]))
    tests.append((input: Int128((high: 1, low: 0)), result: [
      2: "10000000000000000000000000000000000000000000000000000000000000000",
      8: "2000000000000000000000",
      10: "18446744073709551616",
      16: "10000000000000000",
      18: "2d3fgb0b9cg4bd2g",
      36: "3w5e11264sgsg"]))
    tests.append((input: Int128.max, result: [
      2: "11111111111111111111111111111111111111111111111111111111111111111" +
         "11111111111111111111111111111111111111111111111111111111111111",
      8: "1777777777777777777777777777777777777777777",
      10: "170141183460469231731687303715884105727",
      16: "7fffffffffffffffffffffffffffffff",
      18: "3d51ddf66g5befc8e19d2607hc26e31",
      36: "7ksyyizzkutudzbv8aqztecjj"]))
    return tests
  }
  
  func testDescriptionProperty() {
    stringTests().forEach { test in
      XCTAssertEqual(test.input.description, test.result[10])
    }
  }
  
  func testStringDescribingInitializer() {
    stringTests().forEach { test in
      XCTAssertEqual(String(describing: test.input), test.result[10])
    }
  }
  
  func testStringInt128InitializerLowercased() {
    stringTests().forEach { test in
      test.result.forEach { result in
        let (radix, result) = result
        let testOutput = String(test.input, radix: radix)
        XCTAssertEqual(testOutput, result)
      }
    }
  }
  
  func testStringInt128InitializerUppercased() {
    stringTests().forEach { test in
      test.result.forEach { result in
        let (radix, result) = result
        let testOutput = String(test.input, radix: radix, uppercase: true)
        XCTAssertEqual(testOutput, result.uppercased())
      }
    }
  }
  
}

class CustomDebugStringConvertibleInt128Tests : XCTestCase {
  func stringTests() -> [(input: Int128, result: String)] {
    var tests = [(input: Int128(),
                  result:"0")]
    tests.append((input: Int128(1),
                  result: "1"))
    tests.append((input: Int128(UInt64.max),
                  result: "18446744073709551615"))
    tests.append((input: Int128((high: 1, low: 0)),
                  result: "18446744073709551616"))
    tests.append((input: Int128.max,
                  result: "170141183460469231731687303715884105727"))
    return tests
  }
  
  
  func testDebugDescriptionProperty() {
    stringTests().forEach { test in
      XCTAssertEqual(test.input.debugDescription, test.result)
    }
  }
  
  func testStringReflectingInitializer() {
    stringTests().forEach { test in
      XCTAssertEqual(String(reflecting: test.input), test.result)
    }
  }
}

class ComparableInt128Tests : XCTestCase {
  func testLessThanOperator() {
    var tests = [(lhs: Int128.zero, rhs: Int128(1), result: true)]
    tests.append((lhs: Int128.zero, rhs: Int128((high: 1, low: 0)), result: true))
    tests.append((lhs: Int128(1), rhs: Int128((high: 1, low: 0)), result: true))
    tests.append((lhs: Int128(UInt64.max), rhs: Int128.max, result: true))
    tests.append((lhs: Int128.zero, rhs: Int128.zero, result: false))
    tests.append((lhs: Int128.max, rhs: Int128.max, result: false))
    tests.append((lhs: Int128.max, rhs: Int128(UInt64.max), result: false))
    
    tests.forEach { test in
      XCTAssertEqual(test.lhs < test.rhs, test.result)
    }
  }
}

class FailableStringInitializerInt128Tests : XCTestCase {
  func stringTests() -> [(input: String, radix: Int, result: Int128?)] {
    var tests = [(input: "", 10, result: nil as Int128?)]
    tests.append((input: "0", 10, result: Int128()))
    tests.append((input: "1", 10, result: Int128(1)))
    tests.append((input: "99", 10, result: Int128(99)))
    tests.append((input: "0101", 2, result: Int128(5)))
    tests.append((input: "11", 8, result: Int128(9)))
    tests.append((input: "FF", 16, result: Int128(255)))
    tests.append((input: "0z1234", 10, result: nil))
    return tests
  }
  
  func testInitWithStringLiteral() {
    stringTests().forEach { test in
      XCTAssertEqual(Int128(test.input, radix: test.radix), test.result)
    }
  }
  
  func testEvaluatedWithStringLiteral() {
    let binaryTest = Int128("11", radix: 2)
    XCTAssertEqual(binaryTest, Int128(3))
    
    let octalTest = Int128("11", radix: 8)
    XCTAssertEqual(octalTest, Int128(9))
    
    let decimalTest = Int128("11", radix: 10)
    XCTAssertEqual(decimalTest, Int128(11))
    
    let hexTest = Int128("11", radix: 16)
    XCTAssertEqual(hexTest, Int128(17))
  }
}

final class CodableInt128Tests : XCTestCase {
  func testCodable() throws {
      let enc = try XCTUnwrap(Int128(170_141_183_460_469_231_731_687_303_715_884_105_727))
    let data = try! JSONEncoder().encode(enc)
    let dec = try! JSONDecoder().decode(Int128.self, from: data)
    XCTAssertEqual(enc, dec)
  }
}

final class FloatingPointInterworkingInt128Tests : XCTestCase {
  func testNonFailableInitializer() throws {
    var tests = [(input: Int128(), output: Float(0))]
    tests.append((input: Int128((high: 0, low: UInt64.max)),
                  output: Float(UInt64.max)))
    
    tests.forEach { test in
      XCTAssertEqual(Float(test.input), test.output)
    }
  }
  
  func testFailableInitializer() throws {
    var tests = [(input: Int128(),
                  output: Float(0) as Float?)]
    tests.append((input: Int128((high: 0, low: UInt64.max)),
                  output: Float(UInt64.max) as Float?))
    tests.append((input: Int128((high: 1, low: 0)),
                  output: nil))
    
    tests.forEach { test in
      XCTAssertEqual(Float(exactly: test.input), test.output)
    }
  }
}

final class BasicInt128Tests: XCTestCase {
  
  func testBasicMath() throws {
    // Basic go/nogo test to verify the basic operations
    let x = Int128(123_456_789_012_345_678_901_234_567_890)
    let y = Int128(100_000_000)
    let z = x + y
    let v = x - y
    let a = x / y
    let b = x % y
    let c = x * y
    let d = x & y
    let e = x | y
    let f = x ^ y
    let g = ~x
    let h = Int128(0x1234_5678_90AB_CDEF_1234_5678_90AB_CDEF)
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
    print("Random 128-bit = \(Int128.random(in: 0...Int128.max))")
    let sh = String(h.byteSwapped, radix:16, uppercase: true)
    let sh2 = String(h.littleEndian, radix:16, uppercase: true)
    print("0x1234_5678_90AB_CDEF_1234_5678_90AB_CDEF byte swapped = \(sh)")
    print("0x1234_5678_90AB_CDEF_1234_5678_90AB_CDEF little endian = \(sh2)")
    print("Int128.max = \(Int128.max)")
    XCTAssertEqual(Int128.max.description, "170141183460469231731687303715884105727")
    XCTAssertEqual(x.description, "123456789012345678901234567890")
    XCTAssertEqual(y.description, "100000000")
    XCTAssertEqual(z.description, "123456789012345678901334567890")
    XCTAssertEqual(v.description, "123456789012345678901134567890")
    XCTAssertEqual(a.description, "1234567890123456789012")
    XCTAssertEqual(b.description, "34567890")
    XCTAssertEqual(c.description, "12345678901234567890123456789000000000")
    XCTAssertEqual(d.description, "70582272")
    XCTAssertEqual(e.description, "123456789012345678901263985618")
    XCTAssertEqual(f.description, "123456789012345678901193403346")
    XCTAssertEqual(g.description, "-123456789012345678901234567891")
    XCTAssertEqual(sh, "-1032546F87A9CBED1032546F87A9CBEE")
  }
  
  func testPerformanceInt128Multiply() {
    // Multiply is 13X faster than Int128 from Gerber
    let x = Int128(123_456_789_012_345_678_901_234_567_890)
    let y = Int128(100_000_000)
    self.measure {
      for _ in 1...1000 {
        let _ = x * y
      }
    }
  }
  
  func testPerformanceInt128Divide() {
    // Divide is 40X faster than Int128 from Gerber
    let x = Int128(123_456_789_012_345_678_901_234_567_890)
    let y = Int128(100_000_000)
    self.measure {
      for _ in 1...1000 {
        let _ = x / y
      }
    }
  }
  
  func testPerformanceInt128FromString() {
    // Int128 from String is 39X faster than Int128 from Gerber
    self.measure {
      for _ in 1...1000 {
        let _ = Int128("123456789012345678901234567890")
      }
    }
  }
  
  func testPerformanceInt128ToString() {
    // Int128 to String is 23X faster than Apple's version
    self.measure {
      for _ in 1...1000 {
        let _ = String(Int128.max, radix: 10)
      }
    }
  }
}


