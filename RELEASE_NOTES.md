# LuaKit 1.1.0+lua5.4.8

Swift framework for embedding Lua scripting into iOS and macOS applications with powerful macro support.

## 🆕 What's New in This Release

### Property Change Notifications
- Added `luaPropertyWillChange` and `luaPropertyDidChange` methods to LuaBridgeable protocol
- Track property modifications from Lua for persistence, logging, or debugging
- Validate and reject property changes with custom error messages using Result type
- Default implementations ensure backward compatibility

### Array Support
- Full support for array properties: `[String]`, `[Int]`, `[Double]`, `[Bool]`
- Seamless Swift-Lua array bridging with automatic type conversion
- Individual array element access from Lua (e.g., `palette.colors[1] = "red"`)
- Array proxy implementation with full Lua metamethod support
- Respects Lua's 1-based indexing conventions

### Embedded Lua
- Lua 5.4.8 is now embedded directly in LuaKit
- No external dependencies required
- Simplified installation and distribution

## 🎯 Key Features

### @LuaBridgeable Macro (Re-enabled!)
- **Automatic Code Generation**: Save ~100 lines of boilerplate per class
- **Flexible Control**: Use `@LuaIgnore` to exclude specific members
- **Explicit Mode**: Use `@LuaOnly` for fine-grained control
- **Type Safety**: Automatic Swift-Lua type conversions

### Core Functionality
- **Swift-Lua Bridging**: Seamlessly expose Swift classes to Lua
- **Property Change Notifications**: Track and validate property changes from Lua
- **Global Variables**: Easy access with Swift subscript syntax
- **Tables**: Create and manipulate Lua tables from Swift
- **Error Handling**: Comprehensive error reporting
- **Print Capture**: Capture Lua print output in Swift
- **Embedded Lua**: Lua 5.4.8 embedded directly, no external dependencies

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit", from: "1.1.0")
]
```

## 🚀 Quick Start

```swift
import Lua  // Required for @LuaBridgeable
import LuaKit

@LuaBridgeable
class Image: LuaBridgeable {
    public var width: Int
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    public func resize(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

// Use it
let lua = try LuaState()
lua.register(Image.self, as: "Image")

try lua.execute("""
    local img = Image.new(1920, 1080)
    print("Size:", img.width, "x", img.height)
    img:resize(800, 600)
""")
```

## 🔔 Property Change Notifications Example

```swift
@LuaBridgeable
class ConfigModel: LuaBridgeable {
    public var apiUrl: String
    public var timeout: Int
    
    public init(apiUrl: String, timeout: Int) {
        self.apiUrl = apiUrl
        self.timeout = timeout
    }
    
    // Validate changes before they happen
    public func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        if propertyName == "timeout", let newTimeout = newValue as? Int {
            guard newTimeout > 0 && newTimeout <= 300 else {
                return .failure(PropertyValidationError("Timeout must be between 1 and 300 seconds"))
            }
        }
        return .success(())
    }
    
    // Track changes after they happen
    public func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
        print("Config changed: \(propertyName) = \(newValue ?? "nil")")
        saveConfiguration() // Persist to disk
    }
    
    public var description: String {
        return "ConfigModel(apiUrl: \(apiUrl), timeout: \(timeout)s)"
    }
}

// Use it
let config = ConfigModel(apiUrl: "https://api.example.com", timeout: 30)
lua.globals["config"] = config

try lua.execute("""
    config.timeout = 60  -- This will trigger notifications
    
    -- Try invalid value (will raise error)
    local success, err = pcall(function()
        config.timeout = -1  -- This will be rejected
    end)
    if not success then
        print("Error:", err)
    end
""")
```

## 📝 Macro Limitations

Due to current Swift macro limitations:
1. Must import `Lua` in files using `@LuaBridgeable`
2. Must explicitly add `: LuaBridgeable` conformance
3. Generated code expects certain functions in scope

These limitations are documented in the README and will be addressed as Swift's macro system evolves.

## 🧪 Testing

29 comprehensive tests covering:
- Basic Lua execution
- Type conversions
- Global variable access
- Table operations
- Swift class bridging
- Macro functionality
- Explicit mode with @LuaOnly
- Property change notifications

## 📚 Examples

- `MacroExample.swift`: Comprehensive macro demonstrations
- `ManualBridgingExample.swift`: Shows manual implementation
- `PropertyChangeExample.swift`: Property change notifications with validation and persistence
- `Image.swift`: Basic @LuaBridgeable usage

## 🔧 Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.5+
- Xcode 13.0+

## 📝 Version Note

LuaKit uses semantic versioning (major.minor.patch) with the embedded Lua version shown as build metadata.
This release: `1.1.0+lua5.4.8` indicates LuaKit 1.1.0 with Lua 5.4.8 embedded.

## 📄 License

Released under the MIT License.

## 🙏 Acknowledgments

LuaKit embeds Lua 5.4.8 directly, providing a self-contained solution with no external dependencies.