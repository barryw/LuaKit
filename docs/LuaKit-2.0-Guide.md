# LuaKit 2.0 Complete Guide

Welcome to LuaKit 2.0! This major release brings significant new features for embedding Lua in Swift applications.

---

## What's New in 2.0

### Phase 1: Extended Function Support
- **4-6 Parameter Functions**: Register Swift functions with up to 6 typed parameters

### Phase 2: Core API Improvements
- **LuaCallable**: Call Lua functions from Swift with full type safety
- **Nested Collections**: Native support for `[[Int]]`, `[String: [String]]`, etc.
- **LuaTable Iteration**: Swift `Sequence` conformance for Lua tables

### Phase 3: Advanced Features
- **LuaCallback**: Store Lua functions as Swift callbacks
- **LuaCoroutine**: Swift wrapper for Lua coroutines
- **Table Serialization**: JSON and Codable support

### Phase 4: API Cleanup
- **Consistent Naming**: Improved method names for better discoverability
- **Unified Error Handling**: Single `LuaError` type for all errors
- **Documentation**: Enhanced documentation for advanced APIs

---

## Quick Start

### Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit.git", from: "2.0.0")
]
```

### Basic Usage

```swift
import LuaKit

// Create a Lua state
let lua = try LuaState()

// Execute Lua code
try lua.execute("x = 10 + 20")
print(lua.globals["x"] as? Int ?? 0)  // 30

// Register Swift functions (now up to 6 params!)
lua.register(function: "greet") { (name: String, age: Int) -> String in
    "Hello \(name), you are \(age) years old"
}

// Call from Lua
try lua.execute("""
    message = greet("Alice", 30)
    print(message)
""")
```

---

## Feature Examples

### 1. Extended Function Parameters (Phase 1)

Register functions with 4, 5, or 6 parameters:

```swift
// 4 parameters
lua.register(function: "createRect") {
    (x: Double, y: Double, width: Double, height: Double) -> [String: Double] in
    ["x": x, "y": y, "width": width, "height": height]
}

// 5 parameters
lua.register(function: "httpRequest") {
    (method: String, url: String, body: String, timeout: Double, retries: Int) -> Bool in
    // Make request...
    true
}

// 6 parameters
lua.register(function: "drawLine") {
    (x1: Double, y1: Double, x2: Double, y2: Double, color: String, width: Double) in
    print("Drawing \(color) line from (\(x1),\(y1)) to (\(x2),\(y2))")
}
```

### 2. Call Lua Functions from Swift (Phase 2)

```swift
try lua.execute("""
    function add(a, b)
        return a + b
    end

    Math = {
        multiply = function(a, b) return a * b end
    }
""")

// Get function reference
let add = try lua.getFunction("add")
let result: Int = try add.call(10, 20)
print(result)  // 30

// Path-based lookup
let multiply = try lua.getFunction("Math.multiply")
let product: Int = try multiply.call(5, 6)
print(product)  // 30
```

### 3. Nested Collections (Phase 2)

```swift
// Push nested arrays
let matrix: [[Int]] = [[1, 2, 3], [4, 5, 6]]
lua.globals["matrix"] = matrix

// Push dictionaries with array values
let scores: [String: [Int]] = [
    "alice": [95, 87, 92],
    "bob": [88, 91, 85]
]
lua.globals["scores"] = scores

// Read them back
let retrieved = lua.globals["matrix"] as? [[Int]]
```

### 4. Table Iteration (Phase 2)

```swift
try lua.execute("""
    config = {host = "localhost", port = 8080, debug = true}
""")

let table = lua.getTable("config")!

// Iterate with for-in
for (key, value) in table {
    print("\(key): \(value)")
}

// Access properties
print("Count: \(table.count)")
print("Keys: \(table.keys)")
print("Has 'host': \(table.contains(key: "host"))")
```

### 5. Lua Callbacks (Phase 3)

```swift
try lua.execute("""
    function onPlayerDamage(amount)
        print("Player took " .. amount .. " damage!")
        return amount > 50  -- Return true if critical
    end
""")

