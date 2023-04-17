import Foundation

public struct UInt128 : Sendable {
    
    /// This gets used quite a bit so provide a prebuilt value
    static public let zero = (0,0)
    
    /// Internal data representation - pretty simple
    var value : (highBits:UInt64, lowBits:UInt64)
    
    // MARK: - Initializers
    
    public init(high: UInt64, low: UInt64) {
        value.highBits = high
        value.lowBits  = low
    }
    
    public init() {
        self = Self.zero
    }
    
    private init(_ digits: [Digit]) {
//        var digits = digits
//        let mask = Digit(Self.mask)
//        let shift = Digit(Self.shift)
//        while digits.count < 5 { digits.append(0) }
//        let low  = UInt64(digits[0] & mask) |                 // lowest 31 bits
//                   (UInt64(digits[1] & mask) << shift) |      // next 31 bits
//                   (UInt64(digits[2] & 0x3) << (shift*2))     // and 2 bits
//        let high = UInt64(digits[2] & mask) >> 2 |            // next 29 bits
//                   (UInt64(digits[3] & mask) << (shift-2)) |  // next 31 bits
//                   (UInt64(digits[4]) << 60)                  // last 4 bits
        self.init(high: UInt64(digits[1]), low: UInt64(digits[0]))
    }
}

extension UInt128 : Codable {
    
    enum CodingKeys: String, CodingKey {
        case highWord, lowWord
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let high = try values.decode(UInt64.self, forKey: .highWord)
        let low = try values.decode(UInt64.self, forKey: .lowWord)
        value = (high, low)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value.highBits, forKey: .highWord)
        try container.encode(value.lowBits, forKey: .lowWord)
    }
}

extension UInt128 : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value.highBits)
        hasher.combine(value.lowBits)
    }
}

extension UInt128 : ExpressibleByIntegerLiteral {
    
    // FIXME: - Please uncomment if your OS supports the StaticBigInt
    // You'll also need to comment out the Int version.
//    @available(macOS 13.3, *)
//    public init(integerLiteral value: StaticBigInt) {
//        precondition(
//            value.signum() >= 0 && value.bitWidth <= Self.bitWidth + 1,
//            "'\(value)' has too many digits for '\(Self.self)'"
//        )
//        self.init(high: UInt64(value[1]), low: UInt64(value[0]))
//    }
    
    public init(integerLiteral value: Int) {
        self.init(high: 0, low: UInt64(value))
    }
}

extension UInt128 : Comparable, Equatable {
    
    static public func < (lhs: UInt128, rhs: UInt128) -> Bool {
        if lhs.value.highBits < rhs.value.highBits {
            return true
        } else if lhs.value.highBits == rhs.value.highBits && lhs.value.lowBits < rhs.value.lowBits {
            return true
        }
        return false
    }
    
    static public func == (lhs: UInt128, rhs: UInt128) -> Bool {
        if lhs.value.lowBits == rhs.value.lowBits && lhs.value.highBits == rhs.value.highBits {
            return true
        }
        return false
    }
}

extension UInt128 : CustomStringConvertible, CustomDebugStringConvertible {
    
    /// Divides `x` by rⁿ where r is the `radix`. Returns the quotient, remainder, and digits
    private static func div (x: UInt128, radix: Int) -> (q:UInt128, r:UInt64, digits:Int) {
        let maxDivisor: UInt64
        let digits: Int
        switch radix {
            case 2:  maxDivisor = UInt64(9_223_372_036_854_775_808); digits = 63
            case 8:  maxDivisor = UInt64(9_223_372_036_854_775_808); digits = 21
            case 16: maxDivisor = UInt64(1_152_921_504_606_846_976); digits = 15
            case 10: maxDivisor = UInt64(10_000_000_000_000_000_000); digits = 19
            default:
                // Note: Max radix = 36 so 36¹² = 4_738_381_338_321_616_896 < UInt64.max
                var power = radix*radix         // squared
                power *= power                  // 4th power
                power = power * power * power   // 12th power
                maxDivisor = UInt64(power); digits = 12
        }
        let result = x.quotientAndRemainder(dividingBy: UInt128(high: 0, low: maxDivisor))
        return (result.quotient, result.remainder.value.lowBits, digits)
    }
    
