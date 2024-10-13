
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

/// A 128-bit signed integer value type.
@frozen
public struct Int128: Sendable, Codable {
#if _endian(little)
  public var _low: UInt64
  public var _high: Int64
#else
  public var _high: Int64
  public var _low: UInt64
#endif

  @_transparent
  public init(_low: UInt64, _high: Int64) {
    self._low = _low
    self._high = _high
  }
  
  public init(_ value: (high: Int64, low: UInt64)) {
    self._low = value.low
    self._high = value.high
  }

  public var _value: Int128 {
    @_transparent
    get {
      self
    }

    @_transparent
    set {
      self = Self(newValue)
    }
  }

  @_transparent
  public init(_ _value: Int128) {
    self = _value
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
  public init(bitPattern: UInt128) {
    self.init(bitPattern._value)
  }
}

extension Int128 {
  public var components: (high: Int64, low: UInt64) {
    @inline(__always) get { (_high, _low) }
    @inline(__always) set { (self._high, self._low) = (newValue.high, newValue.low) }
  }
}


// MARK: - Constants

extension Int128 {
  
  @_transparent
  public static var zero: Self {
    Self(_low: 0, _high: 0)
  }

  
  @_transparent
  public static var min: Self {
    Self(_low: .zero, _high: .min)
  }

  
  @_transparent
  public static var max: Self {
    Self(_low: .max, _high: .max)
  }
}

// MARK: - Conversions from other integers

extension Int128: ExpressibleByIntegerLiteral {
  
  public typealias IntegerLiteralType = StaticBigInt
  
  public init(integerLiteral value: IntegerLiteralType) {
    precondition(UInt64.bitWidth == 64, "Expecting 64-bit UInt")
    precondition(value.bitWidth <= Self.bitWidth,
                 "\(value.bitWidth)-bit literal too large for Int128")
    self.init(_low: UInt64(value[0]), _high: Int64(bitPattern:UInt64(value[1])))
  }

  @inlinable
  public init?<T>(exactly source: T) where T: BinaryInteger {
    guard let high = Int64(exactly: source >> 64) else { return nil }
    let low = UInt64(truncatingIfNeeded: source)
    self.init(_low: low, _high: high)
  }

  @inlinable
  public init<T>(_ source: T) where T: BinaryInteger {
    guard let value = Self(exactly: source) else {
      fatalError("value cannot be converted to Int128 because it is outside the representable range")
    }
    self = value
  }

  @inlinable
  public init<T>(clamping source: T) where T: BinaryInteger {
    guard let value = Self(exactly: source) else {
      self = source < .zero ? .min : .max
      return
    }
    self = value
  }

  @inlinable
  public init<T>(truncatingIfNeeded source: T) where T: BinaryInteger {
    let high = Int64(truncatingIfNeeded: source >> 64)
    let low = UInt64(truncatingIfNeeded: source)
    self.init(_low: low, _high: high)
  }

  @_transparent
  public init(_truncatingBits source: UInt) {
    self.init(_low: UInt64(source), _high: .zero)
  }
}

// MARK: - Conversions from Binary floating-point

extension Int128 {
  
  @inlinable
  public init?<T>(exactly source: T) where T: BinaryFloatingPoint {
    if source.magnitude < 0x1.0p64 {
      guard let magnitude = UInt64(exactly: source.magnitude) else {
        return nil
      }
      self = Int128(_low: magnitude, _high: 0)
      if source < 0 { self = -self }
    } else {
      let highAsFloat = (source * 0x1.0p-64).rounded(.down)
      guard let high = Int64(exactly: highAsFloat) else { return nil }
      // Because we already ruled out |source| < 0x1.0p64, we know that
      // high contains at least one value bit, and so Sterbenz' lemma
      // allows us to compute an exact residual:
      guard let low = UInt64(exactly: source - 0x1.0p64*highAsFloat) else {
        return nil
      }
      self.init(_low: low, _high: high)
    }
  }