// Store callback for later use
let callback = try lua.getCallback("onPlayerDamage")

// Call when needed
let isCritical: Bool = try callback.call(75)
print("Critical hit: \(isCritical)")  // true

// Use with void return
try callback.callVoid(25)
```

### 6. Coroutines (Phase 3)

```swift
// Create a generator
let fibonacci = try lua.createCoroutine("""
    local a, b = 0, 1
    for i = 1, 10 do
        coroutine.yield(a)
        a, b = b, a + b
    end
    return -1
""")

// Iterate through values
while fibonacci.status == .suspended {
    let num: Int = try fibonacci.resume()
    if num >= 0 {
        print(num, terminator: " ")
    }
}
// Output: 0 1 1 2 3 5 8 13 21 34
```

### 7. JSON Serialization (Phase 3)

```swift
// Export Lua table to JSON
try lua.execute("""
    user = {name = "Alice", age = 30, active = true}
""")
let table = lua.getTable("user")!
let json = try table.toJSON(prettyPrint: true)
print(json)

// Import JSON to Lua
let jsonData = """
{"items": ["sword", "shield"], "gold": 500}
"""
try lua.loadJSON(jsonData, as: "inventory")

try lua.execute("""
    print("Gold: " .. inventory.gold)
    for _, item in ipairs(inventory.items) do
        print("Item: " .. item)
    end
""")
```

### 8. Codable Support (Phase 3)

```swift
struct Player: Codable {
    let name: String
    let level: Int
    let health: Double
}

// Encode Swift struct to Lua
let player = Player(name: "Hero", level: 10, health: 100.0)
try lua.encode(player, as: "player")

try lua.execute("""
    print("Player: " .. player.name .. " (Level " .. player.level .. ")")
    player.level = player.level + 1
""")

// Decode back to Swift
let updated = try lua.decode("player", as: Player.self)
print("New level: \(updated.level)")  // 11
```

---

## Detailed Documentation

For comprehensive examples, see:

- **[Phase 1 Examples](examples/Phase1-Examples.md)** - Extended function parameters
- **[Phase 2 Examples](examples/Phase2-Examples.md)** - LuaCallable, nested collections, table iteration
- **[Phase 3 Examples](examples/Phase3-Examples.md)** - Callbacks, coroutines, serialization

---

## Common Patterns

### Event System with Callbacks

```swift
class EventEmitter {
    private var handlers: [String: [LuaCallback]] = [:]

    func on(_ event: String, handler: LuaCallback) {
        handlers[event, default: []].append(handler)
    }

    func emit(_ event: String, data: Any) {
        for handler in handlers[event] ?? [] {
            if handler.isValid {
                try? handler.callVoid(data)
            }
        }
    }
}
```

### Configuration with JSON

```swift
class Config {
    let lua: LuaState

    init(jsonPath: URL) throws {
        lua = try LuaState()
        let data = try Data(contentsOf: jsonPath)
        try lua.loadJSON(data, as: "config")
    }

    func get<T: LuaConvertible>(_ path: String) throws -> T {
        let getter = try lua.getFunction("function(t, k) return t[k] end")
        // ... implement path traversal
    }
}
```

### Scripted Game Logic

```swift
class GameScript {
    let lua: LuaState
    let onUpdate: LuaCallable
    let onCollision: LuaCallable

    init(scriptPath: URL) throws {
        lua = try LuaState()
        try lua.execute(String(contentsOf: scriptPath, encoding: .utf8))

        onUpdate = try lua.getFunction("onUpdate")
        onCollision = try lua.getFunction("onCollision")
    }

    func update(dt: Double) throws {
        try onUpdate.callVoid(dt)
    }

