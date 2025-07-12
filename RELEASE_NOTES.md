# LuaKit 1.3.0+lua5.4.8

Swift framework for embedding Lua scripting into iOS and macOS applications with powerful macro support.

## 🎉 What's New in 1.3.0

This release delivers **15 major enhancements** that dramatically improve the Swift-Lua bridging experience. These features were implemented based on user feedback to make LuaKit more powerful and developer-friendly.

### Major Enhancements

1. **Support for Methods Returning Different Types** - Methods can now return any type, not just the class type
2. **Collection/Array Method Syntax** - `@LuaCollection` attribute auto-generates collection management methods
3. **Method Aliases** - `@LuaAlias` attribute for backward compatibility and convenience
4. **Automatic Factory Methods** - `@LuaFactory` attribute for factory method pattern
5. **Property Validation Attributes** - `@LuaProperty` with min/max ranges, regex patterns, and custom validators
6. **Automatic Enum Bridging** - Enums conforming to `LuaEnumBridgeable` are automatically bridged
7. **Relationship Annotations** - `@LuaRelationship` for defining object relationships with cascade support
8. **Global Function Registration** - Type-safe `registerGlobal` and namespace support
9. **Async/Await Support** - `@LuaAsync` attribute bridges async Swift methods to Lua callbacks
10. **Debug Helpers** - `@LuaBridgeable(debug: true)` for comprehensive logging and performance tracking
11. **Documentation Attributes** - `@LuaDoc` and `@LuaParam` for API documentation
12. **Method Chaining Support** - `@LuaChainable` for fluent interfaces
13. **Type Conversion Helpers** - Automatic conversion for Date, URL, UUID, Data, and custom types
14. **Namespace Support** - `@LuaNamespace` for organizing APIs
15. **Better Error Messages** - Detailed error context with parameter names and helpful hints

### Quick Examples

#### Different Return Types (#1)
```swift
@LuaBridgeable
public class Project: LuaBridgeable {
    public func getImages() -> [Image] { }        // Returns array
    public func findImage(name: String) -> Image? { } // Returns optional
    public func getImageCount() -> Int { }        // Returns Int
    public func hasImages() -> Bool { }           // Returns Bool
    public func getCreationDate() -> Date { }     // Returns Date
}
```

#### Property Validation (#5)
```swift
@LuaBridgeable
public class ValidatedImage: LuaBridgeable {
    @LuaProperty(readOnly: true)
    public let id: UUID = UUID()
    
    @LuaProperty(min: 1, max: 320)
    public var width: Int
    
    @LuaProperty(regex: "^#[0-9A-Fa-f]{6}$")
    public var backgroundColor: String = "#000000"
}
```

#### Enum Bridging (#6)
```swift
public enum ImageType: String, CaseIterable, LuaEnumBridgeable {
    case sprite, bitmap, vector
}

lua.registerEnum(ImageType.self)
// In Lua: img.type = ImageType.sprite
```

#### Async Support (#9)
```swift
@LuaBridgeable
public class AsyncOps: LuaBridgeable {
    @LuaAsync
    public func loadImage(url: String) async throws -> Image { }
}

// In Lua:
// async:loadImage(url, function(image, error) ... end)
```

#### Better Error Messages (#15)
```
Error: Invalid argument #1 to 'Image:drawLine'
Expected: integer
Got: string ("not a number")
Parameter 'x1'
Hint: Ensure all coordinates are numeric values
```

### New APIs

- `LuaState.registerEnum()` - Register enum types
- `LuaState.registerGlobal()` - Register global values and functions
- `LuaState.registerNamespace()` - Create namespaces
- `LuaState.setDebugMode()` - Enable debug logging
- `LuaState.registerAsyncSupport()` - Enable async/await bridge

### New Protocols

- `LuaEnumBridgeable` - For automatic enum bridging
- `LuaPropertyValidator` - For custom property validation
- `LuaDebuggable` - For debug-enabled types

### 📚 Documentation

See [ENHANCEMENTS.md](ENHANCEMENTS.md) for comprehensive documentation of all new features.

---

## Previous Releases

