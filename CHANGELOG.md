# LuaKit Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.0+lua5.4.8] - 2025-07-12

### Added
- Enhanced README with professional header, badges, and custom logo
- Lua credits section with official Lua logo
- CLAUDE.md documentation for AI assistant context
- GitHub Actions permission fixes for automated releases

### Fixed
- Swift compilation errors in LuaGlobalRegistration.swift
- Coverage profdata path issues in CI/CD pipeline
- GitHub Actions tag creation permissions
- @LuaBridgeable macro now recognizes internal visibility (not just public)

### Changed
- Improved CI/CD pipeline with architecture detection
- Enhanced error handling for coverage data collection

## [1.3.0+lua5.4.8] - 2025-07-12

### Added
Major enhancement release with 15 new features for advanced Swift-Lua bridging:

#### Advanced Bridging Features
- Method return type variants with `@LuaReturnVariant`
- Collection syntax support (`collection[method](args)`)
- Async/await integration with `@LuaAsync`
- Aliasing support with `@LuaAlias`
- Factory methods with `@LuaFactory`
- Chainable methods with `@LuaChainable`
- Type converters with `@LuaConvert`
- Namespacing with `@LuaNamespace`
- Relationships with `@LuaRelationship`

#### Developer Experience
- Documentation with `@LuaDoc` and `@LuaParam`
- Property validation with custom validators
- Global function registration
- Enhanced error messages with suggestions
- Debug helpers for runtime inspection

### Fixed
- Critical EXC_BAD_ACCESS crash in LuaFunction closure handling
- Memory management improvements
- Enhanced macro error handling

## [1.2.1+lua5.4.8] - 2025-07-12

### Fixed
- Critical crash in LuaFunction closure bridging
- Improved memory management for closure retention
- Enhanced error context system

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