    /// Converts the UInt128 `self` into a string with a given `radix`.  The radix
    /// string can use uppercase characters if `uppercase` is true.
    public func string(withRadix radix:Int = 10, uppercase:Bool = false) -> String {
        if self == Self.zero { return "0" }
        let radix = Swift.min(radix, 36)
        var result = (q:self, r:UInt64(0), digits:0)
        var str = ""
        while result.q != Self.zero {
            result = Self.div(x: result.q, radix: radix)
            var temp = String(result.r, radix: radix, uppercase: uppercase)
            if result.q != Self.zero {
                temp = "".padding(toLength: result.digits-temp.count, withPad: "0", startingAt: 0) + temp
            }
            str = temp + str
        }
        return str
    }
    
    public var description: String { string() }
    
    public var debugDescription: String { string() }
}

extension UInt128 : ExpressibleByStringLiteral {
    
    public init(stringLiteral s: String) {
        self.init()
        if let newValue = value(from: s) {
            self = newValue
        }
    }

    public init?(_ string: String, radix: Int = 10) {
        if string.isEmpty { return nil }
        self.init()
        if let x = value(from: string, radix: radix) {
            self = x; return
        }
        return nil
    }
    
    private func value(from string: String, radix: Int = 10) -> UInt128? {
        // Do our best to clean up the input string
        let spaces = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "_"))
        var radix = UInt64(radix)
        var s = string.components(separatedBy: spaces).joined()
        if s.hasPrefix("+") { s.removeFirst() }
        if s.hasPrefix("-") { return nil }
        if s.hasPrefix("0x") { s.removeFirst(2); radix = 16 }
        if s.hasPrefix("0b") { s.removeFirst(2); radix = 2 }
        if s.hasPrefix("0o") { s.removeFirst(2); radix = 8 }
        while s.hasPrefix("0") { s.removeFirst() }
        
        // Translate the string into a number
        var r = UInt128()
        let _ = Self.timesOne(to: 1, x: Self.zero, radix: radix)  // initialize the table
        while !s.isEmpty {
            // remove 18 digits at a time
            let chunk = s.prefix(Self.powers.count)
            let size = chunk.count; s.removeFirst(size)
            if let uint = UInt64(chunk, radix: Int(radix)) {
                if size != 0 {
                    r = Self.timesOne(to: size, x: r, radix: radix)
                }
                r += UInt128(high: 0, low: uint)
            } else {
                return nil
            }
        }
        return r
    }
    
    static var powers = [UInt64]()  /* powers of radix up to UInt64.max */
    
    /// Multiplies `x` by rⁿ where r is the `radix` and returns the product
    private static func timesOne(to n: Int, x: UInt128, radix: UInt64) -> UInt128 {
        // calculate the powers of 10 — you'll thank me later
        if powers.isEmpty || powers.first! != radix {
            powers = [UInt64]()
            var x = UInt64(1)
            while x < UInt64.max / radix {
                x *= radix
                powers.append(x)
            }
        }
        let oneToPower = Self.powers[n-1]
        let result = x * UInt128(high:0, low:oneToPower)
        return result
    }
}

extension UInt128 : BinaryInteger {

    public typealias Words = [UInt]
    
    // MARK: - Class properties
    
    public static let bitWidth = 128
    
    // MARK: - Instance properties

    public var words: Words { Array(value.lowBits.words) + Array(value.highBits.words) }
    public var magnitude: UInt128 { self }
    public var bitWidth: Int { value.highBits.bitWidth + value.lowBits.bitWidth }
    
    public init?<T>(exactly source: T) where T : BinaryFloatingPoint {
        if source.isZero { self = UInt128(); return }
        guard source.exponent >= 0 && source.rounded() == source else { return nil }
        self = UInt128(UInt64(source))
    }
    
