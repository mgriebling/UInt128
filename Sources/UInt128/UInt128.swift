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
        var digits = digits
        let mask = Digit(Self.mask)
        let shift = Digit(Self.shift)
        while digits.count < 5 { digits.append(0) }
        let low  = UInt64(digits[0] & mask) |                 // lowest 31 bits
                   (UInt64(digits[1] & mask) << shift) |      // next 31 bits
                   (UInt64(digits[2] & 0x3) << (shift*2))     // and 2 bits
        let high = UInt64(digits[2] & mask) >> 2 |            // next 29 bits
                   (UInt64(digits[3] & mask) << (shift-2)) |  // next 31 bits
                   (UInt64(digits[4]) << 60)                  // last 4 bits
        self.init(high: high, low: low)
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
        let result = divRemAbs(lhs.toInteger(), w1: rhs.toInteger())
        return UInt128(result.div)
    }

    public static func % (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let result = divRemAbs(lhs.toInteger(), w1: rhs.toInteger())
        return UInt128(result.rem)
    }

    public func quotientAndRemainder (dividingBy rhs: UInt128) -> (quotient: UInt128, remainder: UInt128) {
        let result = Self.divRemAbs(self.toInteger(), w1: rhs.toInteger())
        return (UInt128(result.div), UInt128(result.rem))
    }
    
    
    // MARK: - Helper functions for division and modulo
    
    private typealias Digit = UInt32
    private typealias TwoDigits = UInt64
    private typealias Integer = [Digit]
    private static let shift = Digit.bitWidth-1
    private static let base  = 1 << shift
    private static let mask  = base - 1
    
    /// Note: Each Integer word contains 31 bits so the
    /// 128 bits must be broken into 5 words with the
    /// upper word having 4 bits and all others 31.
    private func toInteger(fullNormalization:Bool = false) -> Integer {
        let mask  = TwoDigits(Self.mask)
        var low   = TwoDigits(self.value.lowBits)
        var high  = TwoDigits(self.value.highBits)
        let low1  = Digit(low & mask); low >>= Self.shift
        let low2  = Digit(low & mask); low >>= Self.shift
        let mid   = Digit(low) | (Digit(high & (mask >> 2)) << 2); high >>= Self.shift-2
        let high1 = Digit(high & mask); high >>= Self.shift
        let high2 = Digit(high)
        
        // quick normalization
        if high2 == 0 {
            if high1 == 0 {
                if mid == 0 {
                    if fullNormalization && low2 == 0 {
                        return [low1]
                    }
                    // Note: div algorithm needs at least two words
                    // so the upper word `low2` may be zero at this point
                    return [low1, low2]
                }
                return [low1, low2, mid]
            }
            return [low1, low2, mid, high1]
        }
        return [low1, low2, mid, high1, high2]
    }
    
    private static func toInteger(high:UInt128, low:UInt128) -> Integer {
        // realign the bits into words
        var xh = high.toInteger(fullNormalization: true)

        // shift left by 128 bits
        if high != UInt128.zero {
            xh.insert(contentsOf: [0,0,0,0], at: 0) // shift left 31*4 = 124 bits
            Self.mul(&xh, n: 0x10)                  // shift left 4 bits
        }

        // add in the low digits
        if low != UInt128.zero {
            // realign the bits for the Integer-representation
            let xl = low.toInteger(fullNormalization: true)
            return xl + xh
        } else {
            return xh
        }
    }
    
    /// Multiply `a` by a single digit *n*, ignoring the sign.
    private static func mul(_ a: inout [Digit], n: Digit) {
        let sizeA = a.count
        var z = [Digit](repeating: 0, count: sizeA+1)
        var carry = TwoDigits(0)
        for i in 0..<sizeA {
            carry += TwoDigits(a[i]) * TwoDigits(n)
            z[i] = Digit(carry & TwoDigits(mask))
            carry >>= TwoDigits(shift)
        }
        z[sizeA] = Digit(carry)
        normalize(&z)
        a = z
    }
    
    private static func normalize(_ a: inout [Digit]) {
        while a.last == 0 { a.removeLast() }
    }
    
    /// Divide a long integer *a* by a digit *n*, returning both the quotient
    /// (as function result) and the remainder *rem*.
    /// The sign of *a* is ignored; *n* should not be zero.
    private static func divRem (_ a: [Digit], n: TwoDigits) -> (div:[Digit], rem:Digit) {
        assert(n > 0 && n <= base, "\(#function): assertion failed")
        let size = a.count
        var z = a
        var rem = TwoDigits(0)
        for size in (0..<size).reversed() {
            rem = (rem << shift) | TwoDigits(a[size])
            let hi = rem / n
            z[size] = Digit(hi)
            rem -= hi * n
        }
        normalize(&z)
        return (z, Digit(rem))
    }
    
    /// Unsigned long division of `v1` divided by `w1` with remainder.
    /// Note: This algorithm will work with unsigned integers of any length
    private static func divRemAbs (_ v1: [Digit], w1: [Digit]) -> (div: [Digit], rem: [Digit]) {
        let sizeW = w1.count
        let d = Digit(TwoDigits(base) / TwoDigits(w1[sizeW-1]+1))
        var v = v1, w = w1
        Self.mul(&v, n:d)
        Self.mul(&w, n:d)
        
        guard v.count > 0 else { return (v1, v1) }
        guard v1.count >= sizeW && sizeW > 1 else { return ([Digit](), v1) }

        assert(sizeW == w.count, "\(#function): assertion 2 failed")
        
        let sizeV = v.count
        var a = [Digit](repeating: 0, count: sizeV-sizeW+1)
        var j = sizeV
        for k in (0..<a.count).reversed() {
            let vj: TwoDigits = j >= sizeV ? 0 : TwoDigits(v[j])
            let base = TwoDigits(base)
            let mask = TwoDigits(mask)
            let w1digit = TwoDigits(w[sizeW-1])
            let w2digit = TwoDigits(w[sizeW-2])
            let vdigit = TwoDigits(v[j-1])
            var q = vj == w1digit ? mask : (vj*base + vdigit) / w1digit
            
            while w2digit*q > (vj*base + vdigit - q*w1digit)*base + TwoDigits(v[j-2]) {
                q -= 1
            }
            
            var i = 0
            var carry: Int = 0
            while i < sizeW && i+k < sizeV {
                let z = TwoDigits(w[i])*q
                let zz = z / base
                carry += Int(v[i+k]) - Int(z) + Int(zz*base)
                v[i+k] = Digit(carry & Int(mask))
                carry >>= shift
                carry -= Int(zz)
                i += 1
            }
            
            if i+k < sizeV {
                carry += Int(v[i+k])
                v[i+k] = 0
            }
            
            if carry == 0 {
                a[k] = Digit(q)
            } else {
                assert(carry == -1, "\(#function): carry != -1")
                a[k] = Digit(q-1)
                carry = 0
                for i in 0..<sizeW where i+k < sizeV {
                    carry += Int(v[i+k] + w[i])
                    v[i+k] = Digit(carry & Int(mask))
                    carry >>= TwoDigits(shift)
                }
            }
            j -= 1
        }
        normalize(&a)
        let (div, _) = divRem(v, n:TwoDigits(d))
        return (a, div)
    } // DivRemAbs;
    
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
        let result = Self.divRemAbs(self.toInteger(), w1: rhs.toInteger()).div
        return (UInt128(result), false)
    }

    public func remainderReportingOverflow(dividingBy rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        guard rhs != Self.zero else { return (self, true) }
        let result = Self.divRemAbs(self.toInteger(), w1: rhs.toInteger()).rem
        return (UInt128(result), false)
    }

    public func dividingFullWidth(_ dividend: (high: UInt128, low: UInt128)) -> (quotient: UInt128, remainder: UInt128) {
        let result = Self.divRemAbs(Self.toInteger(high:dividend.high, low:dividend.low), w1: self.toInteger())
        return (UInt128(result.div), UInt128(result.rem))
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
