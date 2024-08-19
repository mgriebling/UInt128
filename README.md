# UInt128/Int128

A 128-bit unsigned/signed integer implementation with optimized multiplication, division, and string conversions.
The user interface has been changed to be in sync with Apple's unreleased version of the UInt128/Int128.

This package is usually around ten times faster than other UInt128 implementations and roughly the same
speed as Apple's implementation. If you find something faster, please let me know.

This package is compliant with the following protocols:

1. UnsignedInteger/SignedInteger
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

This package now supports `StaticBigInt`. Unfortunately, this means you need
to have one of following configurations (or higher) 

1. macOS 13.3+, 
2. iOS 16.4+, 
3. macCatalyst 16.4+, 
4. tvOS 16.4+,
5. watchOS 9.4+

If you don't have these configurations, you need to use a previous release of
UInt128/Int128.

If you're working with macOS 15.0+, iOS 18.0+, or tvOS 18.0+, you won't need
this package any more because Int128/UInt128 are built into the OS.  Just
remove the imports of this package and you should be good.  If you use the
internals of this package (low, high) and init(low, high), these will need
to have underscores prefixed on the arguments.  Apple does this to indicate internal variables
and methods that you shouldn't use unless you know what you're doing.

## Installation
This library includes Swift Package support out of the box.
Reference this git repository via XCode to install as a Package.

You can also manually copy over the `Sources/(U)Int128.swift` files into your project
and it should work great. This file split duplicates Apple's UInt128 and Int128
files. Note: Some common utilities are located in the Int128.swift file.

## Usage
Since this library fully implements the UnsignedInteger or SignedInteger protocol, 
you can use this data type just like any other native UInt data type. For numbers larger
than UIntMax, you can enter numbers directly as literals (see example).  If you prefer,
the `init(high: UInt64, low: UInt64)`, or the `init(_ source: String, radix: Int)` initializers
can also be used to create a UInt128/Int128. A string can be in any radix up to base 36
including binary, octal, decimal or hexadecimal, by using a corresponding `radix` 
argument. Strings **cannot** contain spaces, underscores, or non-radix digits. Illegal 
input strings will return nil (previously they quietly returned 0).  Note: This is probably confusing
to newbies who may want to use underscores to separate digit groups as they
can do with literal integers (e.g., 123\_456), but it is the *Apple way*.
Fortunately, with big literal number support (aka `StaticBigInt`), you never
need to use string initializers again, unless you need oddball radices.

For example:
```Swift
  let uInt128ByString = UInt128("ffaabbcc00129823fa9a12d4aa87f498", radix:16)!
  let uInt128ByLiteral: UInt128 = 0xffaa_bbcc_0012_9823_fa9a_12d4_aa87_f498
  let uInt128ByInteger: UInt128 = 1234
```
    
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

