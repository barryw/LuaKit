# LuaKit 5.4.7

Initial release of LuaKit - A Swift framework for embedding Lua scripting into iOS and macOS applications.

## 🎯 Features

### Core Functionality
- **Swift-Lua Bridging**: Seamlessly expose Swift classes to Lua with the `LuaBridgeable` protocol
- **Type Safety**: Automatic type conversion between Swift and Lua types
- **Global Variables**: Easy access to Lua globals with Swift subscript syntax
- **Tables**: Create and manipulate Lua tables from Swift
- **Error Handling**: Comprehensive error reporting for syntax and runtime errors

### Swift API
- `LuaState`: Main class for managing Lua execution
- `LuaBridgeable`: Protocol for exposing Swift classes to Lua
- `LuaConvertible`: Protocol for type conversion
- `LuaGlobals`: Access to Lua global variables
- `LuaTable`: Lua table manipulation
- `LuaError`: Detailed error types

## 📦 Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit", from: "5.4.7")
]
```

## 🚀 Quick Start

```swift
import LuaKit

// Create a Lua state
let lua = try LuaState()

// Execute Lua code
try lua.execute("print('Hello from Lua!')")

// Bridge a Swift class
lua.register(MyClass.self, as: "MyClass")

// Use globals
lua.globals["myValue"] = 42
```

## 🧪 Testing

The framework includes a comprehensive test suite with 18 tests covering:
- Basic Lua execution
- Type conversions
- Global variable access
- Table operations
- Swift class bridging

## 🔧 Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.5+
- Xcode 13.0+

## 📝 Notes

- Version 5.4.7 aligns with the underlying Lua version
- Macro support (`@LuaBridgeable`) is temporarily disabled pending Swift macro stabilization
- Full manual bridging is supported and demonstrated in tests

## 🙏 Acknowledgments

Built on top of CLua (https://github.com/barryw/CLua) for Lua C bindings.