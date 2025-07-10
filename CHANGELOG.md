# LuaKit Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1+lua5.4.8] - 2025-07-10

### Fixed
- Fixed array proxy initializer access level that prevented consumers from using array element access
- Array element access now works correctly when using LuaKit as an external dependency

### Added
- Public API test target to ensure public APIs are accessible to consumers
- Tests that verify array element access works without @testable import

## [1.1.0+lua5.4.8] - 2025-07-10

### Added
- Full array support for primitive types (`[String]`, `[Int]`, `[Double]`, `[Bool]`)
- Individual array element access from Lua (e.g., `palette.colors[1] = "red"`)
- Array proxy implementation with Lua metamethods (__index, __newindex, __len, __ipairs, __tostring)
- Comprehensive array tests and examples
- ArrayExample.swift demonstrating array usage patterns

### Changed
- Switched to semantic versioning with Lua version as build metadata
- Updated documentation to reflect new versioning scheme
- Array properties now return proxies instead of direct arrays for element-level access

## [5.4.8] - 2025-07-09

### Changed
- Upgraded embedded Lua from 5.4.7 to 5.4.8
- Updated all documentation to reflect new Lua version

### Added
- Property validation now uses Result pattern with custom error messages
- Added PropertyValidationError type for descriptive validation failures

## [5.4.7] - Initial Release

### Added
- Initial release with Lua 5.4.7 embedded
- @LuaBridgeable macro for automatic Swift-Lua bridging
- Property change notifications (luaPropertyWillChange/luaPropertyDidChange)
- Global variable access with subscript syntax
- Table creation and manipulation
- Comprehensive error handling
- Print output capture