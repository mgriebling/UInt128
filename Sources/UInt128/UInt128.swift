//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
// Modified for public use in pre-Swift 6 installations as a precursor
// to using Swift 6. Modified by Michael Griebling

// MARK: Memory layout

/// A 128-bit unsigned integer value type.

@frozen
public struct UInt128: Sendable, Codable {
  //  On 32-bit platforms, we don't want to use Builtin.Int128 for layout
  //  because it would be 16B aligned, which is excessive for such targets
  //  (and generally incompatible with C's `_BitInt(128)`). Instead we lay
  //  out the type as two `UInt64` fields--note that we have to be careful
  //  about endianness in this case.
#if _endian(little)
  public var _low: UInt64
  public var _high: UInt64
#else
  public var _high: UInt64
  public var _low: UInt64
#endif
  
  /// Creates a new instance from the given tuple of high and low parts.
  ///
  /// - Parameter value: The tuple to use as the source of the new instance's
  ///   high and low parts.
  public init(_ value: (high: UInt64, low: UInt64)) {
    self._low = value.low
    self._high = value.high
  }
  
  @_transparent
  public init(_low: UInt64, _high: UInt64) {
    self._low = _low
    self._high = _high
  }

  public var _value: Int128 {
    @_transparent
    get {
      unsafeBitCast(self, to: Int128.self)
    }

    @_transparent
    set {
      self = Self(newValue)
    }
  }

  @_transparent
  public init(_ _value: Int128) {
    self = unsafeBitCast(_value, to: Self.self)
  }

  /// Creates a new instance with the same memory representation as the given
  /// value.
  ///
  /// This initializer does not perform any range or overflow checking. The
  /// resulting instance may not have the same numeric value as
  /// `bitPattern`---it is only guaranteed to use the same pattern of bits in
  /// its binary representation.
  ///
  /// - Parameter bitPattern: A value to use as the source of the new instance's
  ///   binary representation.
  
  @_transparent
  public init(bitPattern: Int128) {
    self.init(bitPattern._value)
  }
}

extension UInt128 {
  public var components: (high: UInt64, low: UInt64) {
    @inline(__always) get { (_high, _low) }
    @inline(__always) set { (self._high, self._low) = (newValue.high, newValue.low) }
  }
}

// MARK: - Constants

extension UInt128 {
  @_transparent
  public static var zero: Self {
    Self(_low: 0, _high: 0)
  }

  @_transparent
  public static var min: Self {
    zero
  }

  @_transparent
  public static var max: Self {
    Self(_low: .max, _high: .max)
  }
}

// MARK: - Conversions from other integers

extension UInt128: ExpressibleByIntegerLiteral {
  
  public typealias IntegerLiteralType = StaticBigInt
  
  public init(integerLiteral value: IntegerLiteralType) {
    precondition(UInt64.bitWidth == 64, "Expecting 64-bit UInt")
    precondition(value.signum() >= 0, "UInt128 literal cannot be negative")
    precondition(value.bitWidth <= Self.bitWidth+1,
                 "\(value.bitWidth)-bit literal too large for UInt128")
    self.init(_low: UInt64(value[0]), _high: UInt64(value[1]))
  }

  @inlinable
  public init?<T>(exactly source: T) where T: BinaryInteger {
    guard let high = UInt64(exactly: source >> 64) else { return nil }
    let low = UInt64(truncatingIfNeeded: source)
    self.init(_low: low, _high: high)
  }

  @inlinable
  public init<T>(_ source: T) where T: BinaryInteger {
    guard let value = Self(exactly: source) else {
      fatalError("value cannot be converted to UInt128 because it is outside the representable range")
    }
    self = value
  }

  @inlinable
  public init<T>(clamping source: T) where T: BinaryInteger {
    guard let value = Self(exactly: source) else {
      self = source < .zero ? .zero : .max
      return
    }
    self = value
  }

  @inlinable
  public init<T>(truncatingIfNeeded source: T) where T: BinaryInteger {
    let high = UInt64(truncatingIfNeeded: source >> 64)
    let low = UInt64(truncatingIfNeeded: source)
    self.init(_low: low, _high: high)
  }

  @_transparent
  public init(_truncatingBits source: UInt) {
    self.init(_low: UInt64(source), _high: .zero)
  }
}

// MARK: - Conversions from Binary floating-point

extension UInt128 {
  
  @inlinable
  public init?<T>(exactly source: T) where T: BinaryFloatingPoint {
    let highAsFloat = (source * 0x1.0p-64).rounded(.towardZero)
    guard let high = UInt64(exactly: highAsFloat) else { return nil }
    guard let low = UInt64(
      exactly: high == 0 ? source : source - 0x1.0p64*highAsFloat
    ) else { return nil }
    self.init(_low: low, _high: high)
  }

