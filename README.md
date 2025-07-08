# LuaKit

A Swift framework for embedding Lua scripting into iOS and macOS applications with seamless Swift-Lua bridging. LuaKit includes Lua 5.4.7 embedded directly, requiring no external dependencies.

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
1. Import `Lua` in your file
2. Manually add the `: LuaBridgeable` conformance
3. The macro will then generate the required methods

```swift
import Foundation
import Lua  // Required for generated code
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

If you prefer not to use macros or need more control, you can implement the protocol manually. Here's what the macro generates for the Image class above:

```swift
public class Image: LuaBridgeable {
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
    
    // MARK: - LuaBridgeable Protocol Implementation
    
    public static func luaNew(_ L: OpaquePointer) -> Int32 {
        let width = Int(luaL_checkinteger(L, 1))
        let height = Int(luaL_checkinteger(L, 2))
        
        let instance = Image(width: width, height: height)
        push(instance, to: L)
        
        return 1
    }
    
    public static func registerConstructor(_ L: OpaquePointer, name: String) {
        lua_createtable(L, 0, 1)
        
        lua_pushstring(L, "new")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            return Image.luaNew(L!)
        }, 0)
        lua_settable(L, -3)
        
        lua_setglobal(L, name)
    }
    
    public static func registerMethods(_ L: OpaquePointer) {
        // Register resize method
        lua_pushstring(L, "resize")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = Image.checkUserdata(L!, at: 1) else {
                return luaError(L!, "Invalid Image object")
            }
            
            let width = Int(luaL_checkinteger(L!, 2))
            let height = Int(luaL_checkinteger(L!, 3))
            obj.resize(width: width, height: height)
            return 0
        }, 0)
        lua_settable(L, -3)
        
        // Register __index for property access
        lua_pushstring(L, "__index")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = Image.checkUserdata(L!, at: 1) else {
                return luaError(L!, "Invalid Image object")
            }
            
            guard let key = String.pull(from: L!, at: 2) else {
                return 0
            }
            
            switch key {
            case "width":
                lua_pushinteger(L!, lua_Integer(obj.width))
                return 1
            case "height":
                lua_pushinteger(L!, lua_Integer(obj.height))
                return 1
            default:
                // Check metatable for methods
                lua_getmetatable(L!, 1)
                lua_pushstring(L!, key)
                lua_rawget(L!, -2)
                return 1
            }
        }, 0)
        lua_settable(L, -3)
        
        // Register __newindex for property setting
        lua_pushstring(L, "__newindex")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = Image.checkUserdata(L!, at: 1) else {
                return luaError(L!, "Invalid Image object")
            }
            
            guard let key = String.pull(from: L!, at: 2) else {
                return 0
            }
            
            switch key {
            case "width":
                obj.width = Int(luaL_checkinteger(L!, 3))
            case "height":
                obj.height = Int(luaL_checkinteger(L!, 3))
            default:
                return luaError(L!, "Cannot set property \(key)")
            }
            return 0
        }, 0)
        lua_settable(L, -3)
        
        // Register __tostring
        lua_pushstring(L, "__tostring")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = Image.checkUserdata(L!, at: 1) else {
                return luaError(L!, "Invalid Image object")
            }
            lua_pushstring(L!, obj.description)
            return 1
        }, 0)
        lua_settable(L, -3)
    }
}
```

As you can see, the @LuaBridgeable macro saves you from writing ~100 lines of boilerplate code!

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
    public var accountNumber: String // ❌ Not bridged (returns nil in Lua)
    
    public func deposit(_ amount: Double) { }  // ✅ Bridged
    
    @LuaIgnore
    public func deleteAccount() { }  // ❌ Not bridged (error if called)
}
```

**Note**: In Lua, accessing an ignored property returns `nil` (standard Lua behavior for non-existent properties), while calling an ignored method throws an error.

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

1. **Manual Imports Required**: You must import `Lua` in files using the macro
2. **Explicit Conformance**: You must manually add `: LuaBridgeable` to your class
3. **Generated Code Context**: The macro generates code that expects certain functions to be in scope

These limitations will be addressed as Swift's macro system matures. For now, the macro still provides significant value by eliminating boilerplate code.

## Requirements

- iOS 13.0+ / macOS 10.15+
- Swift 5.5+
- Xcode 13.0+

## License

MIT License - see [LICENSE](LICENSE) file for details.