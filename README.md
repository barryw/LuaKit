# LuaKit

A Swift framework for embedding Lua scripting into iOS and macOS applications with seamless Swift-Lua bridging.

## Features

- **Easy Lua Integration**: Simple API to create and manage Lua states
- **Swift-Lua Bridging**: Expose Swift classes and methods to Lua with minimal boilerplate
- **Type Safety**: Automatic type conversion between Swift and Lua types
- **Macro Support**: Use `@LuaBridgeable` macro to automatically generate bridging code
- **Global Variables**: Easy access to Lua globals with Swift subscript syntax
- **Tables**: Create and manipulate Lua tables from Swift
- **Error Handling**: Comprehensive error reporting for syntax and runtime errors

## Installation

### Swift Package Manager

Add LuaKit to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit", from: "5.4.7")
]
```

Or in Xcode:

1. In Xcode, select File > Add Package Dependencies
2. Enter: `https://github.com/barryw/LuaKit`
3. Select the version you want to use

## Quick Start

```swift
import LuaKit

// Create a Lua state
let lua = try LuaState()

// Execute Lua code
try lua.execute("print('Hello from Lua!')")

// Get values from Lua
let result = try lua.executeReturning("return 2 + 2", as: Int.self)
print("Result: \(result)") // Result: 4
```

## Bridging Swift Classes to Lua

### Using the @LuaBridgeable Macro (Recommended)

**Important**: Due to current Swift macro limitations, you must:
1. Import `CLua` in your file
2. Manually add the `: LuaBridgeable` conformance
3. The macro will then generate the required methods

```swift
import Foundation
import CLua  // Required for generated code
import LuaKit

@LuaBridgeable
public class Image: LuaBridgeable {  // Must explicitly conform
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
    
    public var description: String {
        return "Image(\(width)x\(height))"
    }
}

// Create a Lua state
let lua = try LuaState()

// Register the class with Lua
lua.register(Image.self, as: "Image")

// Use it from Lua
try lua.execute("""
    local img = Image.new(1920, 1080)
    print("Size:", img.width, "x", img.height)
    img:resize(800, 600)
""")
```

### Manual Implementation (Alternative)

If you prefer not to use macros or need more control, you can implement the protocol manually:

```swift
public class Image: LuaBridgeable {
    // ... properties and methods ...
    
    static func registerMethods(_ L: OpaquePointer) {
        // Implementation details
    }
    
    static func registerConstructor(_ L: OpaquePointer, name: String) {
        // Implementation details
    }
    
    static func luaNew(_ L: OpaquePointer) -> Int32 {
        // Implementation details
    }
}
```

## Working with Globals

```swift
// Set global variables
lua.globals["myNumber"] = 42
lua.globals["myString"] = "Hello!"

// Access from Lua
try lua.execute("print(myNumber, myString)")

// Get global variables
if let value = lua.globals["myNumber"] as? Int {
    print("Got: \(value)")
}
```

## Working with Tables

```swift
// Create a table
let table = lua.createTable()
table["name"] = "John"
table["age"] = 30
table[1] = "first"
table[2] = "second"

// Set as global
lua.globals.set("person", to: table)

// Use from Lua
try lua.execute("""
    print(person.name)    -- John
    print(person.age)     -- 30
    print(person[1])      -- first
""")
```

## Bridging Modes

The `@LuaBridgeable` macro supports two modes:

### Automatic Mode (Default)
All public members are bridged unless marked with `@LuaIgnore`:

```swift
@LuaBridgeable
public class BankAccount {
    public var balance: Double       // ✅ Bridged
    
    @LuaIgnore
    public var accountNumber: String // ❌ Not bridged
    
    public func deposit(_ amount: Double) { }  // ✅ Bridged
    
    @LuaIgnore
    public func deleteAccount() { }  // ❌ Not bridged
}
```

### Explicit Mode
Only members marked with `@LuaOnly` are bridged:

```swift
@LuaBridgeable(mode: .explicit)
public class SecureData {
    @LuaOnly
    public var publicInfo: String  // ✅ Bridged
    
    public var secretKey: String   // ❌ Not bridged
    
    @LuaOnly
    public func getPublicData() -> String { }  // ✅ Bridged
    
    public func deleteAll() { }  // ❌ Not bridged
}
```

## Error Handling

LuaKit provides detailed error information:

```swift
do {
    try lua.execute("invalid lua code")
} catch LuaError.syntax(let message) {
    print("Syntax error: \(message)")
} catch LuaError.runtime(let message) {
    print("Runtime error: \(message)")
} catch {
    print("Other error: \(error)")
}
```

## Macro Limitations

The `@LuaBridgeable` macro has some limitations due to Swift's evolving macro system:

1. **Manual Imports Required**: You must import `CLua` in files using the macro
2. **Explicit Conformance**: You must manually add `: LuaBridgeable` to your class
3. **Generated Code Context**: The macro generates code that expects certain functions to be in scope

These limitations will be addressed as Swift's macro system matures. For now, the macro still provides significant value by eliminating boilerplate code.

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.5+
- Xcode 13.0+

## License

[Your License Here]