import Foundation

public struct UInt128 : Sendable {
    
    /// Internal data representation - pretty simple
    let value : (high:UInt64, low:UInt64)
    
    // MARK: - Initializers
    public init() {
        value = (0,0)
    }
    
    private init(high: UInt64, low: UInt64) {
        value = (high, low)
    }
    
    private init(_ words: [UInt]) {
        var words = words
        while words.count < 2 { words.append(0) }
        self.init(high: UInt64(words[1]), low: UInt64(words[0]))
    }
    
    private init(_ digits: [Digit]) {
        var digits = digits
        while digits.count < 4 { digits.append(0) }
        let low  = UInt64(digits[0] & Self.mask) |                   // lowest 31 bits
                   (UInt64(digits[1] & Self.mask) << Self.shift) |   // next 31 bits
                   (UInt64(digits[2] & 0x3) << (Self.shift*2))       // and 2 bits
        let high = UInt64(digits[2] & Self.mask) >> 2 |              // next 29 bits
                   (UInt64(digits[3] & Self.mask) << (Self.shift-2)) // last 31 bits
        self.init(high: high, low: low)
    }
    
    public init<T>(_ source: T) where T : BinaryInteger {
        let x = source.words.map { UInt($0) }
        self.init(x)
    }
    
    public init<T>(clamping source: T) where T : BinaryInteger {
        if source.bitWidth > Self.bitWidth { self.init(Words(repeating: UInt.max, count: Self.bitWidth / UInt.bitWidth)) }
        self.init(source)
    }
    
    public init<T>(truncatingIfNeeded source: T) where T : BinaryInteger {
        self.init(source)
    }
    
    public init?<T>(exactly source: T) where T : BinaryInteger {
        guard source.bitWidth <= Self.bitWidth else { return nil }
        self.init(source)
    }
    
    public init?<T>(exactly source: T) where T : BinaryFloatingPoint {
        guard (source - source.rounded()).isZero else { return nil }
        self.init(source)
    }
    
    public init<T>(_ source: T) where T : BinaryFloatingPoint {
        let x = UInt64(source.rounded())
        self.init(high: 0, low: x)
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
        try container.encode(value.high, forKey: .highWord)
        try container.encode(value.low, forKey: .lowWord)
    }
}

extension UInt128 : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value.high)
        hasher.combine(value.low)
    }
}

extension UInt128 : ExpressibleByIntegerLiteral {
    
#if canImport(StaticBigInt)
    public init(integerLiteral value: StaticBigInt) {
        precondition(value.signum() >= 0 && value.bitWidth <= 1 + Self.bitWidth, "Integer overflow: '\(value)' as '\(Self.self)'")
        self.init(high: UInt64(value[1]), low: UInt64(value[0]))
    }
#else
    public init(integerLiteral value: UInt) {
        self.init(high: 0, low: UInt64(value))
    }
#endif
    
}

extension UInt128 : Comparable, Equatable {
    
    static public func < (lhs: UInt128, rhs: UInt128) -> Bool {
        if lhs.value.high == rhs.value.high {
            return lhs.value.low < rhs.value.low
        }
        return lhs.value.high < lhs.value.high
    }
    
    static public func == (lhs: UInt128, rhs: UInt128) -> Bool {
        lhs.value.low == rhs.value.low && lhs.value.high == rhs.value.high
    }
    
}

extension UInt128 : CustomStringConvertible {
    
    /// Divides a UInt128 by 10×10¹⁸ and returns the quotient and remainder
    private static func divOneTo18 (x: UInt128) -> (q:UInt128, r:Int) {
        let oneTo18 = UInt64(10_000_000_000_000_000_000)
        let result = divRem(lhs: x, rhs: UInt128(high: 0, low: oneTo18))
        return (result.div, Int(result.rem.value.low))
    }
    
    public var description: String {
        var result = Self.divOneTo18(x: self)
        var str = String(result.r)
        while result.q != 0 {
            result = Self.divOneTo18(x: result.q)
            str = String(result.r) + str
        }
        return str
    }
}

extension UInt128 : ExpressibleByStringLiteral {
    
    static var powers = [UInt64]()  /* powers of 10 from 10 to 10_000_000_000_000_000_000 */
    