  @inlinable
  public init<T>(_ source: T) where T: BinaryFloatingPoint {
    guard let value = Self(exactly: source.rounded(.towardZero)) else {
      fatalError("value cannot be converted to UInt128 because it is outside the representable range")
    }
    self = value
  }
}

// MARK: - Non-arithmetic utility conformances
extension UInt128: Equatable {
  @_transparent
  public static func ==(a: Self, b: Self) -> Bool {
    (a._high, a._low) == (b._high, b._low)
  }
}

extension UInt128: Comparable {
  @_transparent
  public static func <(a: Self, b: Self) -> Bool {
    (a._high, a._low) < (b._high, b._low)
  }
}


extension UInt128: Hashable {
  @inlinable
  public func hash(into hasher: inout Hasher) {
    hasher.combine(_low)
    hasher.combine(_high)
  }
}

extension UInt128 {
  
  public func dividingFullWidth(
    _ dividend: (high: Self, low: Self.Magnitude)
  ) -> (quotient: Self, remainder: Self) {
    let (q, r) = _wideDivide42(
      (dividend.high.components, dividend.low.components),
      by: self.components)
    return (Self(q), Self(r))
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
  
  /// Maximum power of the `radix` for an unsigned 64-bit UInt for base
  /// indices of 2...36
  static let _maxPowers : [Int] = [
    63, 40, 31, 27, 24, 22, 21, 20, 19, 18, 17, 17, 16, 16, 15, 15, 15, 15,
    14, 14, 14, 14, 13, 13, 13, 13, 13, 13, 13, 13, 13, 12, 12, 12, 12, 12, 12
  ]
  
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
    r = x.quotientAndRemainder(dividingBy: UInt128((high: 0, low: maxDivisor)))
    return (r.quotient, r.remainder._low, digits)
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

// MARK: - Overflow-reporting arithmetic

extension UInt128 {
  public func addingReportingOverflow(_ other: Self) -> (partialValue: Self, overflow: Bool) {
    let (r, o) = _wideAddReportingOverflow22(self.components, other.components)
    return (Self(r), o)
  }

  public func subtractingReportingOverflow(_ other: Self) -> (partialValue: Self, overflow: Bool) {
    let (r, o) = _wideSubtractReportingOverflow22(self.components, other.components)
    return (Self(r), o)
  }

  @_transparent
  public func multipliedReportingOverflow(by other: Self) -> (partialValue: Self, overflow: Bool) {
    let h1 = self._high.multipliedReportingOverflow(by: other._low)
    let h2 = self._low.multipliedReportingOverflow(by: other._high)
    let h3 = h1.partialValue.addingReportingOverflow(h2.partialValue)
    let (h, l) = self._low.multipliedFullWidth(by: other._low)
    let high = h3.partialValue.addingReportingOverflow(h)
    let overflow = (
      (self._high != 0 && other._high != 0)
      || h1.overflow || h2.overflow || h3.overflow || high.overflow)
    return (Self(_low: l, _high: high.partialValue), overflow)
  }

  @_transparent
  public func dividedReportingOverflow(by other: Self) -> (partialValue: Self, overflow: Bool) {
    if other == Self.zero {
      return (self, true)
    }
    if Self.isSigned && other == -1 && self == .min {
      return (self, true)
    }
    // Unsigned divide never overflows.
    return (quotientAndRemainder(dividingBy: other).quotient, false)
  }

  @_transparent
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
}

// MARK: - AdditiveArithmetic conformance

extension UInt128: AdditiveArithmetic {
  @_transparent
  public static func +(a: Self, b: Self) -> Self {
    let (result, overflow) = a.addingReportingOverflow(b)
    assert(!overflow, "arithmetic overflow")
    return result
  }

  @_transparent
  public static func -(a: Self, b: Self) -> Self {
    let (result, overflow) = a.subtractingReportingOverflow(b)
    assert(!overflow, "arithmetic overflow")
    return result
  }
}

// MARK: - Multiplication and division

extension UInt128 {
  @_transparent
  public static func *(a: Self, b: Self) -> Self {
    let (result, overflow) = a.multipliedReportingOverflow(by: b)
    assert(!overflow, "arithmetic overflow")
    return result
  }

  @_transparent
  public static func *=(a: inout Self, b: Self) {
    a = a * b
  }

  @_transparent
  public static func /(a: Self, b: Self) -> Self {
    a.dividedReportingOverflow(by: b).partialValue
  }

  @_transparent
  public static func /=(a: inout Self, b: Self) {
    a = a / b
  }

  @_transparent
  public static func %(a: Self, b: Self) -> Self {
    a.remainderReportingOverflow(dividingBy: b).partialValue
  }

  @_transparent
  public static func %=(a: inout Self, b: Self) {
    a = a % b
  }
}

// MARK: - Numeric conformance
extension UInt128: Numeric {
  public typealias Magnitude = Self

  @_transparent
  public var magnitude: Self {
    self
  }
}

// MARK: - BinaryInteger conformance

extension UInt128: BinaryInteger {
  
  @frozen
  public struct Words {
    @usableFromInline
    let _value: UInt128

    @_transparent
    public init(_value: UInt128) {
      self._value = _value
    }
  }
  
  @_transparent
  public var words: Words {
    Words(_value: self)
  }

  @_transparent
  public static func &=(a: inout Self, b: Self) {
    a._low &= b._low
    a._high &= b._high
  }

  @_transparent
  public static func |=(a: inout Self, b: Self) {
    a._low |= b._low
    a._high |= b._high
  }

  @_transparent
  public static func ^=(a: inout Self, b: Self) {
    a._low ^= b._low
    a._high ^= b._high
  }

  public static func &>>=(a: inout Self, b: Self) {
    a = Self(_wideMaskedShiftRight(a.components, b._low))
  }

  public static func &<<=(a: inout Self, b: Self) {
    _wideMaskedShiftLeft(&a.components, b._low)
  }

  @_transparent
  public var trailingZeroBitCount: Int {
    _low == 0 ? 64 + _high.trailingZeroBitCount : _low.trailingZeroBitCount
  }

  @_transparent
  public var _lowWord: UInt {
    UInt(_low)
  }
}

extension UInt128.Words: RandomAccessCollection {
  
  public typealias Element = UInt
  public typealias Index = Int
  public typealias SubSequence = Slice<Self>
  public typealias Indices = Range<Int>

  @_transparent
  public var count: Int {
    128 / UInt.bitWidth
  }

  @_transparent
  public var startIndex: Int {
    0
  }

  @_transparent
  public var endIndex: Int {
    count
  }

  @_transparent
  public var indices: Indices {
    startIndex ..< endIndex
  }

  @_transparent
  public func index(after i: Int) -> Int {
    i + 1
  }

  @_transparent
  public func index(before i: Int) -> Int {
    i - 1
  }

  public subscript(position: Int) -> UInt {
    @inlinable
    get {
      precondition(position >= 0 && position < count, "Index out of bounds")
      var value = _value
#if _endian(little)
      let index = position
#else
      let index = count - 1 - position
#endif
      return _withUnprotectedUnsafePointer(to: &value) {
        $0.withMemoryRebound(to: UInt.self, capacity: count) { $0[index] }
      }
    }
  }
}

// MARK: - FixedWidthInteger conformance
extension UInt128: FixedWidthInteger, UnsignedInteger {
  @_transparent
  public static var bitWidth: Int { 128 }

  @_transparent
  public var nonzeroBitCount: Int {
    _high.nonzeroBitCount &+ _low.nonzeroBitCount
  }

  @_transparent
  public var leadingZeroBitCount: Int {
    _high == 0 ? 64 + _low.leadingZeroBitCount : _high.leadingZeroBitCount
  }

  @_transparent
  public var byteSwapped: Self {
    return Self(_low: _high.byteSwapped, _high: _low.byteSwapped)
  }
}

// MARK: - Integer comparison type inference

extension UInt128 {
  // IMPORTANT: The following four apparently unnecessary overloads of
  // comparison operations are necessary for literal comparands to be
  // inferred as the desired type.
  @_transparent @_alwaysEmitIntoClient
  public static func != (lhs: Self, rhs: Self) -> Bool {
    return !(lhs == rhs)
  }

  @_transparent @_alwaysEmitIntoClient
  public static func <= (lhs: Self, rhs: Self) -> Bool {
    return !(rhs < lhs)
  }

  @_transparent @_alwaysEmitIntoClient
  public static func >= (lhs: Self, rhs: Self) -> Bool {
    return !(lhs < rhs)
  }

  @_transparent @_alwaysEmitIntoClient
  public static func > (lhs: Self, rhs: Self) -> Bool {
    return rhs < lhs
  }
}

// MARK: - BinaryFloatingPoint Interoperability
extension BinaryFloatingPoint {
    public init(_ value: UInt128) {
        precondition(value._high == 0,
                     "Value is too large to fit into a BinaryFloatingPoint.")
        self.init(value._low)
    }

    public init?(exactly value: UInt128) {
        if value._high > 0 {
            return nil
        }
        self = Self(value._low)
    }
}