    public init<T>(_ source: T) where T : BinaryFloatingPoint {
        self.init(high: 0, low: UInt64(source))
    }
    
    public init<T>(_ source: T) where T : BinaryInteger {
        if let n = source as? Self { self = n; return }
        self.init(high: 0, low: UInt64(source))
    }
    
    public init<T>(truncatingIfNeeded source: T) where T : BinaryInteger {
        if let n = source as? Self { self = n; return }
        if source.signum() < 0 {
            // negative numbers must be sign-extended
            let mag = UInt128(source.magnitude)
            let num = UInt128.max - mag
            self = num
            return
        }
        self.init(high: 0, low: UInt64(source))
    }
    
    public init<T>(clamping source: T) where T : BinaryInteger {
        if let n = source as? Self { self = n; return }
        guard source >= 0 else { self = Self.min; return }
        guard source.bitWidth <= Self.bitWidth else { self = Self.max; return }
        self.init(high: 0, low: UInt64(source))
    }
    
    public var trailingZeroBitCount: Int {
        if value.lowBits == 0 {
            return value.highBits.trailingZeroBitCount + value.lowBits.bitWidth
        }
        return value.lowBits.trailingZeroBitCount
    }
    
    public var leadingZeroBitCount: Int {
        if value.highBits == 0 {
            return value.lowBits.leadingZeroBitCount + value.highBits.bitWidth
        }
        return value.highBits.leadingZeroBitCount
    }
    
    // MARK: - Basic Mathematical Operations
    public static func + (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let result = lhs.addingReportingOverflow(rhs)
        assert(!result.overflow, "Overflow during addition!")
        return result.partialValue
    }
    
    public static func - (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let result = lhs.subtractingReportingOverflow(rhs)
        assert(!result.overflow, "Underflow during subtraction!")
        return result.partialValue
    }
    
    public static func * (lhs: UInt128, rhs: UInt128) -> UInt128 {
        // Multiplies the lhs by the rhs.value.lowBits and reports overflow
        let result = lhs.multipliedReportingOverflow(by: rhs)
        assert(!result.overflow, "Multiplication overflow")
        return result.partialValue
    }
    
    public static func / (lhs: UInt128, rhs: UInt128) -> UInt128 {
        //let result = divRemAbs(lhs.toInteger(), w1: rhs.toInteger())
        let result = divideWithRemainder_KnuthD((0, lhs), by: rhs).quotient
        return UInt128(result)
    }

    public static func % (lhs: UInt128, rhs: UInt128) -> UInt128 {
        // let result = divRemAbs(lhs.toInteger(), w1: rhs.toInteger())
        let result = divideWithRemainder_KnuthD((0, lhs), by: rhs).remainder
        return UInt128(result)
    }

    public func quotientAndRemainder (dividingBy rhs: UInt128) -> (quotient: UInt128, remainder: UInt128) {
        // let result = Self.divRemAbs(self.toInteger(), w1: rhs.toInteger())
        let result = Self.divideWithRemainder_KnuthD((0, self), by: rhs)
        return (UInt128(result.quotient), UInt128(result.remainder))
    }
    
    
    // MARK: - Convenience math functions
    public static func /= (lhs: inout UInt128, rhs: UInt128) { lhs = lhs / rhs }
    public static func %= (lhs: inout UInt128, rhs: UInt128) { lhs = lhs % rhs }
    public static func *= (lhs: inout UInt128, rhs: UInt128) { lhs = lhs * rhs }
    
    // MARK: - Logical functions
    public static func & (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let lhs = lhs.value; let rhs = rhs.value
        return UInt128(high:lhs.highBits & rhs.highBits, low: lhs.lowBits & rhs.lowBits)
    }
    
    public static func | (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let lhs = lhs.value; let rhs = rhs.value
        return UInt128(high: lhs.highBits | rhs.highBits, low: lhs.lowBits | rhs.lowBits)
    }
    