    /// Multiplies a UInt128 by 1×10ⁿ and returns the product
    private static func timesOne(to n: Int, x: UInt128) -> UInt128 {
        // calculate the powers of 10 — you'll thank me later
        if powers.isEmpty {
            var x = UInt64(1)
            Self.powers.reserveCapacity(18)
            for _ in 1...18 {
                x *= 10
                powers.append(x)
            }
        }
        let oneToPower = Self.powers[n-1]
        let result = x * UInt128(high:0, low:oneToPower)
        return result
    }
    
    public init(stringLiteral value: String) {
        // Do our best to clean up the input string
        let spaces = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "_"))
        var s = value.components(separatedBy: spaces).joined()
        if s.hasPrefix("+") { s.removeFirst() }
        if s.hasPrefix("-") { self.init(); return }
        while s.hasPrefix("0") { s.removeFirst() }
        
        // Translate the string into a number
        var r = UInt128()
        while !s.isEmpty {
            // remove 18 digits at a time
            let chunk = s.prefix(18)
            let size = chunk.count; s.removeFirst(size)
            if let uint = UInt64(chunk) {
                if size != 0 {
                    r = Self.timesOne(to: size, x: r)
                }
                r += UInt128(high: 0, low: uint)
            }
        }
        self = r
    }
}

extension UInt128 : BinaryInteger {
    
    // MARK: - Type properties
    public static var isSigned: Bool { false }
    public static var max: UInt128 { self.init(high: UInt64.max, low: UInt64.max) }
    public static var min: UInt128 { self.init() }
    public static let bitWidth = UInt64.bitWidth * 2
    
    public typealias Words = [UInt]
    
    // MARK: - Instance properties
    public var words: Words { Array(value.low.words) + Array(value.high.words) }
    public var magnitude: UInt128 { self }
    public var bitWidth: Int { value.high.bitWidth + value.low.bitWidth }
    
    public var trailingZeroBitCount: Int {
        if value.low == 0 {
            if value.high == 0 { return bitWidth }
            else { return value.high.trailingZeroBitCount + value.low.bitWidth }
        }
        return value.low.trailingZeroBitCount
    }
    
    public var leadingZeroBitCount: Int {
        if value.high == 0 {
            return value.low.leadingZeroBitCount + value.high.bitWidth
        }
        return value.high.leadingZeroBitCount
    }
    
    // MARK: - Basic Mathematical Operations
    public static func + (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let result = lhs.addingReportingOverflow(rhs)
        assert(!result.overflow, "Overflow during addition!")
        return result.partialValue
    }
    
    public static func - (lhs: UInt128, rhs: UInt128) -> UInt128 {
        let result = lhs.subtractingReportingOverflow(rhs)
        assert(!result.overflow, "Unsigned subtraction resulted in negative result!")
        return result.partialValue
    }
    
    public static func * (lhs: UInt128, rhs: UInt128) -> UInt128 {
        // Multiplies the lhs by the rhs.value.low and reports overflow
        let result = lhs.multipliedReportingOverflow(by: rhs)
        assert(!result.overflow, "Multiplication resulted in overflow")
        return result.partialValue
    }
    
    public static func / (lhs: UInt128, rhs: UInt128) -> UInt128 {
        assert(rhs != 0, "Division by zero")
        if lhs.value.high < rhs.value.high { return 0 }
        if lhs.value.high == rhs.value.high && lhs.value.low < rhs.value.low { return 0 }
        let result = divRemAbs(Integer(lhs), w1: Integer(rhs))
        return UInt128(result.div.digit)
    }
    
    public static func % (lhs: UInt128, rhs: UInt128) -> UInt128 {
        assert(rhs != 0, "Modulo must be > 0")
        if lhs.value.high < rhs.value.high { return lhs }
        if lhs.value.high == rhs.value.high && lhs.value.low < rhs.value.low { return lhs }
        let result = divRemAbs(Integer(lhs), w1: Integer(rhs))
        return UInt128(result.rem.digit)
    }
    
