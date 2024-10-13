[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmgriebling%2FUInt128%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/mgriebling/UInt128)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fmgriebling%2FUInt128%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/mgriebling/UInt128)

# UInt128/Int128

A 128-bit unsigned/signed integer implementation with optimized multiplication, division, and string conversions.
The user interface has been changed to be in sync with Apple's unreleased version of the UInt128/Int128.

This package is usually around ten times faster than other UInt128 implementations and roughly the same
speed as Apple's implementation. If you find something faster, please let me know.

This package now supports `StaticBigInt`. Unfortunately, this means you need
to have one of following configurations (or higher) 

1. macOS 13.3+, 
2. iOS 16.4+, 
3. macCatalyst 16.4+, 
4. tvOS 16.4+,
5. watchOS 9.4+

If you don't have these configurations, you need to use a previous release of
UInt128/Int128.

## Installation
This library includes Swift Package support out of the box.
Reference this git repository via XCode to install as a Package.

You can also manually copy over the `Sources/(U)Int128.swift` files into your project
and it should work great. This file split duplicates Apple's UInt128 and Int128
files. Note: Some common utilities are located in the Int128.swift file.

## Documentation

Please refer to https://mgriebling.github.io/UInt128/documentation/uint128
for the documentation.