    public static func ^ (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let lhs = lhs.value; let rhs = rhs.value
        return UInt128(high: lhs.highBits ^ rhs.highBits, low: lhs.lowBits ^ rhs.lowBits)
    }
    
    public static func &= (lhs: inout UInt128, rhs: UInt128) { lhs = lhs & rhs }
    public static func |= (lhs: inout UInt128, rhs: UInt128) { lhs = lhs | rhs }
    public static func ^= (lhs: inout UInt128, rhs: UInt128) { lhs = lhs ^ rhs }
    
    // MARK: - Shifting functions
    public static func >> <RHS>(lhs: UInt128, rhs: RHS) -> UInt128 where RHS : BinaryInteger {
        if rhs.signum() < 0 { return lhs << rhs.magnitude }
        if rhs >= Self.bitWidth { return Self.zero }
        if rhs >= UInt64.bitWidth {
            return UInt128(high: 0, low: lhs.value.highBits >> (Int(rhs)-UInt64.bitWidth))
        } else {
            let shiftOut = lhs.value.highBits << (UInt64.bitWidth-Int(rhs))
            return UInt128(high: lhs.value.highBits >> rhs, low: lhs.value.lowBits >> rhs | shiftOut)
        }
    }
    
    public static func << <RHS>(lhs: UInt128, rhs: RHS) -> UInt128 where RHS : BinaryInteger {
        if rhs.signum() < 0 { return lhs >> rhs.magnitude }
        if rhs >= Self.bitWidth { return Self.zero }
        if rhs >= UInt64.bitWidth {
            return UInt128(high: lhs.value.lowBits << (Int(rhs)-UInt64.bitWidth), low: 0)
        } else {
            let shiftOut = lhs.value.lowBits >> (UInt64.bitWidth-Int(rhs))
            return UInt128(high: lhs.value.highBits << rhs | shiftOut, low: lhs.value.lowBits << rhs)
        }
    }
    
    public static func >>= <RHS>(lhs: inout UInt128, rhs: RHS) where RHS : BinaryInteger {
        lhs = lhs >> rhs
    }
    
    public static func &>>= <RHS>(lhs: inout UInt128, rhs: RHS) where RHS : BinaryInteger {
        lhs = lhs >> (rhs & RHS(UInt128.bitWidth-1))
    }
    
    public static func <<= <RHS>(lhs: inout UInt128, rhs: RHS) where RHS : BinaryInteger {
        lhs = lhs << rhs
    }
    
    public static func &<<= <RHS>(lhs: inout UInt128, rhs: RHS) where RHS : BinaryInteger {
        lhs = lhs << (rhs & RHS(UInt128.bitWidth-1))
    }
}

extension UInt128 : UnsignedInteger { }

extension UInt128 : Numeric {
    public init?<T>(exactly source: T) where T : BinaryInteger {
        guard source.bitWidth <= Self.bitWidth else { return nil }
        self.init(high: 0, low: UInt64(source))
    }
}

extension UInt128 : FixedWidthInteger {
    
    public var nonzeroBitCount: Int {
        value.highBits.nonzeroBitCount + value.lowBits.nonzeroBitCount
    }
    
    public var byteSwapped: UInt128 {
        UInt128(high: value.lowBits.byteSwapped, low: value.highBits.byteSwapped)
    }
    
    public init(_truncatingBits bits: UInt) {
        self.init(high: 0, low: UInt64(bits))
    }
      
    public func addingReportingOverflow(_ rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        let (lowBits, lowOverflow) = self.value.lowBits.addingReportingOverflow(rhs.value.lowBits)
        var (highBits, highOverflow) = self.value.highBits.addingReportingOverflow(rhs.value.highBits)
        var resultOverflow = false
        if lowOverflow {
            (highBits, resultOverflow) = highBits.addingReportingOverflow(1)
        }
        return (UInt128(high: highBits , low: lowBits), resultOverflow || highOverflow)
    }

