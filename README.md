<div align="center">
  <img src="Images/luakit-logo.svg" alt="LuaKit Logo" width="200" height="200">
  
  <h1>LuaKit</h1>
  
  <p><strong>Seamless Swift ↔ Lua Bridging for iOS & macOS</strong></p>
  
  <p>
    <a href="https://github.com/barryw/LuaKit/actions/workflows/ci-cd.yml">
      <img src="https://github.com/barryw/LuaKit/actions/workflows/ci-cd.yml/badge.svg" alt="CI/CD Status">
    </a>
    <a href="https://codecov.io/gh/barryw/LuaKit">
      <img src="https://codecov.io/gh/barryw/LuaKit/branch/main/graph/badge.svg" alt="Code Coverage">
    </a>
    <a href="https://github.com/barryw/LuaKit/releases">
      <img src="https://img.shields.io/github/v/release/barryw/LuaKit?color=orange" alt="Latest Release">
    </a>
    <a href="https://github.com/barryw/LuaKit/blob/main/LICENSE">
      <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT">
    </a>
    <a href="https://www.swift.org">
      <img src="https://img.shields.io/badge/Swift-5.9+-orange.svg" alt="Swift 5.9+">
    </a>
    <a href="https://www.lua.org">
      <img src="https://img.shields.io/badge/Lua-5.4.8-000080.svg" alt="Lua 5.4.8">
    </a>
  </p>
  
  <p>
    <a href="https://developer.apple.com/ios/">
      <img src="https://img.shields.io/badge/iOS-13.0+-black.svg" alt="iOS 13.0+">
    </a>
    <a href="https://developer.apple.com/macos/">
      <img src="https://img.shields.io/badge/macOS-10.15+-black.svg" alt="macOS 10.15+">
    </a>
    <a href="https://developer.apple.com/tvos/">
      <img src="https://img.shields.io/badge/tvOS-13.0+-black.svg" alt="tvOS 13.0+">
    </a>
    <a href="https://developer.apple.com/watchos/">
      <img src="https://img.shields.io/badge/watchOS-6.0+-black.svg" alt="watchOS 6.0+">
    </a>
  </p>
</div>

<div align="center">
  <h3>
    <a href="#installation">Installation</a>
    <span> · </span>
    <a href="#quick-start">Quick Start</a>
    <span> · </span>
    <a href="#documentation">Documentation</a>
    <span> · </span>
    <a href="#examples">Examples</a>
  </h3>
</div>

---

A powerful Swift framework for embedding Lua scripting into iOS and macOS applications with seamless Swift-Lua bridging. LuaKit includes Lua 5.4.8 embedded directly, requiring no external dependencies.

## ✨ Features

### Core Features
- 🚀 **Easy Lua Integration**: Simple API to create and manage Lua states
- 🌉 **Swift-Lua Bridging**: Expose Swift classes and methods to Lua with minimal boilerplate
- 🛡️ **Type Safety**: Automatic type conversion between Swift and Lua types
- 📚 **Array Support**: Seamless bridging of Swift arrays (`[String]`, `[Int]`, `[Double]`, `[Bool]`)
- 🎯 **Macro Support**: Use `@LuaBridgeable` macro to automatically generate bridging code
- 📡 **Property Change Notifications**: Track and validate property changes from Lua
- 🌍 **Global Variables**: Easy access to Lua globals with Swift subscript syntax
- 📊 **Tables**: Create and manipulate Lua tables from Swift
- ⚠️ **Error Handling**: Comprehensive error reporting for syntax and runtime errors

### Enhanced Features (v1.3.0+)