    public static func divRem (lhs: UInt128, rhs: UInt128) -> (div: UInt128, rem: UInt128) {
        assert(rhs != 0, "Division/modulo by zero")
        if lhs.value.high == rhs.value.high && lhs.value.low < rhs.value.low { return (0, lhs) }
        if lhs.value.high == rhs.value.high && lhs.value.low < rhs.value.low { return (0, lhs) }
        let result = divRemAbs(Integer(lhs), w1: Integer(rhs))
        return (UInt128(result.div.digit), UInt128(result.rem.digit))
    }
    
    // MARK: - Helper functions for division and modulo
    
    private typealias Digit = UInt32
    private typealias TwoDigits = UInt64
    private static let shift : Digit = 31
    private static let base : Digit = 1 << shift
    private static let mask : Digit = base-1
    
    private struct Integer {
        var digit: [Digit]
        
        // Note: Each Integer word contains 31 bits so the
        // 128 bits must be broken into 5 words with the
        // upper word having 4 bits and all others 31.
        init(_ x:UInt128) {
            let mask  = TwoDigits(mask)
            var low   = TwoDigits(x.value.low)
            var high  = TwoDigits(x.value.high)
            let low1  = Digit(low & mask); low >>= shift
            let low2  = Digit(low & mask); low >>= shift
            let mid   = Digit(low) | (Digit(high & (mask >> 2)) << 2); high >>= shift-2
            let high1 = Digit(high & mask); high >>= shift
            let high2 = Digit(high)
            
            // quick normalization
            if high2 == 0 {
                if high1 == 0 {
                    if mid == 0 {
                        // Note: div algorithm needs at least two words
                        // so the upper word may be zero at this point
                        digit = [low1, low2]; return
                    }
                    digit = [low1, low2, mid]; return
                }
                digit = [low1, low2, mid, high1]; return
            }
            digit = [low1, low2, mid, high1, high2]
        }
        
        init(size: Int) {
            digit = [Digit](repeating: 0, count: size)
        }
    }
    
    private static func normalize(_ a: inout Integer) {
        let size = a.digit.count
        var i = size
        while i != 0 && a.digit[i-1] == 0 { i -= 1 }
        
        // remove leading zeros
        if i != size { a.digit.removeSubrange(i..<size) }
    }
    
    /// Multiply by a single digit *n* and add a single digit *add*, ignoring the sign.
    private static func mul(_ a: inout Integer, n: Digit) {
        let sizeA = a.digit.count
        var z = Integer(size: sizeA+1)
        var carry = TwoDigits(0)
        for i in 0..<sizeA {
            carry += TwoDigits(a.digit[i]) * TwoDigits(n)
            z.digit[i] = Digit(carry & TwoDigits(mask))
            carry >>= TwoDigits(shift)
        }
        z.digit[sizeA] = Digit(carry)
        normalize(&z)
        a = z
    }
    
    /// Divide *pin*, with *size* digits, by non-zero digit
    /// *n*, storing the quotient in *pout*, and returning the remainder.
    /// *pin[0]* and *pout[0]* point at the LSD.  It's OK for
    /// *pin=pout* on entry, which saves oodles of mallocs/frees in
    /// Integer format, but that should be done with great care since Integers are
    /// immutable.
    private static func inplaceDivRem1 (_ pout: inout [Digit], pin: [Digit], n: Digit) -> Digit {
        assert(n > 0 && n <= base, "\(#function): assertion failed")
        let psize = pin.count
        var rem: TwoDigits = 0
        for size in (0..<psize).reversed() {
            rem = (rem << TwoDigits(shift)) | TwoDigits(pin[size])
            let hi = rem / TwoDigits(n)
            pout[size] = Digit(hi)
            rem -= hi * TwoDigits(n)
        }
        return Digit(rem)
    } // InplaceDivRem1;
    
    /// Divide a long integer *a* by a digit *n*, returning both the quotient
    /// (as function result) and the remainder *rem*.
    /// The sign of *a* is ignored; *n* should not be zero.
    private static func divRem (_ a: Integer, n: Digit, rem: inout Digit) -> Integer {
        assert(n > 0 && n <= base, "\(#function): assertion failed")
        let size = a.digit.count
        var z = Integer(size: size)
        rem = inplaceDivRem1(&z.digit, pin:a.digit, n:n)
        normalize(&z)
        return z
    }
    