    public func subtractingReportingOverflow(_ rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        let (lowBits, lowOverflow) = self.value.lowBits.subtractingReportingOverflow(rhs.value.lowBits)
        var (highBits, highOverflow) = self.value.highBits.subtractingReportingOverflow(rhs.value.highBits)
        var resultOverflow = false
        if lowOverflow {
            (highBits, resultOverflow) = highBits.subtractingReportingOverflow(1)
        }
        return (UInt128(high: highBits , low: lowBits), resultOverflow || highOverflow)
    }
    
    public func multipliedReportingOverflow(by rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        let result = self.multipliedFullWidth(by: rhs)
        return (result.low, result.high != Self.zero)
    }
    
    public func multipliedFullWidth(by other: UInt128) -> (high: UInt128, low: UInt128) {
        let lhs = self
        let rhs = other
        let productLL = lhs.value.lowBits.multipliedFullWidth(by: rhs.value.lowBits)
        let productHL = lhs.value.highBits.multipliedFullWidth(by: rhs.value.lowBits)
        
        // Multiplies the lhs by the rhs.value.highBits and reports overflow
        let productLH = lhs.value.lowBits.multipliedFullWidth(by: rhs.value.highBits)
        let productHH = lhs.value.highBits.multipliedFullWidth(by: rhs.value.highBits)
        
        // Add the various products together
        var resultLow = UInt128(high: 0, low:productLL.low)
        let addMidl = UInt128(productLL.high) + UInt128(productHL.low) + UInt128(productLH.low)
        resultLow.value.highBits = addMidl.value.lowBits
        let addMidu = UInt128(addMidl.value.highBits) + UInt128(productHL.high) + UInt128(productLH.high) + UInt128(productHH.low)
        let addHigh = addMidu.value.highBits + productHH.high
        let resultHigh = UInt128(high: addHigh, low: addMidu.value.lowBits)
        return (resultHigh, resultLow)
    }

    public func dividedReportingOverflow(by rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        guard rhs != Self.zero else { return (self, true) }
        // let result = Self.divRemAbs(self.toInteger(), w1: rhs.toInteger()).div
        let result = Self.divideWithRemainder_KnuthD((0, self), by: rhs).quotient
        return (UInt128(result), false)
    }

    public func remainderReportingOverflow(dividingBy rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        guard rhs != Self.zero else { return (self, true) }
        // let result = Self.divRemAbs(self.toInteger(), w1: rhs.toInteger()).rem
        let result = Self.divideWithRemainder_KnuthD((0, self), by: rhs).remainder
        return (UInt128(result), false)
    }

    public func dividingFullWidth(_ dividend: (high: UInt128, low: UInt128)) -> (quotient: UInt128, remainder: UInt128) {
        //let result = Self.divRemAbs(Self.toInteger(high:dividend.high, low:dividend.low), w1: self.toInteger())
        let result = Self.divideWithRemainder_KnuthD(dividend, by: self)
        return (UInt128(result.quotient), UInt128(result.remainder))
    }
    
}

// MARK: - TwoDigit Helper Utility Methods

// -------------------------------------
private extension FixedWidthInteger {
    /// Fast creation of an integer from a Bool
    init(_ source: Bool) {
        assert(unsafeBitCast(source, to: UInt8.self) & 0xfe == 0)
        self.init(unsafeBitCast(source, to: UInt8.self))
    }
}

private typealias Digit = UInt
private typealias TwoDigits = (high: Digit, low: Digit)

/**
 The operators below implement the tuple operations for the 2-digit
 arithmetic needed for Knuth's Algorithm D, and *only* those operations.
 There is no attempt to be a complete set. They are meant to make the code that
 uses them more readable than if the operations they express were written out
 directly.
 */

infix operator /% : MultiplicationPrecedence

