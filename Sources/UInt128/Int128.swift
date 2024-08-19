//
//  Int128.swift
//
//
//  Created by Mike Griebling on 19.08.2024.
//

/// A 128-bit signed integer type.
public struct Int128 : Codable {
  public typealias High = Int64
  public typealias Low = UInt64

  /// The low part of the value.
  internal var low: Low
  public var _low: Low { low }

  /// The high part of the value.
  internal var high: High
  public var _high: High { high }

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

  public init(bitPattern v: UInt128) {
    self.init(high: High(bitPattern: v.high), low: v.low)
  }

  public static var zero: Self { Self(high: 0, low: 0) }
  public static var one: Self { Self(high: 0, low: 1) }
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
    if self._isNegative {
      return "-" + str
    }
    return str
  }
}

extension String {
  public init(_ n: Int128, radix: Int = 10, uppercase: Bool = false) {
    self = n._description(radix: radix, uppercase: uppercase)
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


extension Int128 : ExpressibleByIntegerLiteral {
  public typealias IntegerLiteralType = StaticBigInt
  
  public init(integerLiteral value: StaticBigInt) {
    precondition(Low.bitWidth == 64, "Expecting 64-bit UInt")
    precondition(value.bitWidth <= Self.bitWidth,
                 "\(value.bitWidth)-bit literal too large for Int128")
    self.init(high: High(bitPattern:UInt64(value[1])), low: Low(value[0]))
  }
}

extension Int128 {
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

extension Int128 {
  /// This method breaks `string` into pieces to reduce overhead of the
  /// multiplications and allow UInt64 to work in converting larger numbers.
  static func value<S: StringProtocol>(
    from string: S, radix: Int = 10) -> Self? {
    // Handles signs and leading zeros
    var s = String(string)
    var isNegative = false
    if s.hasPrefix("-") { isNegative = true; s.removeFirst() }
      
    // Translate the string into a number
    guard let r = UInt128.value(from: s, radix: radix) else { return nil }
    if isNegative {
      return -Self(r)
    }
    return Self(r)
  }
          
}

extension Int128: Equatable {
  public static func == (_ lhs: Self, _ rhs: Self) -> Bool {
    return (lhs.high, lhs.low) == (rhs.high, rhs.low)
  }
}

extension Int128: Comparable {
  public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
    (lhs.high, lhs.low) < (rhs.high, rhs.low)
  }
}

extension Int128: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(low)
    hasher.combine(high)
  }
}

extension Int128 {
  public var components: (high: High, low: Low) {
    @inline(__always) get { (high, low) }
    @inline(__always) set { (self.high, self.low) = (newValue.high, newValue.low) }
  }
}

extension Int128: AdditiveArithmetic {
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

extension Int128: Numeric {
  public typealias Magnitude = UInt128

  public var magnitude: Magnitude {
    var result = UInt128(bitPattern: self)
    guard high._isNegative else { return result }
    result.high = ~result.high
    result.low = ~result.low
    return result.addingReportingOverflow(.one).partialValue
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

extension Int128 {
  public struct Words {
    internal var _value: Int128

    internal init(_ value: Int128) {
      self._value = value
    }
  }
}

extension Int128.Words: RandomAccessCollection {
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
      precondition(shift < Int128.bitWidth)

      let r = _wideMaskedShiftRight(
        _value.components, UInt64(truncatingIfNeeded: shift))
      return r.low._lowWord
    }
  }
}

extension Int128: FixedWidthInteger {
  public var _lowWord: UInt {
    low._lowWord
  }

  public var words: Words {
    Words(self)
  }

  public static var isSigned: Bool {
    true
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
    let isNegative = (self._isNegative != rhs._isNegative)
    let (p, overflow) = self.magnitude.multipliedReportingOverflow(
      by: rhs.magnitude)
    let r = Int128(bitPattern: isNegative ? p._twosComplement : p)
    return (r, overflow || (isNegative != r._isNegative))
  }