    /// Unsigned long division of `v1` divided by `w1` with remainder
    private static func divRemAbs (_ v1: Integer, w1: Integer) -> (div: Integer, rem: Integer) {
        let sizeW = w1.digit.count
        let d = Digit(TwoDigits(base) / TwoDigits(w1.digit[sizeW-1]+1))
        var v = v1, w = w1
        mul(&v, n:d)
        mul(&w, n:d)
        
        assert(v1.digit.count >= sizeW && sizeW > 1, "\(#function): assertion 1 failed")
        assert(sizeW == w.digit.count, "\(#function): assertion 2 failed")
        
        let sizeV = v.digit.count
        var a = Integer(size:sizeV-sizeW+1)
        var j = sizeV
        for k in (0..<a.digit.count).reversed() {
            let vj: TwoDigits = j >= sizeV ? 0 : TwoDigits(v.digit[j])
            let base = TwoDigits(base)
            let mask = TwoDigits(mask)
            let w1digit = TwoDigits(w.digit[sizeW-1])
            let w2digit = TwoDigits(w.digit[sizeW-2])
            let vdigit = TwoDigits(v.digit[j-1])
            var q = vj == w1digit ? mask : (vj*base + vdigit) / w1digit
            
            while w2digit*q > (vj*base + vdigit - q*w1digit)*base + TwoDigits(v.digit[j-2]) {
                q -= 1
            }
            
            var i = 0
            var carry: Int = 0
            while i < sizeW && i+k < sizeV {
                let z = TwoDigits(w.digit[i])*q
                let zz = TwoDigits(z / base)
                carry += Int(v.digit[i+k]) - Int(z) + Int(zz*base)
                v.digit[i+k] = Digit(carry & Int(mask))
                carry >>= shift
                carry -= Int(zz)
                i += 1
            }
            
            if i+k < sizeV {
                carry += Int(v.digit[i+k])
                v.digit[i+k] = 0
            }
            
            if carry == 0 {
                a.digit[k] = Digit(q)
            } else {
                assert(carry == -1, "\(#function): carry != -1")
                a.digit[k] = Digit(q-1)
                carry = 0
                for i in 0..<sizeW where i+k < sizeV {
                    carry += Int(v.digit[i+k] + w.digit[i])
                    v.digit[i+k] = Digit(carry & Int(mask))
                    carry >>= TwoDigits(shift)
                }
            }
            j -= 1
        }
        normalize(&a)
        var dx : Digit = 0
        let rem = divRem(v, n:d, rem:&dx)
        return (a, rem)
    } // DivRemAbs;
    
    // MARK: - Convenience math functions
    public static func /= (lhs: inout UInt128, rhs: UInt128) {
        lhs = lhs / rhs
    }
        
    public static func %= (lhs: inout UInt128, rhs: UInt128) {
        lhs = lhs % rhs
    }
    
    public static func *= (lhs: inout UInt128, rhs: UInt128) {
        lhs = lhs * rhs
    }
    
    // MARK: - Logical functions
    public static func &= (lhs: inout UInt128, rhs: UInt128) {
        lhs = UInt128(high: lhs.value.high & rhs.value.high,
                      low: lhs.value.low & rhs.value.low)
    }
    
    public static func |= (lhs: inout UInt128, rhs: UInt128) {
        lhs = UInt128(high: lhs.value.high | rhs.value.high,
                      low: lhs.value.low | rhs.value.low)
    }
    
    public static func ^= (lhs: inout UInt128, rhs: UInt128) {
        lhs = UInt128(high: lhs.value.high ^ rhs.value.high,
                      low: lhs.value.low ^ rhs.value.low)
    }
    
    public static prefix func ~ (x: UInt128) -> UInt128 {
        UInt128(high: ~x.value.high, low: ~x.value.low)
    }
    
    // MARK: - Shifting functions
    public static func >>= <RHS>(lhs: inout UInt128, rhs: RHS) where RHS : BinaryInteger {
        if RHS.isSigned && rhs.signum() < 0 { lhs <<= rhs.magnitude }
        if rhs >= Self.bitWidth { lhs = 0 }
        if rhs >= UInt64.bitWidth {
            lhs = UInt128(high: 0, low: lhs.value.high >> (Int(rhs)-UInt64.bitWidth))
        } else {
            let shiftOut = lhs.value.high << (UInt64.bitWidth-Int(rhs))
            let high = lhs.value.high >> rhs
            let low = lhs.value.low >> rhs | shiftOut
            lhs = UInt128(high: high, low: low)
        }
    }
    