/// Divide a tuple of digits `left` by 1 digit `right` returning both quotient and remainder
private func /% (left: TwoDigits, right: Digit) -> (quotient: TwoDigits, remainder: TwoDigits) {
    var r: Digit
    let q: TwoDigits
    (q.high, r) = left.high.quotientAndRemainder(dividingBy: right)
    (q.low, r) = right.dividingFullWidth((high: r, low: left.low))
    return (q, (high: 0, low: r))
}

/// Multiply a tuple of digits `left` by 1 digit `right` returning both quotient and remainder
private func * (left: TwoDigits, right: Digit) -> TwoDigits {
    var product = left.low.multipliedFullWidth(by: right)
    let productHigh = left.high.multipliedFullWidth(by: right)
    assert(productHigh.high == 0, "multiplication overflow")
    let c = addReportingCarry(&product.high, productHigh.low)
    assert(c == 0, "multiplication overflow")
    return product
}

private func > (left: TwoDigits, right: TwoDigits) -> UInt8 {
    return UInt8(left.high > right.high) |
            (UInt8(left.high == right.high) & UInt8(left.low > right.low))
}

/// Subtract a digit from a tuple, borrowing the high part if necessary
private func -= (left: inout TwoDigits, right: Digit) {
    left.high &-= subtractReportingBorrow(&left.low, right)
}

/// Add a digit to a tuple's low part, carrying to the high part.
private func += (left: inout TwoDigits, right: Digit) {
    left.high &+= addReportingCarry(&left.low, right)
}

// -------------------------------------
/// Add one tuple to another tuple
private func += (left: inout TwoDigits, right: TwoDigits) {
    left.high &+= addReportingCarry(&left.low, right.low)
    left.high &+= right.high
}

private func subtractReportingBorrow(_ x: inout Digit, _ y: Digit) -> Digit {
    let b: Bool
    (x, b) = x.subtractingReportingOverflow(y)
    return Digit(b)
}

private func addReportingCarry(_ x: inout Digit, _ y: Digit) -> Digit {
    let c: Bool
    (x, c) = x.addingReportingOverflow(y)
    return Digit(c)
}

extension UInt128 {
    
    /*************************************************************************************/
    /**  Following division code was shamelessly borrowed from Chip Jarred who in turn   */
    /**  implemented the algorithm from Donald Knuth's *Algorithm D* for dividing        */
    /**  multiprecision unsigned integers from *The Art of Computer Programming*         */
    /**  Volume 2: *Semi-numerical Algorithms*, Chapter 4.3.3.                           */
    
    /*
        Copyright 2020 Chip Jarred

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        SOFTWARE.
    */
    private static func leftShift(_ x: [Digit], by shift: Int, into y: inout [Digit]) {
        assert(y.count >= x.count)
        assert(y.startIndex == x.startIndex)
        let bitWidth = Digit.bitWidth
        
        for i in (1..<x.count).reversed() {
            y[i] = (x[i] << shift) | (x[i - 1] >> (bitWidth - shift))
        }
        y[0] = x[0] << shift
    }
    
    private static func rightShift(_ x: [Digit], by shift: Int, into y: inout [Digit]) {
        assert(y.count == x.count)
        assert(y.startIndex == x.startIndex)
        let bitWidth = Digit.bitWidth
        
        let lastElemIndex = x.count - 1
        for i in 0..<lastElemIndex {
            y[i] = (x[i] >> shift) | (x[i + 1] << (bitWidth - shift))
        }
        y[lastElemIndex] = x[lastElemIndex] >> shift
    }
    
    
    private static func divide(_ x: [Digit], by y: Digit, result z: inout [Digit]) -> Digit {
        assert(x.count == z.count)
        assert(x.startIndex == z.startIndex)
        
        var r: Digit = 0
        var i = x.count - 1
        
        (z[i], r) = x[i].quotientAndRemainder(dividingBy: y)
        i -= 1
        
        while i >= 0 {
            (z[i], r) = y.dividingFullWidth((r, x[i]))
            i -= 1
        }
        return r
    }
        