    func collision(a: String, b: String) throws -> Bool {
        try onCollision.call(a, b)
    }
}
```

---

## Error Handling

LuaKit 2.0 adds new error cases:

```swift
do {
    let callback = try lua.getCallback("myFunc")
    try callback.callVoid()
} catch LuaError.stateInvalid {
    // Lua state was deallocated
} catch LuaError.coroutineError(let message) {
    // Coroutine-specific error
} catch LuaError.runtime(let message) {
    // Lua runtime error
} catch LuaError.typeMismatch(let expected, let actual, let context) {
    // Type conversion failed
}
```

---

## Thread Safety

`LuaCallback` and `LuaCoroutine` are `@unchecked Sendable` with internal locking:

```swift
let callback = try lua.getCallback("asyncHandler")

Task {
    // Safe to use in async context
    try callback.callVoid("async data")
}

Task {
    // Can be used from multiple tasks
    let result: Int = try callback.call()
}
```

---

## API Reference

### LuaState Extensions

| Method | Description |
|--------|-------------|
| `getFunction(_:)` | Get a `LuaCallable` for a global or path-based function |
| `getTable(_:)` | Get a `LuaTable` for iteration |
| `getCallback(_:)` | Get a `LuaCallback` for storing/calling later |
| `createCoroutine(_:)` | Create a coroutine from code |
| `loadJSON(_:as:)` | Load JSON string/data as Lua table |
| `encode(_:as:)` | Encode Codable value to Lua |
| `decode(_:as:)` | Decode Lua table to Codable type |

### LuaCallable

| Method | Description |
|--------|-------------|
| `call<R>()` | Call with 0 args, return typed value |
| `call<T1,R>(_:)` | Call with 1 arg, return typed value |
| `call<T1,T2,R>(_:_:)` | Call with 2 args, return typed value |
| `callVoid()` | Call with 0 args, ignore return |
| `callVoid<T1>(_:)` | Call with 1 arg, ignore return |

### LuaCallback

| Property/Method | Description |
|-----------------|-------------|
| `isValid` | Check if Lua state is still alive |
| `state` | Get the LuaState (optional) |
| `call<R>()` | Call with 0-3 args, return value |
| `callVoid()` | Call with 0-4 args, ignore return |

### LuaCoroutine

| Property/Method | Description |
|-----------------|-------------|
| `status` | `.suspended`, `.running`, or `.dead` |
| `isValid` | Check if Lua state is still alive |
| `resume<R>()` | Resume with 0-2 args, return value |
| `resumeVoid()` | Resume, ignore return |

### LuaTable

| Property/Method | Description |
|-----------------|-------------|
| `count` | Number of elements |
| `isEmpty` | True if empty |
| `keys` | Array of all keys |
| `values` | Array of all values |
| `contains(key:)` | Check for string key |
| `contains(index:)` | Check for integer index |
| `toJSON(prettyPrint:)` | Export to JSON string |
| `toDictionary()` | Export to Swift dictionary |
| `toArray()` | Export to Swift array (if array-like) |

---

## Migration from 1.x

### Renamed APIs (Deprecated in 2.0)

| Old API | New API |
|---------|---------|
| `registerFunction("name") { ... }` | `register(function: "name") { ... }` |
| `registerEnum(MyEnum.self, as:)` | `register(enum: MyEnum.self, as:)` |
| `executeReturning("code", as: T.self)` | `execute("code", returning: T.self)` |
| `setPrintHandler { ... }` | `onPrint { ... }` |
| `setOutputHandler { ... }` | `onPrint { ... }` |
| `LuaEnumBridgeable` | `LuaBridgeableEnum` |

The old APIs still work but will emit deprecation warnings. Update your code to use the new APIs for future compatibility.

### Error Types

`LuaError` is now the primary error type. The following are deprecated:
- `LuaKitError` - Use `LuaError` instead
- `LuaErrorContext` - Use `LuaError.typeMismatch(expected:actual:context:)` for type errors

---

## Support

- **Issues**: [GitHub Issues](https://github.com/barryw/LuaKit/issues)
- **Documentation**: See the `docs/` folder for detailed guides

---

*LuaKit 2.0 - Seamless Swift-Lua Integration*