- **🎯 Method Return Type Variants**: Support methods that return different types based on parameters
- **📊 Collection Syntax**: Array-like method calls with intuitive syntax
- **🔄 Method Aliases**: Multiple names for the same method to improve API usability
- **🏭 Factory Pattern**: Create instances using factory methods
- **🔗 Method Chaining**: Fluent API support for chained method calls
- **🔢 Enum Bridging**: Automatic registration and validation of Swift enums
- **📋 Namespace Organization**: Organize related functionality into logical namespaces
- **✅ Property Validation**: Built-in validators for ranges, regex patterns, and enums
- **⚡ Async/Await Support**: Bridge Swift async functions to Lua
- **🔧 Type Conversion Helpers**: Simplified type conversion with @LuaConvert
- **🐛 Debug Mode**: Enhanced debugging capabilities with performance tracking
- **🌐 Global Function Registration**: Register Swift functions as global Lua functions
- **📝 Better Error Messages**: Detailed error context with suggestions
- **🔍 Debug Helpers**: Runtime inspection and debugging tools
- **🛡️ Enhanced Type Safety**: Additional validation and type checking

## Installation

### Swift Package Manager

Add LuaKit to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit", from: "1.3.0")
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

## Working with Arrays

LuaKit provides seamless array bridging between Swift and Lua for all primitive types:

```swift
@LuaBridgeable
class ServerConfig: LuaBridgeable {
    public var hosts: [String] = []
    public var ports: [Int] = []
    public var weights: [Double] = []
    public var enabled: [Bool] = []
    
    public init() {}
    
    public var description: String {
        return "ServerConfig(hosts: \(hosts.count), ports: \(ports.count))"
    }
}

// Register and use
let config = ServerConfig()
lua.register(ServerConfig.self, as: "ServerConfig")
lua.globals["config"] = config

// Set arrays from Lua
try lua.execute("""
    config.hosts = {"api1.example.com", "api2.example.com", "api3.example.com"}
    config.ports = {443, 443, 8443}
    config.weights = {0.5, 0.3, 0.2}
    config.enabled = {true, true, false}
    
    -- Access array elements (Lua uses 1-based indexing)
    print(config.hosts[1])  -- "api1.example.com"
    
    -- Modify individual elements
    config.hosts[2] = "api2-backup.example.com"
    config.ports[3] = 9443
    
    -- Append elements by setting at length + 1
    config.hosts[#config.hosts + 1] = "api4.example.com"
    
    -- Iterate over arrays
    for i, host in ipairs(config.hosts) do
        print(i, host, config.ports[i])
    end
""")

// Arrays set in Swift are accessible in Lua
config.hosts = ["db1.local", "db2.local"]
let count = try lua.executeReturning("return #config.hosts", as: Int.self)  // 2
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

## Property Change Notifications

LuaBridgeable classes can track and control property changes made from Lua by implementing optional notification methods:

### Basic Usage

```swift
@LuaBridgeable
public class TrackedModel: LuaBridgeable {
    public var name: String
    public var value: Int
    
    public init(name: String, value: Int) {
        self.name = name
        self.value = value
    }
    
    // Called before a property is changed from Lua
    public func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        print("Property '\(propertyName)' will change from \(oldValue ?? "nil") to \(newValue ?? "nil")")
        
        // Return failure to reject the change with a custom error message
        if propertyName == "value", let newInt = newValue as? Int, newInt < 0 {
            return .failure(PropertyValidationError("Value cannot be negative (attempted to set to \(newInt))"))
        }
        
        return .success(()) // Allow the change
    }
    
    // Called after a property has been changed from Lua
    public func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
        print("Property '\(propertyName)' changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
    }
    
    public var description: String {
        return "TrackedModel(name: \(name), value: \(value))"
    }
}
```

### Persistence Example

```swift
@LuaBridgeable
public class PersistentModel: LuaBridgeable {
    public var data: String
    private var isDirty = false
    
    public init(data: String) {
        self.data = data
    }
    
    public func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
        isDirty = true
        // In a real app, you might schedule a save operation here
        saveToDatabase()
    }
    
    private func saveToDatabase() {
        // Persist changes to your database
        print("Saving \(propertyName) = \(newValue) to database")
        isDirty = false
    }
    
    public var description: String {
        return "PersistentModel(data: \(data))"
    }
}
```

### Validation Example

```swift
@LuaBridgeable
public class ValidatedUser: LuaBridgeable {
    public var email: String
    public var age: Int
    
    public init(email: String, age: Int) {
        self.email = email
        self.age = age
    }
    
