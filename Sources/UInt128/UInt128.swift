import Foundation

public struct UInt128 : Sendable {
    
    /// Internal data representation - pretty simple
    static let bitWidth = UInt64.bitWidth * 2
    
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
        // Divide by 10
        let oneTo18 = UInt64(10_000_000_000_000_000_000)
        let result = oneTo18.dividingFullWidth((x.value.high, x.value.low))
        return (UInt128(high: 0, low: result.quotient), Int(result.remainder))
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
        let resultLow = lhs.value.low.addingReportingOverflow(rhs.value.low)
        var resultHigh = lhs.value.high.addingReportingOverflow(rhs.value.high)
        if resultLow.overflow {
            resultHigh = resultHigh.partialValue.addingReportingOverflow(1)
        }
        assert(!resultHigh.overflow, "Overflow during UInt128 addition!")
        return UInt128(high: resultHigh.partialValue, low: resultLow.partialValue)
    }
    
    public static func - (lhs: UInt128, rhs: UInt128) -> UInt128 {
        if lhs.value.high == rhs.value.high {
            if lhs.value.low >= rhs.value.low {
                return UInt128(high: 0, low: lhs.value.low - rhs.value.low)
            } else {
                assertionFailure("UInt128 subtraction resulted in negative result!")
            }
        }
        if lhs.value.high > rhs.value.high {
            var high = lhs.value.high
            let low = lhs.value.low.subtractingReportingOverflow(rhs.value.low)
            if low.overflow { high -= 1 }
            return UInt128(high: high - rhs.value.high, low: low.partialValue)
        } else {
            assertionFailure("UInt128 subtraction resulted in negative result!")
            return 0
        }
    }
    
    public static func * (lhs: UInt128, rhs: UInt128) -> UInt128 {
        // Multiplies the lhs by the rhs.value.low and reports overflow
        let overflowMessage = "UInt128 multiplication resulted in overflow"
        let product = lhs.value.low.multipliedFullWidth(by: rhs.value.low)
        let productHigh = lhs.value.high.multipliedFullWidth(by: rhs.value.low)
        assert(productHigh.high == 0, overflowMessage)
        let c = product.high.addingReportingOverflow(productHigh.low)
        assert(!c.overflow, overflowMessage)
        let result = UInt128(high:c.partialValue, low: product.low)
        
        // Multiplies the lhs by the rhs.value.high and reports overflow
        let res = lhs.value.low.multipliedReportingOverflow(by: rhs.value.high)
        assert(!res.overflow, overflowMessage)
        assert(lhs.value.high == 0 && rhs.value.high == 0, overflowMessage)
        let newHigh = result.value.high.addingReportingOverflow(res.partialValue)
        assert(!newHigh.overflow, overflowMessage)
        return UInt128(high: newHigh.partialValue, low: result.value.low)
    }
    
    public static func / (lhs: UInt128, rhs: UInt128) -> UInt128 {
        assert(rhs != 0, "Division by zero")
        if lhs.value.high < rhs.value.high { return 0 }
        if lhs.value.high == rhs.value.high && lhs.value.low < rhs.value.low { return 0 }
        
        // Check if the single-word division will generate an overflow
        let size1 = rhs.value.low.bitWidth - rhs.value.low.leadingZeroBitCount
        let size2 = lhs.bitWidth - lhs.leadingZeroBitCount
        
        // Single-word division if no overflow will occur
        if rhs.value.high == 0 && size2 - size1 <= UInt64.bitWidth {
            let res = rhs.value.low.dividingFullWidth(lhs.value)
            return UInt128(high: 0, low: res.quotient)
        }

        // Handle multi-word division
        if rhs.value.high == 0 {
            // increase divisor until overflow cannot occur - we'll fix this later
            let correction = size2 - size1 - UInt64.bitWidth + 10
            let newDivisor = rhs.value.low << correction
            let res = newDivisor.dividingFullWidth(lhs.value)
            let corrected = res.quotient >> correction
            let remainder = res.remainder >> correction
            return UInt128(high: res.quotient >> (UInt64.bitWidth-correction), low: res.quotient &<< correction)
        } else {
            // First an approximation of the quotient
            let res = rhs.value.high.dividingFullWidth(lhs.value)
            // let res2 = rhs.value.low.dividingFullWidth((lhs.value.high, lhs.value.low))
            return UInt128(high: 0, low: res.quotient)
        }
    }
    
    public static func % (lhs: UInt128, rhs: UInt128) -> UInt128 {
        lhs
    }
    
    public static func /= (lhs: inout UInt128, rhs: UInt128) {
        lhs = lhs / rhs
    }
        
    public static func %= (lhs: inout UInt128, rhs: UInt128) {
        lhs = lhs % rhs
    }
    
    public static func *= (lhs: inout UInt128, rhs: UInt128) {
        lhs = lhs * rhs
    }
    
    public static func &= (lhs: inout UInt128, rhs: UInt128) {
        lhs = UInt128(high: lhs.value.high & rhs.value.high, low: lhs.value.low & rhs.value.low)
    }
    
    public static func |= (lhs: inout UInt128, rhs: UInt128) {
        lhs = UInt128(high: lhs.value.high | rhs.value.high, low: lhs.value.low | rhs.value.low)
    }
    
    public static func ^= (lhs: inout UInt128, rhs: UInt128) {
        lhs = UInt128(high: lhs.value.high ^ rhs.value.high, low: lhs.value.low ^ rhs.value.low)
    }
    
    public static prefix func ~ (x: UInt128) -> UInt128 {
        UInt128(high: ~x.value.high, low: ~x.value.low)
    }
    
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