    private static func subtractReportingBorrow(_ x: [Digit], times k: Digit, from y: inout ArraySlice<Digit>) -> Bool {
        assert(x.count + 1 <= y.count)
        
        func subtractReportingBorrow(_ x: inout Digit, _ y: Digit) -> Digit {
            let b: Bool
            (x, b) = x.subtractingReportingOverflow(y)
            return Digit(b)
        }
        
        var i = x.startIndex
        var j = y.startIndex

        var borrow: Digit = 0
        while i < x.endIndex {
            borrow = subtractReportingBorrow(&y[j], borrow)
            let (pHi, pLo) = k.multipliedFullWidth(by: x[i])
            borrow &+= pHi
            borrow &+= subtractReportingBorrow(&y[j], pLo)
            
            i &+= 1
            j &+= 1
        }
        return 0 != subtractReportingBorrow(&y[j], borrow)
    }
    
    private static func divideWithRemainder_KnuthD(_ dividend: (high:UInt128, low:UInt128), by divisor: UInt128) ->
    (quotient: [Digit], remainder: [Digit]) {
        assert(divisor != 0, "Division by 0")
        
        let digitWidth = Digit.bitWidth
        let dividend = dividend.low.words + dividend.high.words
        let divisor =  divisor.words
        let m = dividend.count
        let n = divisor.count
        
        assert(n > 0, "Divisor must have at least one digit")
        assert(m >= n, "Dividend must have at least as many digits as the divisor")

        var quotient = [Digit](repeating: 0, count: m-n+1)
        var remainder = [Digit](repeating: 0, count: n)
        
        guard n > 1 else {
            remainder[0] = divide(dividend, by: divisor.first!, result: &quotient)
            return (quotient, remainder)
        }
        
        let shift = divisor.last!.leadingZeroBitCount
        
        var v = [Digit](repeating: 0, count: n)
        leftShift(divisor, by: shift, into: &v)

        var u = [Digit](repeating: 0, count: m + 1)
        u[m] = dividend[m - 1] >> (digitWidth - shift)
        leftShift(dividend, by: shift, into: &u)
        
        let vLast: Digit = v.last!
        let vNextToLast: Digit = v[n - 2]
        let partialDividendDelta: TwoDigits = (high: vLast, low: 0)

        for j in (0...(m - n)).reversed() {
            let jPlusN = j &+ n
            
            let dividendHead: TwoDigits = (high: u[jPlusN], low: u[jPlusN &- 1])
            
            // These are tuple arithemtic operations.  `/%` is custom combined
            // division and remainder operator.  See above.
            var (q̂, r̂) = dividendHead /% vLast
            var partialProduct = q̂ * vNextToLast
            var partialDividend:TwoDigits = (high: r̂.low, low: u[jPlusN &- 2])
            
            while true {
                if (UInt8(q̂.high != 0) | (partialProduct > partialDividend)) == 1 {
                    q̂ -= 1
                    r̂ += vLast
                    partialProduct -= vNextToLast
                    partialDividend += partialDividendDelta
                    
                    if r̂.high == 0 { continue }
                }
                break
            }

            quotient[j] = q̂.low
            
            if subtractReportingBorrow(Array(v[0..<n]), times: q̂.low, from: &u[j...jPlusN]) {
                quotient[j] &-= 1
                u[j...jPlusN] += v[0..<n] // digit collection addition!
            }
        }
        
        rightShift(Array(u[0..<n]), by: shift, into: &remainder)
        return (quotient, remainder)
    }
}

// MARK: - BinaryFloatingPoint Interoperability

extension BinaryFloatingPoint {
    public init(_ value: UInt128) {
        precondition(value.value.highBits == 0, "Value is too large to fit into a BinaryFloatingPoint until a 128bit BinaryFloatingPoint type is defined.")
        self.init(value.value.lowBits)
    }

    public init?(exactly value: UInt128) {
        if value.value.highBits > 0 {
            return nil
        }
        self = Self(value.value.lowBits)
    }
}