    public func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        switch propertyName {
        case "email":
            guard let newEmail = newValue as? String,
                  newEmail.contains("@") && newEmail.contains(".") else {
                return .failure(PropertyValidationError("Invalid email format"))
            }
        case "age":
            guard let newAge = newValue as? Int,
                  newAge >= 0 && newAge <= 150 else {
                return .failure(PropertyValidationError("Age must be between 0 and 150"))
            }
        default:
            break
        }
        return .success(())
    }
    
    public var description: String {
        return "ValidatedUser(email: \(email), age: \(age))"
    }
}
```

### Default Behavior

If you don't implement these methods, the default behavior is:
- `luaPropertyWillChange`: Always returns `.success(())` (allows all changes)
- `luaPropertyDidChange`: Does nothing (no-op)

This means existing code continues to work without modification.

### Error Handling

When `luaPropertyWillChange` returns `.failure(PropertyValidationError)`, the property setter raises a Lua runtime error with the custom error message you provide. This allows for descriptive validation errors that help users understand why their change was rejected.

This follows Lua's standard error handling patterns, allowing you to catch the error with `pcall`:

```lua
local success, err = pcall(function()
    obj.value = -5  -- This might be rejected
end)

if not success then
    print("Property change rejected:", err)
    -- Error message will be your custom validation error, e.g.:
    -- "Value cannot be negative (attempted to set to -5)"
end
```

## Closure Bridging

Pass Swift closures to Lua as callable functions:

```swift
// Simple closure
lua.globals["greet"] = LuaFunction { 
    return "Hello from Swift!" 
}

// Closure with parameters
lua.registerFunction("add") { (a: Int, b: Int) in
    return a + b
}

// Closure returning Swift objects
lua.registerFunction("createPoint") { (x: Double, y: Double) in
    return Point(x: x, y: y)  // Returns a LuaBridgeable object
}

// Use from Lua
try lua.execute("""
    print(greet())                    -- "Hello from Swift!"
    print("Sum:", add(10, 32))        -- "Sum: 42"
    
    local p = createPoint(5.0, 10.0)
    print("Point:", p.x, p.y)         -- "Point: 5.0 10.0"
""")
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

## Enhanced Features Documentation

### 🎯 Method Return Type Variants

Methods can return different types based on their parameters using the `@LuaVariant` attribute:

```swift
@LuaBridgeable
public class DataProcessor: LuaBridgeable {
    public init() {}
    
    @LuaVariant(returns: String.self, when: "format == 'string'")
    @LuaVariant(returns: Int.self, when: "format == 'number'")
    public func process(_ data: String, format: String) -> Any {
        switch format {
        case "string":
            return data.uppercased()
        case "number":
            return Int(data) ?? 0
        default:
            return data
        }
    }
    
    public var description: String { "DataProcessor()" }
}

// Usage in Lua
try lua.execute("""
    local processor = DataProcessor.new()
    local result1 = processor:process("hello", "string")  -- Returns "HELLO"
    local result2 = processor:process("42", "number")     -- Returns 42
""")
```

### 📊 Collection Syntax

Access arrays and collections with intuitive method-like syntax:

```swift
@LuaBridgeable
public class TaskManager: LuaBridgeable {
    public var tasks: [String] = []
    
    public init() {}
    
    @LuaCollection
    public var items: [String] {
        get { tasks }
        set { tasks = newValue }
    }
    
    public var description: String { "TaskManager(\(tasks.count) tasks)" }
}

// Usage in Lua - multiple syntax options
try lua.execute("""
    local manager = TaskManager.new()
    
    -- Array-style access
    manager.tasks = {"task1", "task2", "task3"}
    print(manager.tasks[1])  -- "task1"
    
    -- Collection-style methods
    manager:add("task4")         -- Add item
    manager:remove(2)            -- Remove by index
    manager:clear()              -- Clear all
    print(manager:count())       -- Get count
""")
```

### 🔄 Method Aliases

Provide multiple names for the same method to improve API usability:

```swift
@LuaBridgeable
public class FileManager: LuaBridgeable {
    public init() {}
    
    @LuaAlias("delete", "remove", "rm")
    public func deleteFile(_ path: String) -> Bool {
        // File deletion logic
        print("Deleting file: \(path)")
        return true
    }
    
    @LuaAlias("copy", "cp", "duplicate")
    public func copyFile(from source: String, to dest: String) -> Bool {
        print("Copying \(source) to \(dest)")
        return true
    }
    
    public var description: String { "FileManager()" }
}

// Usage in Lua - all aliases work
try lua.execute("""
    local fm = FileManager.new()
    
    -- All these do the same thing
    fm:deleteFile("old.txt")
    fm:delete("old.txt")
    fm:remove("old.txt")
    fm:rm("old.txt")
    
    -- Copy with different alias styles
    fm:copyFile("source.txt", "dest.txt")
    fm:copy("source.txt", "dest.txt")
    fm:cp("source.txt", "dest.txt")
""")
```

### 🏭 Factory Pattern

Create instances using factory methods with `@LuaFactory`:

```swift
@LuaBridgeable
public class DatabaseConnection: LuaBridgeable {
    private let connectionString: String
    
    private init(connectionString: String) {
        self.connectionString = connectionString
    }
    
    @LuaFactory()
    public static func mysql(host: String, port: Int, database: String) -> DatabaseConnection {
        return DatabaseConnection(connectionString: "mysql://\(host):\(port)/\(database)")
    }
    
    @LuaFactory()
    public static func postgresql(host: String, database: String) -> DatabaseConnection {
        return DatabaseConnection(connectionString: "postgresql://\(host)/\(database)")
    }
    
    @LuaFactory()
    public static func sqlite(path: String) -> DatabaseConnection {
        return DatabaseConnection(connectionString: "sqlite://\(path)")
    }
    
    public var description: String { "DatabaseConnection(\(connectionString))" }
}

// Usage in Lua
try lua.execute("""
    -- Create different database connections using factory methods
    local mysql_db = DatabaseConnection.mysql("localhost", 3306, "myapp")
    local postgres_db = DatabaseConnection.postgresql("localhost", "myapp")
    local sqlite_db = DatabaseConnection.sqlite("/path/to/db.sqlite")
    
    print(mysql_db)      -- DatabaseConnection(mysql://localhost:3306/myapp)
    print(postgres_db)   -- DatabaseConnection(postgresql://localhost/myapp)
    print(sqlite_db)     -- DatabaseConnection(sqlite:///path/to/db.sqlite)
""")
```

### 🔗 Method Chaining

Create fluent APIs with method chaining using `@LuaChainable`:

```swift
@LuaBridgeable
public class QueryBuilder: LuaBridgeable {
    private var query = ""
    
    public init() {}
    
    @LuaChainable()
    public func select(_ fields: String) -> QueryBuilder {
        query += "SELECT \(fields) "
        return self
    }
    
    @LuaChainable()
    public func from(_ table: String) -> QueryBuilder {
        query += "FROM \(table) "
        return self
    }
    
    @LuaChainable()
    public func where(_ condition: String) -> QueryBuilder {
        query += "WHERE \(condition) "
        return self
    }
    
    @LuaChainable()
    public func orderBy(_ field: String) -> QueryBuilder {
        query += "ORDER BY \(field) "
        return self
    }
    
    public func build() -> String {
        return query.trimmingCharacters(in: .whitespaces)
    }
    
    public var description: String { "QueryBuilder('\(query.trimmingCharacters(in: .whitespaces))')" }
}

// Usage in Lua with method chaining
try lua.execute("""
    local query = QueryBuilder.new()
        :select("name, email")
        :from("users")
        :where("age > 18")
        :orderBy("name")
    
    print(query:build())  -- "SELECT name, email FROM users WHERE age > 18 ORDER BY name"
""")
```

### 🔢 Enum Bridging

Automatically bridge Swift enums to Lua with validation:

```swift
public enum UserRole: String, LuaEnumBridgeable, CaseIterable {
    case admin = "admin"
    case editor = "editor"
    case viewer = "viewer"
    
    public static var luaTypeName: String { "UserRole" }
}

public enum Priority: String, LuaEnumBridgeable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

@LuaBridgeable
public class User: LuaBridgeable {
    public var name: String
    public var role: String
    
    public init(name: String, role: String = "viewer") {
        self.name = name
        self.role = role
    }
    
    public func hasPermission(for action: String) -> Bool {
        guard let userRole = UserRole(rawValue: role) else { return false }
        switch userRole {
        case .admin: return true
        case .editor: return action != "delete"
        case .viewer: return action == "read"
        }
    }
    
    public var description: String { "User(\(name), \(role))" }
}

// Register enums and use them
lua.registerEnum(UserRole.self)
lua.registerEnum(Priority.self, as: "TaskPriority")

try lua.execute("""
    -- Enums are available as global tables
    print(UserRole.admin)    -- "admin"
    print(UserRole.editor)   -- "editor"
    print(TaskPriority.high) -- "high"
    
    -- Use with objects
    local user = User.new("John", UserRole.admin)
    print(user:hasPermission("delete"))  -- true
    
    -- Validation functions are also available
    print(validateUserRole("admin"))     -- true
    print(validateUserRole("invalid"))   -- false
""")
```

### 📋 Namespace Organization

Organize related functionality into logical namespaces:

```swift
// Register functions in namespaces
lua.globals.namespace("Math")
    .registerFunction("add") { (a: Double, b: Double) in a + b }
    .registerFunction("multiply") { (a: Double, b: Double) in a * b }
    .registerFunction("power") { (base: Double, exp: Double) in pow(base, exp) }

lua.globals.namespace("String")
    .registerFunction("reverse") { (s: String) in String(s.reversed()) }
    .registerFunction("uppercase") { (s: String) in s.uppercased() }
    .registerFunction("wordCount") { (s: String) in s.components(separatedBy: .whitespaces).count }

// Usage in Lua
try lua.execute("""
    -- Use namespaced functions
    local result = Math.add(5, 3)           -- 8
    local power = Math.power(2, 3)          -- 8
    
    local reversed = String.reverse("hello") -- "olleh"
    local upper = String.uppercase("world")  -- "WORLD"
    local words = String.wordCount("hello world")  -- 2
""")
```

### ✅ Property Validation

Built-in validators for common validation scenarios:

```swift
@LuaBridgeable
public class Product: LuaBridgeable {
    @LuaValidate(min: 0.0, max: 10000.0)
    public var price: Double = 0.0
    
    @LuaValidate(regex: "^[A-Z]{2,4}-\\d{3,5}$")
    public var sku: String = ""
    
    @LuaValidate(enum: ProductCategory.self)
    public var category: String = "electronics"
    
    @LuaReadOnly
    public var id: String
    
    public init(id: String) {
        self.id = id
    }
    
    public var description: String { "Product(\(id): \(sku), $\(price))" }
}

public enum ProductCategory: String, LuaEnumBridgeable, CaseIterable {
    case electronics = "electronics"
    case clothing = "clothing"
    case books = "books"
    case home = "home"
}

// Usage with automatic validation
try lua.execute("""
    local product = Product.new("P001")
    
    -- Valid assignments
    product.price = 99.99        -- ✅ Within range
    product.sku = "ABC-1234"     -- ✅ Matches regex
    product.category = "books"   -- ✅ Valid enum value
    
    -- Invalid assignments (will throw errors)
    -- product.price = -10       -- ❌ Below minimum
    -- product.sku = "invalid"   -- ❌ Doesn't match regex
    -- product.category = "food" -- ❌ Invalid enum value
    -- product.id = "new"        -- ❌ Read-only property
""")
```

### ⚡ Async/Await Support

Bridge Swift async functions to Lua:

```swift
@LuaBridgeable
public class APIClient: LuaBridgeable {
    public init() {}
    
    @LuaAsync()
    public func fetchUser(id: String) async throws -> [String: Any] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        return [
            "id": id,
            "name": "User \(id)",
            "email": "\(id.lowercased())@example.com"
        ]
    }
    
    @LuaAsync()
    public func uploadFile(path: String) async throws -> String {
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        return "uploaded://\(path)"
    }
    
    public var description: String { "APIClient()" }
}

// Register async support and use
lua.registerAsyncSupport()

try lua.execute("""
    local api = APIClient.new()
    
    -- Async operations return handles
    local handle1 = api:fetchUser("123")
    local handle2 = api:uploadFile("/tmp/file.txt")
    
    -- Wait for completion (simplified example)
    -- In practice, you'd use proper async patterns
""")
```

