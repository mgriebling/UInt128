# ``UInt128``

A 128-bit unsigned/signed integer implementation with optimized multiplication, division, and string conversions.
The user interface has been changed to be in sync with Apple's new UInt128/Int128 data types.

If you're working with macOS 15.0+, iOS 18.0+, or tvOS 18.0+, you won't need
this package any more because Int128/UInt128 are built into those OSes.  Just
remove the imports of this package and you should be good.  If you use the
internals of this package (low, high) and init(low, high), these will need
to have underscores prefixed on the arguments. Apple does this to indicate internal variables
and methods that you shouldn't use unless you know what you're doing.

This package is usually around ten times faster than other UInt128 implementations and roughly the same
speed as Apple's implementation. If you find something faster, please let me know.

The `UInt128` package name is a bit of a misnomer since it actually includes 
two datatypes:

1. ``UInt128`` which is an unsigned 128-bit integer type, and
2. ``Int128`` which is a signed 128-bit integer type.

## Details

### Protocol Support

These integer types are compliant with the following protocols:

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

### Usage
Since this library fully implements the UnsignedInteger or SignedInteger protocols, 
you can use these data types just like any other native integer data type. For numbers larger
than `UInt.max`, you can enter numbers directly as literals (see example).  If you prefer,
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

### Testing
Some tests are included (many from Joel Gerber's great UInt128 implementation)
to verify that the source files are intact and working correctly.  Please
let me know of any testing failures. Please forward to me any new tests that
you decide to add.

