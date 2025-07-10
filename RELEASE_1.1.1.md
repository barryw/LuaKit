# LuaKit 1.1.1+lua5.4.8: Critical Array Access Fix

## 🐛 Critical Bug Fix

This release fixes a critical issue that prevented the array element access feature (introduced in 1.1.0) from working for consumers of the LuaKit package.

### The Issue
In version 1.1.0, array element access (`palette.colors[1] = "red"`) would fail with:
```
'LuaStringArrayProxy' initializer is inaccessible due to 'internal' protection level
```

### The Fix
- Changed `LuaArrayProxy` initializer from `internal` to `public`
- Array element access now works correctly for all package consumers

### Why Tests Didn't Catch This
- Our tests used `@testable import LuaKit` which provides access to internal members
- The bug only manifested when using LuaKit as a normal dependency

## 🧪 New Testing Infrastructure

Added a dedicated public API test target that imports LuaKit without `@testable` to catch these issues in the future.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit", from: "1.1.1")
]
```

## Upgrading from 1.1.0

Simply update your package dependency. No code changes required - the array element access feature will now work as documented.

## Full Changelog
See [CHANGELOG.md](https://github.com/barryw/LuaKit/blob/main/CHANGELOG.md) for complete details.