    public static func <<= <RHS>(lhs: inout UInt128, rhs: RHS) where RHS : BinaryInteger {
        if RHS.isSigned && rhs.signum() < 0 { lhs >>= rhs.magnitude }
        if rhs >= Self.bitWidth { lhs = 0 }
        if rhs >= UInt64.bitWidth {
            lhs = UInt128(high: lhs.value.low << (Int(rhs)-UInt64.bitWidth), low: 0)
        } else {
            let shiftOut = lhs.value.low >> (UInt64.bitWidth-Int(rhs))
            let high = lhs.value.high << rhs | shiftOut
            let low = lhs.value.low << rhs
            lhs = UInt128(high: high, low: low)
        }
    }
}

extension UInt128 : UnsignedInteger { }

extension UInt128 : Numeric { }

extension UInt128 { // : FixedWidthInteger {
    
    public init(_truncatingBits bits: UInt) {
        self.init(bits)
    }
      
    public func addingReportingOverflow(_ rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        let lhs = self
        let resultLow = lhs.value.low.addingReportingOverflow(rhs.value.low)
        var resultHigh = lhs.value.high.addingReportingOverflow(rhs.value.high)
        if resultLow.overflow {
            resultHigh = resultHigh.partialValue.addingReportingOverflow(1)
        }
        return (UInt128(high: resultHigh.partialValue, low: resultLow.partialValue), resultHigh.overflow)
    }

    public func subtractingReportingOverflow(_ rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        let lhs = self
        if lhs.value.high == rhs.value.high {
            if lhs.value.low >= rhs.value.low {
                return (UInt128(high: 0, low: lhs.value.low - rhs.value.low), false)
            } else {
                return (0, true)
            }
        }
        if lhs.value.high > rhs.value.high {
            var high = lhs.value.high
            let low = lhs.value.low.subtractingReportingOverflow(rhs.value.low)
            if low.overflow { high -= 1 }
            return (UInt128(high: high - rhs.value.high, low: low.partialValue), false)
        } else {
            return (0, true)
        }
    }

    public func multipliedReportingOverflow(by rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
        let lhs = self
        let product = lhs.value.low.multipliedFullWidth(by: rhs.value.low)
        let productHigh = lhs.value.high.multipliedFullWidth(by: rhs.value.low)
        var overflow = productHigh.high != 0
        let c = product.high.addingReportingOverflow(productHigh.low)
        overflow = overflow || c.overflow
        let result = UInt128(high:c.partialValue, low: product.low)
        
        // Multiplies the lhs by the rhs.value.high and reports overflow
        let res = lhs.value.low.multipliedReportingOverflow(by: rhs.value.high)
        overflow = overflow || res.overflow
        let newHigh = result.value.high.addingReportingOverflow(res.partialValue)
        overflow = overflow || newHigh.overflow
        let res2 = lhs.value.high.multipliedReportingOverflow(by: rhs.value.high)
        overflow = overflow || (res2.overflow && res2.partialValue == 0)
        return (UInt128(high: newHigh.partialValue, low: result.value.low), overflow)
    }

//    public func dividedReportingOverflow(by rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
//        (self, false)  // FIXME: - Really
//    }
//
//    public func remainderReportingOverflow(dividingBy rhs: UInt128) -> (partialValue: UInt128, overflow: Bool) {
//        (self, false)  // FIXME: - Really
//    }
//
//    public func dividingFullWidth(_ dividend: (high: UInt128, low: UInt128)) -> (quotient: UInt128, remainder: UInt128) {
//        (self, 0)  // FIXME: - Really
//    }
    
    public var nonzeroBitCount: Int {
        value.high.nonzeroBitCount + value.low.nonzeroBitCount
    }
    
    public var byteSwapped: UInt128 {
        UInt128(high: value.low.byteSwapped, low: value.high.byteSwapped)
    }
    
}