  /// Returns the product of this value and the given 64-bit value, along with a
  /// Boolean value indicating whether overflow occurred in the operation.
  public func multipliedReportingOverflow(
    by other: UInt64
  ) -> (partialValue: Self, overflow: Bool) {
    let isNegative = self._isNegative
    let (p, overflow) = self.magnitude.multipliedReportingOverflow(by: other)
    let r = Int128(bitPattern: isNegative ? p._twosComplement : p)
    return (r, overflow || (isNegative != r._isNegative))
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
    let isNegative = (self.high._isNegative != other.high._isNegative)
    let quotient_ = (isNegative
      ? quotient == Self.min.magnitude ? Self.min : 0 - Self(quotient)
      : Self(quotient))
    let remainder_ = (self.high._isNegative
      ? 0 - Self(remainder)
      : Self(remainder))
    return (quotient_, remainder_)
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

    let high = Int128(
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
    let m = _wideMagnitude22(dividend)
    let (quotient, remainder) = self.magnitude.dividingFullWidth(m)

    let isNegative = (self.high._isNegative != dividend.high.high._isNegative)
    let quotient_ = (isNegative
      ? (quotient == Self.min.magnitude ? Self.min : 0 - Self(quotient))
      : Self(quotient))
    let remainder_ = (dividend.high.high._isNegative
      ? 0 - Self(remainder)
      : Self(remainder))
    return (quotient_, remainder_)
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
    _wideMaskedShiftRight(&lhs.components, rhs.low)
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

extension Int128: Sendable {}

// MARK: - BinaryFloatingPoint Interoperability
extension BinaryFloatingPoint {
    public init(_ value: Int128) {
        precondition(value.high == 0,
                     "Value is too large to fit into a BinaryFloatingPoint.")
        self.init(value.low)
    }

    public init?(exactly value: Int128) {
        if value.high > 0 {
            return nil
        }
        self = Self(value.low)
    }
}

extension BinaryInteger {
  @inline(__always)
  var _isNegative: Bool { self < Self.zero }
}

extension FixedWidthInteger {
  @inline(__always)
  var _twosComplement: Self {
    ~self &+ 1
  }
}


extension Int128 {
  internal func dividedBy1e18() -> (quotient: Self, remainder: Self) {
    let m = Int128(high: 664613997892457936, low: 8336148766501648893)
    var q = self.multipliedFullWidth(by: m).high
    q &>>= 55
    // Add 1 to q if self is negative
    q &+= Int128(bitPattern: UInt128(bitPattern: self) &>> 127)
    let r = self &- q &* (1000000000000000000 as Int128)
    return (q, r)
  }
}
extension Int128 {
  internal func dividedBy1e15() -> (quotient: Self, remainder: Self) {
    let m = Int128(high: -8062150356639896359, low: 1125115960621402641)
    var q = self.multipliedFullWidth(by: m).high
    q &+= self
    q &>>= 49
    // Add 1 to q if self is negative
    q &+= Int128(bitPattern: UInt128(bitPattern: self) &>> 127)
    let r = self &- q &* (1000000000000000 as Int128)
    return (q, r)
  }
}
extension Int128 {
  internal func dividedBy1e12() -> (quotient: Self, remainder: Self) {
    let m = Int128(high: 2535301200456458802, low: 18325113820324532597)
    var q = self.multipliedFullWidth(by: m).high
    q &>>= 37
    // Add 1 to q if self is negative
    q &+= Int128(bitPattern: UInt128(bitPattern: self) &>> 127)
    let r = self &- q &* (1000000000000 as Int128)
    return (q, r)
  }
}
extension Int128 {
  internal func dividedBy1e9() -> (quotient: Self, remainder: Self) {
    let m = Int128(high: 4951760157141521099, low: 11003425581274142745)
    var q = self.multipliedFullWidth(by: m).high
    q &>>= 28
    // Add 1 to q if self is negative
    q &+= Int128(bitPattern: UInt128(bitPattern: self) &>> 127)
    let r = self &- q &* (1000000000 as Int128)
    return (q, r)
  }
}
extension Int128 {
  internal func dividedBy1e6() -> (quotient: Self, remainder: Self) {
    let m = Int128(high: 604462909807314587, low: 6513323971497958161)
    var q = self.multipliedFullWidth(by: m).high
    q &>>= 15
    // Add 1 to q if self is negative
    q &+= Int128(bitPattern: UInt128(bitPattern: self) &>> 127)
    let r = self &- q &* (1000000 as Int128)
    return (q, r)
  }
}
extension Int128 {
  internal func dividedBy1e3() -> (quotient: Self, remainder: Self) {
    let m = Int128(high: 4722366482869645213, low: 12838933875301847925)
    var q = self.multipliedFullWidth(by: m).high
    q &>>= 8
    // Add 1 to q if self is negative
    q &+= Int128(bitPattern: UInt128(bitPattern: self) &>> 127)
    let r = self &- q &* (1000 as Int128)
    return (q, r)
  }
}

typealias _Wide2<F: FixedWidthInteger> =
  (high: F, low: F.Magnitude)

typealias _Wide3<F: FixedWidthInteger> =
  (high: F, mid: F.Magnitude, low: F.Magnitude)

typealias _Wide4<F: FixedWidthInteger> =
  (high: _Wide2<F>, low: (high: F.Magnitude, low: F.Magnitude))

private func _wideMagnitude22<F: FixedWidthInteger>(
  _ v: _Wide2<F>
) -> _Wide2<F.Magnitude> {
  var result = (high: F.Magnitude(truncatingIfNeeded: v.high), low: v.low)
  guard F.isSigned && v.high._isNegative else { return result }
  result.high = ~result.high
  result.low = ~result.low
  return _wideAddReportingOverflow22(result, (high: 0, low: 1)).partialValue
}

func _wideAddReportingOverflow22<F: FixedWidthInteger>(
  _ lhs: _Wide2<F>, _ rhs: _Wide2<F>
) -> (partialValue: _Wide2<F>, overflow: Bool) {
  let (low, lowOverflow) = lhs.low.addingReportingOverflow(rhs.low)
  let (high, highOverflow) = lhs.high.addingReportingOverflow(rhs.high)
  let overflow = highOverflow || high == F.max && lowOverflow
  let result = (high: high &+ (lowOverflow ? 1 : 0), low: low)
  return (partialValue: result, overflow: overflow)
}

private func _wideAdd22<F: FixedWidthInteger>(
  _ lhs: inout _Wide2<F>, _ rhs: _Wide2<F>
) {
  let (result, overflow) = _wideAddReportingOverflow22(lhs, rhs)
  precondition(!overflow, "Overflow in +")
  lhs = result
}

func _wideAddReportingOverflow33<F: FixedWidthInteger>(
  _ lhs: _Wide3<F>, _ rhs: _Wide3<F>
) -> (
  partialValue: _Wide3<F>,
  overflow: Bool
) {
  let (low, lowOverflow) =
    _wideAddReportingOverflow22((lhs.mid, lhs.low), (rhs.mid, rhs.low))
  let (high, highOverflow) = lhs.high.addingReportingOverflow(rhs.high)
  let result = (high: high &+ (lowOverflow ? 1 : 0), mid: low.high, low: low.low)
  let overflow = highOverflow || (high == F.max && lowOverflow)
  return (partialValue: result, overflow: overflow)
}

func _wideSubtractReportingOverflow22<F: FixedWidthInteger>(
  _ lhs: _Wide2<F>, _ rhs: _Wide2<F>
) -> (partialValue: (high: F, low: F.Magnitude), overflow: Bool) {
  let (low, lowOverflow) = lhs.low.subtractingReportingOverflow(rhs.low)
  let (high, highOverflow) = lhs.high.subtractingReportingOverflow(rhs.high)
  let result = (high: high &- (lowOverflow ? 1 : 0), low: low)
  let overflow = highOverflow || high == F.min && lowOverflow
  return (partialValue: result, overflow: overflow)
}

private func _wideSubtract22<F: FixedWidthInteger>(
  _ lhs: inout _Wide2<F>, _ rhs: _Wide2<F>
) {
  let (result, overflow) = _wideSubtractReportingOverflow22(lhs, rhs)
  precondition(!overflow, "Overflow in -")
  lhs = result
}

private func _wideSubtractReportingOverflow33<F: FixedWidthInteger>(
  _ lhs: _Wide3<F>, _ rhs: _Wide3<F>
) -> (
  partialValue: _Wide3<F>,
  overflow: Bool
) {
  let (low, lowOverflow) =
    _wideSubtractReportingOverflow22((lhs.mid, lhs.low), (rhs.mid, rhs.low))
  let (high, highOverflow) = lhs.high.subtractingReportingOverflow(rhs.high)
  let result = (high: high &- (lowOverflow ? 1 : 0), mid: low.high, low: low.low)
  let overflow = highOverflow || (high == F.min && lowOverflow)
  return (partialValue: result, overflow: overflow)
}

func _wideMaskedShiftLeft<F: FixedWidthInteger>(
  _ lhs: _Wide2<F>, _ rhs: F.Magnitude
) -> _Wide2<F> {
  let bitWidth = F.bitWidth + F.Magnitude.bitWidth
  precondition(bitWidth.nonzeroBitCount == 1)

  // Mask rhs by the bit width of the wide value.
  let rhs = rhs & F.Magnitude(bitWidth &- 1)

  guard rhs < F.Magnitude.bitWidth else {
    let s = rhs &- F.Magnitude(F.Magnitude.bitWidth)
    return (high: F(truncatingIfNeeded: lhs.low &<< s), low: 0)
  }

  guard rhs != F.Magnitude.zero else { return lhs }
  var high = lhs.high &<< F(rhs)
  let rollover = F.Magnitude(F.bitWidth) &- rhs
  high |= F(truncatingIfNeeded: lhs.low &>> rollover)
  let low = lhs.low &<< rhs
  return (high, low)
}

func _wideMaskedShiftLeft<F: FixedWidthInteger>(
  _ lhs: inout _Wide2<F>, _ rhs: F.Magnitude
) {
  lhs = _wideMaskedShiftLeft(lhs, rhs)
}

func _wideMaskedShiftRight<F: FixedWidthInteger>(
  _ lhs: _Wide2<F>, _ rhs: F.Magnitude
) -> _Wide2<F> {
  let bitWidth = F.bitWidth + F.Magnitude.bitWidth
  precondition(bitWidth.nonzeroBitCount == 1)

  // Mask rhs by the bit width of the wide value.
  let rhs = rhs & F.Magnitude(bitWidth &- 1)

  guard rhs < F.bitWidth else {
    let s = F(rhs &- F.Magnitude(F.bitWidth))
    return (
      high: lhs.high._isNegative ? ~0 : 0,
      low: F.Magnitude(truncatingIfNeeded: lhs.high &>> s))
  }

  guard rhs != F.zero else { return lhs }
  var low = lhs.low &>> rhs
  let rollover = F(F.bitWidth) &- F(rhs)
  low |= F.Magnitude(truncatingIfNeeded: lhs.high &<< rollover)
  let high = lhs.high &>> rhs
  return (high, low)
}

private func _wideMaskedShiftRight<F: FixedWidthInteger>(
  _ lhs: inout _Wide2<F>, _ rhs: F.Magnitude
) {
  lhs = _wideMaskedShiftRight(lhs, rhs)
}

/// Returns the quotient and remainder after dividing a triple-width magnitude
/// `lhs` by a double-width magnitude `rhs`.
///
/// This operation is conceptually that described by Burnikel and Ziegler
/// (1998).
private func _wideDivide32<F: FixedWidthInteger & UnsignedInteger>(
  _ lhs: _Wide3<F>, by rhs: _Wide2<F>
) -> (quotient: F, remainder: _Wide2<F>) {
  // The following invariants are guaranteed to hold by dividingFullWidth or
  // quotientAndRemainder before this function is invoked:
  precondition(lhs.high != F.zero)
  precondition(rhs.high.leadingZeroBitCount == 0)
  precondition((high: lhs.high, low: lhs.mid) < rhs)

  // Estimate the quotient with a 2/1 division using just the top digits.
  var quotient = (lhs.high == rhs.high
    ? F.max
    : rhs.high.dividingFullWidth((high: lhs.high, low: lhs.mid)).quotient)

  // Compute quotient * rhs.
  // TODO: This could be performed more efficiently.
  let p1 = quotient.multipliedFullWidth(by: F(rhs.low))
  let p2 = quotient.multipliedFullWidth(by: rhs.high)
  let product = _wideAddReportingOverflow33(
    (high: F.zero, mid: F.Magnitude(p1.high), low: p1.low),
    (high: p2.high, mid: p2.low, low: .zero)).partialValue

  // Compute the remainder after decrementing quotient as necessary.
  var remainder = lhs

  while remainder < product {
    quotient = quotient &- 1
    remainder = _wideAddReportingOverflow33(
      remainder,
      (high: F.zero, mid: F.Magnitude(rhs.high), low: rhs.low)).partialValue
  }
  remainder = _wideSubtractReportingOverflow33(remainder, product).partialValue
  precondition(remainder.high == 0)
  return (quotient, (high: F(remainder.mid), low: remainder.low))
}

/// Returns the quotient and remainder after dividing a double-width
/// magnitude `lhs` by a double-width magnitude `rhs`.
func _wideDivide22<F: FixedWidthInteger & UnsignedInteger>(
  _ lhs: _Wide2<F>, by rhs: _Wide2<F>
) -> (quotient: _Wide2<F>, remainder: _Wide2<F>) {
  guard _fastPath(rhs > (F.zero, F.Magnitude.zero)) else {
    fatalError("Division by zero")
  }
  guard rhs < lhs else {
    if _fastPath(rhs > lhs) { return (quotient: (0, 0), remainder: lhs) }
    return (quotient: (0, 1), remainder: (0, 0))
  }

  if lhs.high == F.zero {
    let (quotient, remainder) =
      lhs.low.quotientAndRemainder(dividingBy: rhs.low)
    return ((0, quotient), (0, remainder))
  }

  if rhs.high == F.zero {
    let (x, a) = lhs.high.quotientAndRemainder(dividingBy: F(rhs.low))
    let (y, b) = (a == F.zero
      ? lhs.low.quotientAndRemainder(dividingBy: rhs.low)
      : rhs.low.dividingFullWidth((F.Magnitude(a), lhs.low)))
    return (quotient: (high: x, low: y), remainder: (high: 0, low: b))
  }

  // Left shift both rhs and lhs, then divide and right shift the remainder.
  let shift = F.Magnitude(rhs.high.leadingZeroBitCount)
  let rollover = F.Magnitude(F.bitWidth + F.Magnitude.bitWidth) &- shift
  let rhs = _wideMaskedShiftLeft(rhs, shift)
  let high = _wideMaskedShiftRight(lhs, rollover).low
  let lhs = _wideMaskedShiftLeft(lhs, shift)
  let (quotient, remainder) = _wideDivide32(
    (F(high), F.Magnitude(lhs.high), lhs.low), by: rhs)
  return (
    quotient: (high: 0, low: F.Magnitude(quotient)),
    remainder: _wideMaskedShiftRight(remainder, shift))
}

/// Returns the quotient and remainder after dividing a quadruple-width
/// magnitude `lhs` by a double-width magnitude `rhs`.
func _wideDivide42<F: FixedWidthInteger & UnsignedInteger>(
  _ lhs: _Wide4<F>, by rhs: _Wide2<F>
) -> (quotient: _Wide2<F>, remainder: _Wide2<F>) {
  guard _fastPath(rhs > (F.zero, F.Magnitude.zero)) else {
    fatalError("Division by zero")
  }
  guard _fastPath(rhs >= lhs.high) else {
    fatalError("Division results in an overflow")
  }

  if lhs.high == (F.zero, F.Magnitude.zero) {
    return _wideDivide22((high: F(lhs.low.high), low: lhs.low.low), by: rhs)
  }

  if rhs.high == F.zero {
    let a = F.Magnitude(lhs.high.high) % rhs.low
    let b = (a == F.Magnitude.zero
      ? lhs.high.low % rhs.low
      : rhs.low.dividingFullWidth((a, lhs.high.low)).remainder)
    let (x, c) = (b == F.Magnitude.zero
      ? lhs.low.high.quotientAndRemainder(dividingBy: rhs.low)
      : rhs.low.dividingFullWidth((b, lhs.low.high)))
    let (y, d) = (c == F.Magnitude.zero
      ? lhs.low.low.quotientAndRemainder(dividingBy: rhs.low)
      : rhs.low.dividingFullWidth((c, lhs.low.low)))
    return (quotient: (high: F(x), low: y), remainder: (high: 0, low: d))
  }

  // Left shift both rhs and lhs, then divide and right shift the remainder.
  let shift = F.Magnitude(rhs.high.leadingZeroBitCount)
  let rollover = F.Magnitude(F.bitWidth + F.Magnitude.bitWidth) &- shift
  let rhs = _wideMaskedShiftLeft(rhs, shift)

  let lh1 = _wideMaskedShiftLeft(lhs.high, shift)
  let lh2 = _wideMaskedShiftRight(lhs.low, rollover)
  let lhs = (
    high: (high: lh1.high | F(lh2.high), low: lh1.low | lh2.low),
    low: _wideMaskedShiftLeft(lhs.low, shift))

  if
    lhs.high.high == F.Magnitude.zero,
    (high: F(lhs.high.low), low: lhs.low.high) < rhs
  {
    let (quotient, remainder) = _wideDivide32(
      (F(lhs.high.low), lhs.low.high, lhs.low.low),
      by: rhs)
    return (
      quotient: (high: 0, low: F.Magnitude(quotient)),
      remainder: _wideMaskedShiftRight(remainder, shift))
  }
  let (x, a) = _wideDivide32(
    (lhs.high.high, lhs.high.low, lhs.low.high), by: rhs)
  let (y, b) = _wideDivide32((a.high, a.low, lhs.low.low), by: rhs)
  return (
    quotient: (high: x, low: F.Magnitude(y)),
    remainder: _wideMaskedShiftRight(b, shift))
}

extension Int128: SignedNumeric, SignedInteger {}
