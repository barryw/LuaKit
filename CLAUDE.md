# LuaKit - Claude AI Assistant Documentation

This document provides essential information for Claude AI instances working on the LuaKit project. LuaKit is a Swift framework for embedding Lua scripting into iOS and macOS applications with seamless Swift-Lua bridging.

## Project Overview

**LuaKit v1.3.0** - A Swift framework that:
- Embeds Lua 5.4.8 directly (no external dependencies)
- Provides seamless Swift-Lua bridging via the `@LuaBridgeable` macro
- Supports iOS 13+, macOS 10.15+, tvOS 13+, watchOS 6+
- Features AI-powered semantic versioning via Claude API integration

## Critical Build and Test Commands

### Before Committing Any Code
**ALWAYS** run these commands before committing:

```bash
# 1. Run SwiftLint to check for style violations
swiftlint

# 2. Build the project
swift build --configuration release

# 3. Run tests (note: may timeout due to SwiftSyntax compilation)
swift test --configuration release --parallel
```

### Platform-Specific Builds
```bash
# macOS (primary platform)
swift build --configuration release

# iOS (if simulators available)
xcodebuild -scheme LuaKit -destination 'generic/platform=iOS' -configuration Release build
```

## Project Structure

```
LuaKit/
├── Sources/
│   ├── Lua/              # Embedded Lua 5.4.8 C source
│   ├── LuaKit/           # Main Swift framework
│   │   ├── LuaBridgeable/    # Core bridging protocols
│   │   └── ...
│   └── LuaMacros/        # Swift macro implementations
├── Tests/
│   ├── LuaKitTests/      # Unit tests
│   └── LuaKitPublicAPITests/  # Public API tests
├── .github/
│   ├── workflows/        # CI/CD pipelines
│   └── scripts/          # AI version analysis scripts
└── Package.swift         # SPM configuration
```

## Known Issues and Workarounds

### 1. SwiftSyntax Compilation Timeout
- **Issue**: `swift test` may timeout during SwiftSyntax compilation
- **Workaround**: Test individual components or use Xcode for testing
- **Status**: Ongoing issue affecting full test suite execution

### 2. Disabled Tests (CRITICAL)
The following test files are currently disabled due to @LuaBridgeable macro issues:
- `PropertyChangeTests.swift.disabled`
- `MacroTests.swift.disabled` 
- `ArrayPropertyTests.swift.disabled`
- `ArrayElementAccessTests.swift.disabled`
- `ArrayProxyPublicAPITest.swift.disabled`
- `LuaIgnoreTest.swift.disabled`

**Root Cause**: The @LuaBridgeable macro was only recognizing `public` members, not `internal` (Swift's default). This has been fixed in the macro implementation but tests need re-enabling.

### 3. SwiftLint Configuration
- Complex files excluded from cyclomatic complexity checks:
  - `Sources/LuaKit/LuaArrayProxy.swift`
  - `Sources/LuaMacros/LuaMacrosPlugin.swift`

## Architecture and Key Components

### 1. Core Classes
- **LuaState**: Main entry point for Lua interaction
- **LuaValue**: Type-safe wrapper for Lua values
- **LuaBridgeable**: Protocol for Swift-Lua bridging

### 2. @LuaBridgeable Macro
**Important Usage Requirements**:
1. Import `Lua` in your file (required for generated code)
2. Manually add `: LuaBridgeable` conformance
3. The macro generates required bridging methods

Example:
```swift
import Foundation
import Lua  // Required!
import LuaKit

@LuaBridgeable
public class MyClass: LuaBridgeable {  // Must explicitly conform
    public var name: String
    // ...
}
```

### 3. Property Change Notifications
Classes can implement optional methods to track property changes:
- `luaPropertyWillChange(property:oldValue:newValue:)`
- `luaPropertyDidChange(property:from:to:)`

### 4. Array Bridging
Supports bridging of Swift arrays to Lua:
- `[String]`, `[Int]`, `[Double]`, `[Bool]`
- Uses `LuaArrayProxy` for transparent access

## CI/CD Pipeline

### GitHub Actions Workflow
1. **Build and Test**: Multi-platform builds, unit tests, coverage
2. **Lint and Format**: SwiftLint enforcement
3. **Security Scan**: Dependency and secret scanning
4. **Auto Release**: AI-powered version analysis and release

### AI Version Management
- Uses Claude API to analyze commits and determine version bumps
- Format: `x.x.x+luax.x.x` (e.g., `1.3.0+lua5.4.8`)
- Semantic versioning based on change analysis

## Development Guidelines

### 1. Testing Requirements
- Run tests before committing: `swift test --configuration release --parallel`
- Verify SwiftLint compliance: `swiftlint`
- Check multi-platform builds if making platform-specific changes

### 2. Code Style
- Follow existing patterns in the codebase
- Use SwiftLint rules defined in `.swiftlint.yml`
- Maintain consistent naming conventions

### 3. Macro Development
When modifying `@LuaBridgeable` macro:
1. Update `Sources/LuaMacros/LuaMacrosPlugin.swift`
2. Test with both `public` and `internal` visibility
3. Verify property and method bridging
4. Check array property support

### 4. Error Handling
- Use `LuaError` for Lua-specific errors
- Provide descriptive error messages
- Include context for debugging

## Common Tasks

### Adding New Bridgeable Types
1. Create class with `@LuaBridgeable` macro
2. Add `: LuaBridgeable` conformance
3. Import `Lua` for generated code
4. Test bridging functionality

### Debugging Lua Errors
1. Check `LuaError` for detailed messages
2. Use `lua.globals["_G"]` to inspect global state
3. Enable debug mode for additional logging

### Updating Lua Version
1. Update Lua sources in `Sources/Lua/`
2. Update version in documentation
3. Test compatibility thoroughly
4. Update version format in releases

## Important Constants

- `luaRegistryIndex`: -1,001,000 (was LUA_REGISTRYINDEX, renamed for SwiftLint)
- Lua type constants: `LUA_TNIL`, `LUA_TBOOLEAN`, etc.

## Security Considerations

- Never expose raw Lua state pointers
- Validate all inputs from Lua
- Use type-safe wrappers
- Implement proper sandboxing for untrusted scripts

## Troubleshooting

### Build Failures
1. Clean build folder: `swift package clean`
2. Reset package cache: `swift package reset`
3. Check Xcode version compatibility

### Test Failures
1. Check for SwiftSyntax timeout issues
2. Verify @LuaBridgeable macro generation
3. Review property visibility (public/internal)
4. Check for platform-specific issues

### Macro Issues
1. Ensure `import Lua` is present
2. Verify explicit `: LuaBridgeable` conformance
3. Check property/method visibility
4. Review generated code in build logs

## Contact and Resources

- GitHub: https://github.com/barryw/LuaKit
- Swift Package Index: [if available]
- Documentation: See README.md for usage examples

## Version History

- v1.3.0: Added 15 major enhancements, AI-powered versioning
- v1.2.1: Fixed EXC_BAD_ACCESS crash
- v1.2.0: Enhanced @LuaBridgeable macro capabilities
- v1.1.0: Added array bridging support
- v1.0.0: Initial release

---
Last Updated: 2025-07-12