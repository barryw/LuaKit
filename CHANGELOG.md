# LuaKit Changelog

All notable changes to this project will be documented in this file.

## [5.4.8] - 2025-07-09

### Changed
- Upgraded embedded Lua from 5.4.7 to 5.4.8
- Updated all documentation to reflect new Lua version

### Added
- Property validation now uses Result pattern with custom error messages
- Added PropertyValidationError type for descriptive validation failures

## [5.4.7] - Previous Release

### Added
- Initial release with Lua 5.4.7 embedded
- @LuaBridgeable macro for automatic Swift-Lua bridging
- Property change notifications (luaPropertyWillChange/luaPropertyDidChange)
- Global variable access with subscript syntax
- Table creation and manipulation
- Comprehensive error handling
- Print output capture