### 🔧 Type Conversion Helpers

Simplified type conversion with `@LuaConvert`:

```swift
@LuaBridgeable
public class DataConverter: LuaBridgeable {
    public init() {}
    
    @LuaConvert(from: String.self, to: Int.self)
    public func stringToInt(_ value: String) -> Int? {
        return Int(value)
    }
    
    @LuaConvert(from: Double.self, to: String.self)
    public func doubleToString(_ value: Double) -> String {
        return String(format: "%.2f", value)
    }
    
    @LuaConvert(from: [String].self, to: String.self)
    public func arrayToString(_ array: [String]) -> String {
        return array.joined(separator: ", ")
    }
    
    public var description: String { "DataConverter()" }
}

// Usage with automatic conversion
try lua.execute("""
    local converter = DataConverter.new()
    
    -- Type conversions are available
    local number = stringToInt("42")        -- 42
    local text = doubleToString(3.14159)    -- "3.14"
    local joined = arrayToString({"a", "b", "c"})  -- "a, b, c"
""")
```

### 🐛 Debug Mode

Enhanced debugging capabilities with performance tracking:

```swift
@LuaBridgeable(debug: true)
public class PerformanceCritical: LuaBridgeable {
    public var value: Int = 0
    
    public init() {}
    
    public func heavyComputation(_ iterations: Int) -> Int {
        var result = 0
        for i in 0..<iterations {
            result += i * i
        }
        return result
    }
    
    public var description: String { "PerformanceCritical(value: \(value))" }
}

// Enable debug mode for detailed logging
lua.setDebugMode(true)

try lua.execute("""
    local obj = PerformanceCritical.new()
    
    -- All method calls and property access are logged with timing
    obj.value = 42                    -- Logged: Property set: value = 42 (0.001ms)
    local result = obj:heavyComputation(1000)  -- Logged: Method call: heavyComputation(1000) -> 332833500 (2.4ms)
""")
```

### 🌐 Global Function Registration

Register Swift functions as global Lua functions:

```swift
// Register utility functions globally
lua.registerGlobal("uuid") { 
    return UUID().uuidString
}

lua.registerGlobal("timestamp") {
    return Date().timeIntervalSince1970
}

lua.registerGlobal("randomInt") { (min: Int, max: Int) in
    return Int.random(in: min...max)
}

lua.registerGlobal("formatCurrency") { (amount: Double, symbol: String) in
    return "\(symbol)\(String(format: "%.2f", amount))"
}

// Usage as global functions
try lua.execute("""
    print(uuid())                           -- "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
    print(timestamp())                      -- 1678901234.567
    print(randomInt(1, 100))               -- 42
    print(formatCurrency(123.45, "$"))     -- "$123.45"
""")
```

### 📝 Better Error Messages

Detailed error context with suggestions:

```swift
// Enhanced error context is automatically provided
do {
    try lua.execute("""
        local obj = NonExistentClass.new()
        obj:invalidMethod()
    """)
} catch LuaError.runtime(let message) {
    print(message)
    // Output includes:
    // - Line number and column
    // - Contextual information
    // - Suggestions for fixing the error
    // - Available alternatives
}
```

### 🔍 Debug Helpers

Runtime inspection and debugging tools:

```swift
// Enable enhanced debugging
lua.setDebugMode(true)

// Register debug inspection functions
lua.registerGlobal("inspect") { (obj: Any) in
    return LuaDebugger.inspect(obj)
}

lua.registerGlobal("getType") { (obj: Any) in
    return LuaDebugger.getDetailedType(obj)
}

// Usage for debugging
try lua.execute("""
    local obj = SomeClass.new()
    
    print(inspect(obj))    -- Detailed object inspection
    print(getType(obj))    -- "SomeClass (LuaBridgeable, 3 properties, 5 methods)"
    
    -- Performance monitoring
    local startTime = timestamp()
    obj:someMethod()
    local elapsed = timestamp() - startTime
    print("Method execution time:", elapsed, "seconds")
""")
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

## 📖 Documentation

### API Reference
- [LuaState](Documentation/LuaState.md) - Core Lua state management
- [LuaBridgeable](Documentation/LuaBridgeable.md) - Swift-Lua bridging protocol
- [LuaValue](Documentation/LuaValue.md) - Type-safe Lua value wrapper
- [Error Handling](Documentation/ErrorHandling.md) - Comprehensive error guide

### Guides
- [Getting Started](Documentation/GettingStarted.md) - Step-by-step introduction
- [Advanced Usage](Documentation/AdvancedUsage.md) - Performance tips and best practices
- [Migration Guide](Documentation/MigrationGuide.md) - Upgrading from older versions

### Examples
Check out the [Examples](Examples/) directory for complete sample projects:
- 🎮 [Game Scripting](Examples/GameScripting/) - Add Lua scripting to a game
- 🔧 [Configuration](Examples/Configuration/) - Use Lua for app configuration
- 🤖 [Automation](Examples/Automation/) - Build automation tools with Lua
- 📊 [Data Processing](Examples/DataProcessing/) - Process data with Lua scripts

## 📈 Changelog

### v1.3.0 (Latest)

**Major Enhancement Release** - 15 new features for advanced Swift-Lua bridging:

#### 🎯 Advanced Bridging Features
- **Method Return Type Variants** (`@LuaVariant`) - Methods that return different types based on parameters
- **Collection Syntax** (`@LuaCollection`) - Array-like method calls with intuitive syntax  
- **Method Aliases** (`@LuaAlias`) - Multiple names for the same method
- **Factory Pattern** (`@LuaFactory`) - Create instances using factory methods
- **Method Chaining** (`@LuaChainable`) - Fluent API support for chained method calls

#### 🔧 Developer Experience
- **Enum Bridging** - Automatic registration and validation of Swift enums
- **Namespace Organization** - Organize related functionality into logical namespaces
- **Property Validation** (`@LuaValidate`, `@LuaReadOnly`) - Built-in validators for ranges, regex, enums
- **Async/Await Support** (`@LuaAsync`) - Bridge Swift async functions to Lua
- **Type Conversion Helpers** (`@LuaConvert`) - Simplified type conversion utilities

#### 🐛 Debugging & Quality of Life
- **Debug Mode** - Enhanced debugging with performance tracking
- **Global Function Registration** - Register Swift functions as global Lua functions
- **Better Error Messages** - Detailed error context with suggestions
- **Debug Helpers** - Runtime inspection and debugging tools
- **Enhanced Type Safety** - Additional validation and type checking

#### 🔧 Under the Hood
- Fixed critical EXC_BAD_ACCESS crash in LuaFunction closure handling
- Improved macro system with better error handling
- Enhanced memory management for bridged objects
- All enhancements designed to be generic and reusable by any library consumer

#### 📊 Compatibility
- Fully backward compatible with v1.2.x
- All existing code continues to work without modification
- New features are opt-in and don't affect existing functionality

### v1.2.1
- Fixed critical crash in LuaFunction closure bridging
- Improved memory management for closure retention
- Enhanced error context system

### v1.1.1
- Initial stable release with core Swift-Lua bridging
- `@LuaBridgeable` macro support
- Array bridging for primitive types
- Property change notifications

## Credits

<div align="center">
  <a href="https://www.lua.org/">
    <img src="Images/lua-logo.gif" alt="Lua" width="128">
  </a>
  <br>
  <strong>Powered by Lua 5.4.8</strong>
</div>

LuaKit embeds the [Lua](https://www.lua.org/) programming language, created by Roberto Ierusalimschy, Waldemar Celes, and Luiz Henrique de Figueiredo at PUC-Rio. We are grateful for their excellent work on creating such a powerful, lightweight, and embeddable scripting language.

Lua is licensed under the [MIT license](https://www.lua.org/license.html).

## License

MIT License - see [LICENSE](LICENSE) file for details.