  @inlinable
  public init<T>(_ source: T) where T: BinaryFloatingPoint {
    guard let value = Self(exactly: source.rounded(.towardZero)) else {
      fatalError("value cannot be converted to Int128 because it is outside the representable range")
    }
    self = value
  }
}

// MARK: - Non-arithmetic utility conformances

extension Int128: Equatable {
  @_transparent
  public static func ==(a: Self, b: Self) -> Bool {
    (a._high, a._low) == (b._high, b._low)
  }
}

extension Int128: Comparable {
  @_transparent
  public static func <(a: Self, b: Self) -> Bool {
    (a._high, a._low) < (b._high, b._low)
  }
}

extension Int128: Hashable {
  @inlinable
  public func hash(into hasher: inout Hasher) {
    hasher.combine(_low)
    hasher.combine(_high)
  }
}

extension Int128 {
  /// Converts the Int128 `self` into a string with a given `radix`.  The
  /// radix string can use uppercase characters if `uppercase` is true.
  ///
  /// Why convert numbers in chunks?  This approach reduces the number of
  /// calls to division and modulo functions so is more efficient than a naïve
  /// digit-based approach.  Ideally this code should be in the String module.
  /// Further optimizations may be possible by using unchecked string buffers.
  internal func _description(radix:Int=10, uppercase:Bool=false) -> String {
    let str = self.magnitude._description(radix:radix, uppercase: uppercase)
    if self < 0 {
      return "-" + str
    }
    return str
  }
}

extension Int128 : CustomStringConvertible {
  public var description: String {
    _description(radix: 10)
  }
}

extension Int128: CustomDebugStringConvertible {
  public var debugDescription: String {
    description
  }
}

// MARK: - Overflow-reporting arithmetic

extension Int128 {
  
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
    let a = self.magnitude
    let b = other.magnitude
    let (magnitude, overflow) = a.multipliedReportingOverflow(by: b)
    if (self < 0) != (other < 0) {
      let partialValue = Self(bitPattern: 0 &- magnitude)
      return (partialValue, overflow || partialValue > 0)
    } else {
      let partialValue = Self(bitPattern: magnitude)
      return (partialValue, overflow || partialValue < 0)
    }
  }
  
  public func dividingFullWidth(
    _ dividend: (high: Self, low: Self.Magnitude)
  ) -> (quotient: Self, remainder: Self) {
    let m = _wideMagnitude22(dividend)
    let (quotient, remainder) = self.magnitude.dividingFullWidth(m)

    let isNegative = (self._high < 0) != (dividend.high._high < 0)
    let quotient_ = (isNegative
      ? (quotient == Self.min.magnitude ? Self.min : 0 - Self(quotient))
      : Self(quotient))
    let remainder_ = (dividend.high._high < 0
      ? 0 - Self(remainder)
      : Self(remainder))
    return (quotient_, remainder_)
  }
  
  // Need to use this because the runtime routine doesn't exist
  public func quotientAndRemainder(
    dividingBy other: Self
  ) -> (quotient: Self, remainder: Self) {
    let (q, r) = _wideDivide22(
      self.magnitude.components, by: other.magnitude.components)
    let quotient = Self.Magnitude(q)
    let remainder = Self.Magnitude(r)
    let isNegative = (self._high < 0) != (other._high < 0)
    let quotient_ = (isNegative
      ? quotient == Self.min.magnitude ? Self.min : 0 - Self(quotient)
      : Self(quotient))
    let remainder_ = (self._high < 0)
      ? 0 - Self(remainder)
      : Self(remainder)
    return (quotient_, remainder_)
  }

  @_transparent
  public func dividedReportingOverflow(by other: Self) -> (partialValue: Self, overflow: Bool) {
    if other == Self.zero {
      return (self, true)
    }
    if Self.isSigned && other == -1 && self == .min {
      return (self, true)
    }
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

extension Int128: AdditiveArithmetic {
  
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

extension Int128 {
  
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

extension Int128: SignedNumeric {
  
  public typealias Magnitude = UInt128

  @_transparent
  public var magnitude: Magnitude {
    let unsignedSelf = UInt128(_value)
    return self < 0 ? 0 &- unsignedSelf : unsignedSelf
  }
}

// MARK: - BinaryInteger conformance

extension Int128: BinaryInteger {
  
  public var words: UInt128.Words {
    Words(_value: UInt128(_value))
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
    _wideMaskedShiftRight(&a.components, b._low)
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

// MARK: - FixedWidthInteger conformance

extension Int128: FixedWidthInteger, SignedInteger {
  
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
    return Self(_low: UInt64(bitPattern: _high.byteSwapped),
                _high: Int64(bitPattern: _low.byteSwapped))
  }

//  @_transparent
//  public static func &*(lhs: Self, rhs: Self) -> Self {
//    // The default &* on FixedWidthInteger calls multipliedReportingOverflow,
//    // which we want to avoid here, since the overflow check is expensive
//    // enough that we wouldn't want to inline it into most callers.
//    // Self(Builtin.mul_Int128(lhs._value, rhs._value))
//    let (high: h, low: l) = lhs.multipliedFullWidth(by: rhs)
//    return Self(_low:l, _high: h)
//  }
}

// MARK: - Integer comparison type inference

extension Int128 {
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
    public init(_ value: Int128) {
        precondition(value._high == 0,
                     "Value is too large to fit into a BinaryFloatingPoint.")
        self.init(value._low)
    }

    public init?(exactly value: Int128) {
        if value._high > 0 {
            return nil
        }
        self = Self(value._low)
    }
}

