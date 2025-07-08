# LuaKit 5.4.7

Swift framework for embedding Lua scripting into iOS and macOS applications with powerful macro support.

## 🎯 Key Features

### @LuaBridgeable Macro (Re-enabled!)
- **Automatic Code Generation**: Save ~100 lines of boilerplate per class
- **Flexible Control**: Use `@LuaIgnore` to exclude specific members
- **Explicit Mode**: Use `@LuaOnly` for fine-grained control
- **Type Safety**: Automatic Swift-Lua type conversions

### Core Functionality
- **Swift-Lua Bridging**: Seamlessly expose Swift classes to Lua
- **Global Variables**: Easy access with Swift subscript syntax
- **Tables**: Create and manipulate Lua tables from Swift
- **Error Handling**: Comprehensive error reporting
- **Print Capture**: Capture Lua print output in Swift

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit", from: "5.4.7")
]
```

## 🚀 Quick Start

```swift
import CLua  // Required for @LuaBridgeable
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

## 📝 Macro Limitations

Due to current Swift macro limitations:
1. Must import `CLua` in files using `@LuaBridgeable`
2. Must explicitly add `: LuaBridgeable` conformance
3. Generated code expects certain functions in scope

These limitations are documented in the README and will be addressed as Swift's macro system evolves.

## 🧪 Testing

20 comprehensive tests covering:
- Basic Lua execution
- Type conversions
- Global variable access
- Table operations
- Swift class bridging
- Macro functionality
- Explicit mode with @LuaOnly

## 📚 Examples

- `MacroExample.swift`: Comprehensive macro demonstrations
- `ManualBridgingExample.swift`: Shows manual implementation
- `Image.swift`: Basic @LuaBridgeable usage

## 🔧 Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.5+
- Xcode 13.0+

## 📝 Version Note

Version 5.4.7 matches the underlying Lua version for clarity.

## 🙏 Acknowledgments

Built on [CLua](https://github.com/barryw/CLua) for Lua C bindings.