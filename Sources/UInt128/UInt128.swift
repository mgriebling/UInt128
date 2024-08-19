/**
Copyright © 2023 Computer Inspirations. All rights reserved.
Portions are Copyright (c) 2014 - 2021 Apple Inc. and the
Swift project authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/// A 128-bit unsigned integer type.
public struct UInt128 : Codable {
  public typealias High = UInt64
  public typealias Low = UInt64

  /// The low part of the value.
  internal var low: Low
  public var _low: UInt64 { low }

  /// The high part of the value.
  internal var high: High
  public var _high: UInt64 { high }

  /// Creates a new instance from the given tuple of high and low parts.
  ///
  /// - Parameter value: The tuple to use as the source of the new instance's
  ///   high and low parts.
  public init(_ value: (high: High, low: Low)) {
    self.low = value.low
    self.high = value.high
  }

  public init(high: High, low: Low) {
    self.low = low
    self.high = high
  }
    
  public init(_high: High, _low: Low) {
    self.low = _low
    self.high = _high
  }

  public init() {
    self.init(high: 0, low: 0)
  }

  public init(bitPattern v: Int128) {
    self.init(high: High(bitPattern: v.high), low: v.low)
  }

  public static var zero: Self { Self(high: 0, low: 0) }
  public static var one: Self { Self(high: 0, low: 1) }
}

extension UInt128 {
  /// Divides `x` by rⁿ where r is the `radix`. Returns the quotient,
  /// remainder, and digits
  static func _div(x:UInt128, radix:Int) -> (q:UInt128, r:UInt64, digits:Int) {
    var digits = _maxPowers[radix-2]
    let maxDivisor: UInt64
    let r: (quotient:UInt128.Magnitude, remainder:UInt128.Magnitude)
    
    // set the maximum radix power for the divisor
    switch radix {
      case  2: maxDivisor = 0x8000_0000_0000_0000
      case  4: maxDivisor = 0x4000_0000_0000_0000
      case  8: maxDivisor = 0x8000_0000_0000_0000
      case 10: maxDivisor = 10_000_000_000_000_000_000
      case 16: maxDivisor = 0x1000_0000_0000_0000
      case 32: maxDivisor = 0x1000_0000_0000_0000
      default:
        // Compute the maximum divisor for a worst-case radix of 36
        // Max radix = 36 so 36¹² = 4_738_381_338_321_616_896 < UInt64.max
        var power = radix * radix       // squared
        power *= power                  // 4th power
        power = power * power * power   // 12th power
        maxDivisor = UInt64(power)
        digits = 12
    }
    r = x.quotientAndRemainder(dividingBy: UInt128(high: 0, low: maxDivisor))
    return (r.quotient, r.remainder.low, digits)
  }
  
  /// Converts the UInt128 `self` into a string with a given `radix`.  The
  /// radix string can use uppercase characters if `uppercase` is true.
  ///
  /// Why convert numbers in chunks?  This approach reduces the number of
  /// calls to division and modulo functions so is more efficient than a naïve
  /// digit-based approach.  Ideally this code should be in the String module.
  /// Further optimizations may be possible by using unchecked string buffers.
  internal func _description(radix:Int=10, uppercase:Bool=false) -> String {
    guard 2...36 ~= radix else { return "0" }
    if self == Self.zero { return "0" }
    var result = (q:self.magnitude, r:UInt64(0), digits:0)
    var str = ""
    while result.q != Self.zero {
      result = Self._div(x: result.q, radix: radix)
      var temp = String(result.r, radix: radix, uppercase: uppercase)
      if result.q != Self.zero {
        temp = String(repeating: "0", count: result.digits-temp.count) + temp
      }
      str = temp + str
    }
    return str
  }
}

extension String {
  public init(_ n: UInt128, radix: Int = 10, uppercase: Bool = false) {
    self = n._description(radix: radix, uppercase: uppercase)
  }
}

extension UInt128 : CustomStringConvertible {
  public var description: String {
    _description(radix: 10)
  }
}

extension UInt128: CustomDebugStringConvertible {
  public var debugDescription: String {
    description
  }
}


extension UInt128 : ExpressibleByIntegerLiteral {
  public typealias IntegerLiteralType = StaticBigInt
  
  public init(integerLiteral value: StaticBigInt) {
    precondition(Low.bitWidth == 64, "Expecting 64-bit UInt")
    precondition(value.signum() >= 0, "UInt128 literal cannot be negative")
    precondition(value.bitWidth <= Self.bitWidth+1,
                 "\(value.bitWidth)-bit literal too large for UInt128")
    self.init(high: High(value[1]), low: Low(value[0]))
  }
}

extension UInt128 {
  public init?<S: StringProtocol>(_ text: S, radix: Int = 10) {
    guard !text.isEmpty else { return nil }
    guard 2...36 ~= radix else { return nil }
    self.init()
    if let x = Self.value(from: text, radix: radix) {
      self = x
    } else {
      return nil
    }
  }
  
  public init?(_ description: String) {
    self.init(description, radix:10)
  }
}

extension UInt128 {
  /// This method breaks `string` into pieces to reduce overhead of the
  /// multiplications and allow UInt64 to work in converting larger numbers.
  static func value<S: StringProtocol>(
    from string: S, radix: Int = 10) -> Self? {
    // Handles signs and leading zeros
    var s = String(string)
    let uradix = UInt64(radix)
    if s.hasPrefix("-") { return nil }
    if s.hasPrefix("+") { s.removeFirst() }
    while s.hasPrefix("0") { s.removeFirst() }
    
    // Translate the string into a number
    var r = UInt128.zero
    while !s.isEmpty {
      // handle `chunk`-sized digits at a time
      let chunk = s.prefix(UInt128._maxPowers[radix-2])
      let size = chunk.count; s.removeFirst(size)
      if let uint = UInt64(chunk, radix: radix) {
        if size != 0 {
          r = UInt128._multiply(r, timesRadix: uradix, toPower: size)
        }
        r += UInt128(high: 0, low: uint)
      } else {
        return nil
      }
    }
    return Self(r)
  }
  /// Multiplies `x` by rⁿ where r is the `radix` and returns the product
  static func _multiply<T:FixedWidthInteger>(
    _ x: T, timesRadix radix: UInt64, toPower n: Int) -> T {
    // calculate the powers of the radix and store in a table
    func power(of radix:UInt64, to n:Int) -> UInt64 {
      var t = radix
      var n = n
      while n > 0 && t < UInt64.max / radix {
        t &*= radix; n -= 1
      }
      return t
    }
    let radixToPower: UInt64
    if radix == 10 {
      radixToPower = Self._powers10[n-1]
    } else {
      radixToPower = power(of: radix, to: n-1)
    }
    return x * T(radixToPower)
  }
  
  /// Maximum power of the `radix` for an unsigned 64-bit UInt for base
  /// indices of 2...36
  static let _maxPowers : [Int] = [
    63, 40, 31, 27, 24, 22, 21, 20, 19, 18, 17, 17, 16, 16, 15, 15, 15, 15,
    14, 14, 14, 14, 13, 13, 13, 13, 13, 13, 13, 13, 13, 12, 12, 12, 12, 12, 12
  ]

  /// Computed powers of 10ⁿ up to UInt64.max
  static let _powers10 : [UInt64] = [
    10, 100, 1_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000,
    1_000_000_000, 10_000_000_000, 100_000_000_000, 1_000_000_000_000,
    10_000_000_000_000, 100_000_000_000_000, 1_000_000_000_000_000,
    10_000_000_000_000_000, 100_000_000_000_000_000, 1_000_000_000_000_000_000,
    10_000_000_000_000_000_000
  ]
}

extension UInt128: Equatable {
  public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
    return (lhs.high, lhs.low) == (rhs.high, rhs.low)
  }
}

extension UInt128: Comparable {
  public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
    (lhs.high, lhs.low) < (rhs.high, rhs.low)
  }
}

extension UInt128: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(low)
    hasher.combine(high)
  }
}

extension UInt128 {
  public var components: (high: High, low: Low) {
    @inline(__always) get { (high, low) }
    @inline(__always) set { (self.high, self.low) = (newValue.high, newValue.low) }
  }
}

extension UInt128: AdditiveArithmetic {
  public static func - (_ lhs: Self, _ rhs: Self) -> Self {
    let (result, overflow) = lhs.subtractingReportingOverflow(rhs)
    precondition(!overflow, "Overflow in -")
    return result
  }

  public static func -= (_ lhs: inout Self, _ rhs: Self) {
    let (result, overflow) = lhs.subtractingReportingOverflow(rhs)
    precondition(!overflow, "Overflow in -=")
    lhs = result
  }

  public static func + (_ lhs: Self, _ rhs: Self) -> Self {
    let (result, overflow) = lhs.addingReportingOverflow(rhs)
    precondition(!overflow, "Overflow in +")
    return result
  }

  public static func += (_ lhs: inout Self, _ rhs: Self) {
    let (result, overflow) = lhs.addingReportingOverflow(rhs)
    precondition(!overflow, "Overflow in +=")
    lhs = result
  }
}

extension UInt128: Numeric {
  public typealias Magnitude = UInt128

  public var magnitude: Magnitude {
    return self
  }

  public init(_ magnitude: Magnitude) {
    self.init(high: High(magnitude.high), low: magnitude.low)
  }

  public init<T: BinaryInteger>(_ source: T) {
    guard let result = Self(exactly: source) else {
      preconditionFailure("Value is outside the representable range")
    }
    self = result
  }

  public init?<T: BinaryInteger>(exactly source: T) {
    // Can't represent a negative 'source' if Self is unsigned.
    guard Self.isSigned || source >= 0 else {
      return nil
    }

    // Is 'source' entirely representable in Low?
    if let low = Low(exactly: source.magnitude) {
      self.init(source._isNegative ? (~0, low._twosComplement) : (0, low))
    } else {
      // At this point we know source.bitWidth > High.bitWidth, or else we
      // would've taken the first branch.
      let lowInT = source & T(~0 as Low)
      let highInT = source >> Low.bitWidth

      let low = Low(lowInT)
      guard let high = High(exactly: highInT) else {
        return nil
      }
      self.init(high: high, low: low)
    }
  }

  public static func * (_ lhs: Self, _ rhs: Self) -> Self {
    let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    precondition(!overflow, "Overflow in *")
    return result
  }

  public static func *= (_ lhs: inout Self, _ rhs: Self) {
    let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
    precondition(!overflow, "Overflow in *=")
    lhs = result
  }
}

extension UInt128 {
  public struct Words {
    internal var _value: UInt128

    internal init(_ value: UInt128) {
      self._value = value
    }
  }
}

extension UInt128.Words: RandomAccessCollection {
  public typealias Element = UInt
  public typealias Index = Int
  public typealias Indices = Range<Int>
  public typealias SubSequence = Slice<Self>

  public var count: Int { 128 / UInt.bitWidth }
  public var startIndex: Int { 0 }
  public var endIndex: Int { count }
  public var indices: Indices { startIndex ..< endIndex }
  public func index(after i: Int) -> Int { i + 1 }
  public func index(before i: Int) -> Int { i - 1 }

  public subscript(position: Int) -> UInt {
    get {
      precondition(position >= 0 && position < endIndex,
        "Word index out of range")
      let shift = position &* UInt.bitWidth
      precondition(shift < UInt128.bitWidth)

      let r = _wideMaskedShiftRight(
        _value.components, UInt64(truncatingIfNeeded: shift))
      return r.low._lowWord
    }
  }
}

extension UInt128: FixedWidthInteger {
  public var _lowWord: UInt {
    low._lowWord
  }

  public var words: Words {
    Words(self)
  }

  public static var isSigned: Bool {
    false
  }

  public static var max: Self {
    self.init(high: High.max, low: Low.max)
  }

  public static var min: Self {
    self.init(high: High.min, low: Low.min)
  }

  public static var bitWidth: Int { 128 }

  public func addingReportingOverflow(
    _ rhs: Self
  ) -> (partialValue: Self, overflow: Bool) {
    let (r, o) = _wideAddReportingOverflow22(self.components, rhs.components)
    return (Self(r), o)
  }

  public func subtractingReportingOverflow(
    _ rhs: Self
  ) -> (partialValue: Self, overflow: Bool) {
    let (r, o) = _wideSubtractReportingOverflow22(
      self.components, rhs.components)
    return (Self(r), o)
  }

  public func multipliedReportingOverflow(
    by rhs: Self
  ) -> (partialValue: Self, overflow: Bool) {
    let h1 = self.high.multipliedReportingOverflow(by: rhs.low)
    let h2 = self.low.multipliedReportingOverflow(by: rhs.high)
    let h3 = h1.partialValue.addingReportingOverflow(h2.partialValue)
    let (h, l) = self.low.multipliedFullWidth(by: rhs.low)
    let high = h3.partialValue.addingReportingOverflow(h)
    let overflow = (
      (self.high != 0 && rhs.high != 0)
      || h1.overflow || h2.overflow || h3.overflow || high.overflow)
    return (Self(high: high.partialValue, low: l), overflow)
  }

  /// Returns the product of this value and the given 64-bit value, along with a
  /// Boolean value indicating whether overflow occurred in the operation.
  public func multipliedReportingOverflow(
    by other: UInt64
  ) -> (partialValue: Self, overflow: Bool) {
    let h1 = self.high.multipliedReportingOverflow(by: other)
    let (h2, l) = self.low.multipliedFullWidth(by: other)
    let high = h1.partialValue.addingReportingOverflow(h2)
    let overflow = h1.overflow || high.overflow
    return (Self(high: high.partialValue, low: l), overflow)
  }

  public func multiplied(by other: UInt64) -> Self {
    let r = multipliedReportingOverflow(by: other)
    precondition(!r.overflow, "Overflow in multiplication")
    return r.partialValue
  }

  public func quotientAndRemainder(
    dividingBy other: Self
  ) -> (quotient: Self, remainder: Self) {
    let (q, r) = _wideDivide22(
      self.magnitude.components, by: other.magnitude.components)
    let quotient = Self.Magnitude(q)
    let remainder = Self.Magnitude(r)
    return (quotient, remainder)
  }

  public func dividedReportingOverflow(
    by other: Self
  ) -> (partialValue: Self, overflow: Bool) {
    if other == Self.zero {
      return (self, true)
    }
    if Self.isSigned && other == -1 && self == .min {
      return (self, true)
    }
    return (quotientAndRemainder(dividingBy: other).quotient, false)
  }

  public func remainderReportingOverflow(
    dividingBy other: Self
  ) -> (partialValue: Self, overflow: Bool) {
    if other == Self.zero {
      return (self, true)
    }
    if Self.isSigned && other == -1 && self == .min {
      return (0, true)
    }
    return (quotientAndRemainder(dividingBy: other).remainder, false)
  }

  public func multipliedFullWidth(
    by other: Self
  ) -> (high: Self, low: Magnitude) {
    let isNegative = Self.isSigned && (self._isNegative != other._isNegative)

    func sum(_ x: Low, _ y: Low) -> (high: Low, low: Low) {
      let (sum, overflow) = x.addingReportingOverflow(y)
      return (overflow ? 1 : 0, sum)
    }

    func sum(_ x: Low, _ y: Low, _ z: Low) -> (high: Low, low: Low) {
      let s1 = sum(x, y)
      let s2 = sum(s1.low, z)
      return (s1.high &+ s2.high, s2.low)
    }

    func sum(
      _ x0: Low, _ x1: Low, _ x2: Low, _ x3: Low
    ) -> (high: Low, low: Low) {
      let s1 = sum(x0, x1)
      let s2 = sum(x2, x3)
      let s = sum(s1.low, s2.low)
      return (s1.high &+ s2.high &+ s.high, s.low)
    }

    let lhs = self.magnitude
    let rhs = other.magnitude

    let a = rhs.low.multipliedFullWidth(by: lhs.low)
    let b = rhs.low.multipliedFullWidth(by: lhs.high)
    let c = rhs.high.multipliedFullWidth(by: lhs.low)
    let d = rhs.high.multipliedFullWidth(by: lhs.high)

    let mid1 = sum(a.high, b.low, c.low)
    let mid2 = sum(b.high, c.high, mid1.high, d.low)

    let high = UInt128(
      high: High(d.high &+ mid2.high), // Note: this addition will never wrap
      low: mid2.low)
    let low = UInt128(
      high: mid1.low,
      low: a.low)

    if isNegative {
      let (lowComplement, overflow) = (~low).addingReportingOverflow(.one)
      return (~high + (overflow ? 1 : 0), lowComplement)
    } else {
      return (high, low)
    }
  }

  public func dividingFullWidth(
    _ dividend: (high: Self, low: Self.Magnitude)
  ) -> (quotient: Self, remainder: Self) {
    let (q, r) = _wideDivide42(
      (dividend.high.components, dividend.low.components),
      by: self.components)
    return (Self(q), Self(r))
  }

  #if false // This triggers an unexpected type checking issue with `~0` in an
            // lldb test
  public static prefix func ~(x: Self) -> Self {
    Self(high: ~x.high, low: ~x.low)
  }
  #endif

  public static func &= (_ lhs: inout Self, _ rhs: Self) {
    lhs.low &= rhs.low
    lhs.high &= rhs.high
  }

  public static func |= (_ lhs: inout Self, _ rhs: Self) {
    lhs.low |= rhs.low
    lhs.high |= rhs.high
  }

  public static func ^= (_ lhs: inout Self, _ rhs: Self) {
    lhs.low ^= rhs.low
    lhs.high ^= rhs.high
  }

  public static func <<= (_ lhs: inout Self, _ rhs: Self) {
    if Self.isSigned && rhs._isNegative {
      lhs >>= 0 - rhs
      return
    }

    // Shift is larger than this type's bit width.
    if rhs.high != High.zero || rhs.low >= Self.bitWidth {
      lhs = 0
      return
    }

    lhs &<<= rhs
  }

  public static func >>= (_ lhs: inout Self, _ rhs: Self) {
    if Self.isSigned && rhs._isNegative {
      lhs <<= 0 - rhs
      return
    }

    // Shift is larger than this type's bit width.
    if rhs.high != High.zero || rhs.low >= Self.bitWidth {
      lhs = lhs._isNegative ? ~0 : 0
      return
    }

    lhs &>>= rhs
  }

  public static func &<< (lhs: Self, rhs: Self) -> Self {
    Self(_wideMaskedShiftLeft(lhs.components, rhs.low))
  }

  public static func &>> (lhs: Self, rhs: Self) -> Self {
    Self(_wideMaskedShiftRight(lhs.components, rhs.low))
  }

  public static func &<<= (lhs: inout Self, rhs: Self) {
    _wideMaskedShiftLeft(&lhs.components, rhs.low)
  }

  public static func &>>= (lhs: inout Self, rhs: Self) {
    lhs = Self(_wideMaskedShiftRight(lhs.components, rhs.low))
  }

  public static func / (
    _ lhs: Self, _ rhs: Self
  ) -> Self {
    var lhs = lhs
    lhs /= rhs
    return lhs
  }

  public static func /= (_ lhs: inout Self, _ rhs: Self) {
    let (result, overflow) = lhs.dividedReportingOverflow(by: rhs)
    precondition(!overflow, "Overflow in /=")
    lhs = result
  }

  public static func % (
    _ lhs: Self, _ rhs: Self
  ) -> Self {
    var lhs = lhs
    lhs %= rhs
    return lhs
  }

  public static func %= (_ lhs: inout Self, _ rhs: Self) {
    let (result, overflow) = lhs.remainderReportingOverflow(dividingBy: rhs)
    precondition(!overflow, "Overflow in %=")
    lhs = result
  }

  public init(_truncatingBits bits: UInt) {
    low = Low(_truncatingBits: bits)
    high = High(_truncatingBits: bits >> UInt(Low.bitWidth))
  }

  public init(integerLiteral x: Int64) {
    self.init(x)
  }

  public var leadingZeroBitCount: Int {
    (high == High.zero
      ? High.bitWidth + low.leadingZeroBitCount
      : high.leadingZeroBitCount)
  }

  public var trailingZeroBitCount: Int {
    (low == Low.zero
      ? Low.bitWidth + high.trailingZeroBitCount
      : low.trailingZeroBitCount)
  }

  public var nonzeroBitCount: Int {
    high.nonzeroBitCount + low.nonzeroBitCount
  }

  public var byteSwapped: Self {
    Self(
      high: High(truncatingIfNeeded: low.byteSwapped),
      low: Low(truncatingIfNeeded: high.byteSwapped))
  }
}

extension UInt128: Sendable {}

// MARK: - BinaryFloatingPoint Interoperability
extension BinaryFloatingPoint {
    public init(_ value: UInt128) {
        precondition(value.high == 0,
                     "Value is too large to fit into a BinaryFloatingPoint.")
        self.init(value.low)
    }

    public init?(exactly value: UInt128) {
        if value.high > 0 {
            return nil
        }
        self = Self(value.low)
    }
}

extension UInt128: UnsignedInteger {}