### Version 1.2.1 (2025-01-12)

#### Critical Bug Fixes
- Fixed EXC_BAD_ACCESS crash in closure bridging
- Fixed memory management issues causing "Function no longer exists" errors
- Improved type checking order to prevent runtime crashes

#### Closure Bridging (Stable)
- Pass Swift closures to Lua as callable functions
- Support for closures with 0-3 parameters
- Automatic type conversion for parameters and return values
- Return LuaBridgeable objects from closures to Lua
- Convenient `registerFunction` methods for global function registration

#### Property Change Notifications
- Added `luaPropertyWillChange` and `luaPropertyDidChange` methods to LuaBridgeable protocol
- Track property modifications from Lua for persistence, logging, or debugging
- Validate and reject property changes with custom error messages using Result type
- Default implementations ensure backward compatibility

#### Array Support
- Full support for array properties: `[String]`, `[Int]`, `[Double]`, `[Bool]`
- Seamless Swift-Lua array bridging with automatic type conversion
- Individual array element access from Lua (e.g., `palette.colors[1] = "red"`)
- Array proxy implementation with full Lua metamethod support
- Respects Lua's 1-based indexing conventions

#### Embedded Lua
- Lua 5.4.8 is now embedded directly in LuaKit
- No external dependencies required
- Simplified installation and distribution

## 🎯 Key Features

### @LuaBridgeable Macro
- **Automatic Code Generation**: Save ~100 lines of boilerplate per class
- **Flexible Control**: Use `@LuaIgnore` to exclude specific members
- **Explicit Mode**: Use `@LuaOnly` for fine-grained control
- **Type Safety**: Automatic Swift-Lua type conversions
- **Debug Mode**: `@LuaBridgeable(debug: true)` for detailed logging

### Core Functionality
- **Swift-Lua Bridging**: Seamlessly expose Swift classes to Lua
- **Property Change Notifications**: Track and validate property changes from Lua
- **Global Variables**: Easy access with Swift subscript syntax
- **Tables**: Create and manipulate Lua tables from Swift
- **Error Handling**: Comprehensive error reporting with detailed context
- **Print Capture**: Capture Lua print output in Swift
- **Embedded Lua**: Lua 5.4.8 embedded directly, no external dependencies

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit", from: "1.3.0")
]
```

## 🚀 Quick Start

```swift
import Lua  // Required for @LuaBridgeable
import LuaKit

@LuaBridgeable(debug: true)
class Image: LuaBridgeable {
    @LuaProperty(min: 1, max: 4096)
    public var width: Int
    
    @LuaProperty(min: 1, max: 4096)
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    @LuaChainable
    public func resize(width: Int, height: Int) -> Self {
        self.width = width
        self.height = height
        return self
    }
}

// Use it
let lua = try LuaState()
lua.setDebugMode(true)
lua.register(Image.self, as: "Image")

try lua.execute("""
    local img = Image.new(1920, 1080)
    print("Size:", img.width, "x", img.height)
    img:resize(800, 600):resize(400, 300)  -- Method chaining!
""")
```

## 🧪 Testing

50+ comprehensive tests covering all features including:
- Basic Lua execution
- Type conversions (including Date, URL, UUID)
- Global variable access
- Table operations
- Swift class bridging
- All 15 enhancement features
- Property validation
- Enum bridging
- Async operations
- Debug mode

## 📚 Examples

- `EnhancementsExample.swift`: Demonstrates all 15 new features
- `MacroExample.swift`: Comprehensive macro demonstrations
- `PropertyChangeExample.swift`: Property change notifications with validation
- `ClosureBridgingExample.swift`: Closure bridging demonstrations

## 🔧 Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.5+
- Xcode 13.0+

## 📝 Version Note

LuaKit uses semantic versioning (major.minor.patch) with the embedded Lua version shown as build metadata.
This release: `1.3.0+lua5.4.8` indicates LuaKit 1.3.0 with Lua 5.4.8 embedded.

## 📄 License

Released under the MIT License.

## 🙏 Acknowledgments

LuaKit embeds Lua 5.4.8 directly, providing a self-contained solution with no external dependencies.