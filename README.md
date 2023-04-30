# UInt128/Int128

A 128-bit unsigned/signed integer implementation with optimized multiplication, division, and string conversions.
The user interface has been changed to be in sync with Apple's unreleased version of the UInt128/Int128.

This package is usually around ten times faster than other UInt128 implementations and roughly the same
speed as Apple's implementation. If you find something faster, please let me know.

This package is compliant with the following protocols:

1. UnsignedInteger
2. BinaryInteger
3. FixedWidthInteger
4. Numeric
4. AdditiveArithmetic
5. ExpressibleByIntegerLiteral
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

I will be adding support for the new StaticBigInt, once it is generally available.

## Installation
This library includes Swift Package support out of the box.
Reference this git repository via XCode to install as a Package.

You can also manually copy over the `Sources/UInt128.swift` file into your project
and it should work great. I've purposely kept this library constrained to a
single file in order to support this use case.

## Usage
Since this library fully implements the UnsignedInteger or SignedInteger protocol, 
you can use this data type just like any other native UInt data type. For numbers larger
than UIntMax, you'll either want to call the `init(high: UInt64, low: UInt64)` 
initializer, or, use the `init(_ source: String, radix: Int)` initializer to
create an instance with a string.  The string can be in any radix up to base 36
including binary, octal, decimal orr hexadecimal, by using a corresponding `radix` 
argument. Strings **cannot** contain spaces, underscores, or non-radix digits. Illegal 
input strings will return nil (previously they quietly returned 0).  Note: This is probably confusing
to newbies who may want to use underscores to separate digit groups as they
can do with literal integers (e.g., 123\_456).

For example:

    let uInt128ByString = UInt128("ffaabbcc00129823fa9a12d4aa87f498", radix:16)!
    let uInt128ByInteger: UInt128 = 1234
    
The `Int128.swift.gyb` file is the source for the generated file `UInt128.swift` (containing
both `Int128` and `UInt128` number types). If you would like to contribute to this
project, please make changes in the .gyb file and remember to include signed and
unsigned variants of the changes. The source files are automagically generated using a gyb tool
invocation like:

```
/utils/gyb -D CMAKE_SIZEOF_VOID_P=8 --line-directive '' /Users/.../Int128.swift.gyb -o/Users/.../UInt128.swift
```

The `...` represents the detailed file path to get to your .gyb and output files.
The gyb tool is available from Apple.

## Testing
Some tests are included (many from Joel Gerber's great UInt128 implementation)
to verify that the source files are intact and working correctly.  Please
let me know of any testing failures. Please forward to me any new tests that
you decide to add.

