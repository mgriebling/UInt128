# UInt128

A 128-bit unsigned integer implementation with optimized multiplication, division, and string conversions.
This package supports the new **StaticBigInt** on macOS 13.3+ or iOS 16.4+. Please see FIXME in the source
since there seems to be no way to fake support for StaticBigInt on lower OS versions without resorting to
commenting out alternate ExpressibleByIntegerLiteral implementations. 
I **really** tried to get this to work automagically — but failed.

This package is usually at least ten times faster than other UInt128 implementations.
If you find something faster, please let me know.

This package is compliant with the following protocols:

1. UnsignedInteger
2. BinaryInteger
3. FixedWidthInteger
4. Numeric
4. AdditiveArithmetic
9. Plottable (for Charts)
5. ExpressibleByIntegerLiteral (with StaticBigInt support)
6. ExpressibleByStringLiteral
6. LosslessStringConvertible
7. CustomStringConvertible
7. CustomDebugStringConvertible
8. Comparable
9. Equatable
9. Strideable
10. Hashable
11. Sendable
12. Codable

## Installation
This library includes Swift Package support out of the box.
Reference this git repository via XCode to install as a Package.

You can also manually copy over the `Sources/UInt128.swift` file into your project
and it should work great. I've purposely kept this library constrained to a
single file in order to support this use case.

## Usage
Since this library fully implements the UnsignedInteger protocol, you can use
this data type just like any other native UInt data type. For numbers larger
than UIntMax, you'll either want to call the `init(high: UInt64, low: UInt64)` 
initializer, or, use the `init(_ source: String)` initializer to
create an instance with a string.  The string can be in binary, octal, decimal
or hexadecimal.  Alternatively, with the correct OS, you can use the `StaticBigInt`
initializer. If the `StaticBigInt` initializer is not supported on your OS, you
can also use standard integers to initialize `UInt128` variables just like any
other integers.

For example:

    let uInt128ByString = UInt128("0xffaabbcc00129823fa9a12d4aa87f498")!
    let uInt128ByInteger: UInt128 = 1234
    let uInt128ByStaticBigInt : UInt128 = 123456789012345678901234567890

## Testing
Some tests are included (many from Joel Gerber's great UInt128 implementation)
to verify that the source files are intact and working correctly.  Please
let me know of any testing failures.  Some tests are commented out since
they are no longer applicable to the current Swift versions.

