# LuaState

The main entry point for Lua interaction in LuaKit. Manages the Lua runtime environment and provides methods for executing code, managing globals, and registering Swift types.

## Declaration

```swift
public final class LuaState
```

## Overview

`LuaState` represents a Lua interpreter instance. Each `LuaState` is independent and maintains its own global environment, loaded libraries, and registered types.

## Initialization

### init()

Creates a new Lua state with standard libraries loaded.

```swift
public init() throws
```

**Throws**: `LuaError.memoryAllocation` if the Lua state cannot be created.

**Example**:
```swift
do {
    let lua = try LuaState()
    // Use lua...
} catch {
    print("Failed to create Lua state: \(error)")
}
```

## Properties

### globals

Provides access to Lua global variables through a subscript interface.

```swift
public var globals: LuaGlobals { get }
```

**Example**:
```swift
// Set globals
lua.globals["playerName"] = "Alice"
lua.globals["score"] = 1000
lua.globals["isActive"] = true

// Get globals
let name: String? = lua.globals["playerName"]
let score: Int? = lua.globals["score"]
let active: Bool? = lua.globals["isActive"]
```

## Methods

### execute(_:)

Executes a Lua script and returns any output captured from print statements.

```swift
public func execute(_ code: String) throws -> String
```

**Parameters**:
- `code`: The Lua code to execute

**Returns**: String containing any output from print statements

**Throws**: 
- `LuaError.syntax` if the code has syntax errors
- `LuaError.runtime` if execution fails

**Example**:
```swift
let output = try lua.execute("""
    print("Hello from Lua!")
    for i = 1, 3 do
        print("Count: " .. i)
    end
""")
// output contains: "Hello from Lua!\nCount: 1\nCount: 2\nCount: 3\n"
```

### executeReturning(_:as:)

Executes Lua code and returns the result as a specific Swift type.

```swift
public func executeReturning<T: LuaConvertible>(_ code: String, as type: T.Type = T.self) throws -> T
```

**Parameters**:
- `code`: The Lua code to execute
- `type`: The expected return type (can be inferred)

**Returns**: The return value converted to the specified Swift type

**Throws**:
- `LuaError.syntax` if the code has syntax errors
- `LuaError.runtime` if execution fails
- `LuaError.typeMismatch` if the return value cannot be converted to the expected type

**Example**:
```swift
// Explicit type
let sum = try lua.executeReturning("return 10 + 20", as: Int.self)

// Inferred type
let message: String = try lua.executeReturning("return 'Hello, ' .. 'World!'")

// Array return
let numbers: [Int] = try lua.executeReturning("return {1, 2, 3, 4, 5}")
```

### register(_:as:)

Registers a Swift class to make it available in Lua.

```swift
public func register<T: LuaBridgeable>(_ type: T.Type, as name: String)
```

**Parameters**:
- `type`: The Swift class type to register (must conform to `LuaBridgeable`)
- `name`: The name to use for the class in Lua

**Example**:
```swift
@LuaBridgeable
class Player: LuaBridgeable {
    var name: String = ""
    var score: Int = 0
}

lua.register(Player.self, as: "Player")

try lua.execute("""
    local player = Player()
    player.name = "Alice"
    player.score = 100
""")
```

### registerFunction(_:_:)

Registers a Swift closure as a global Lua function.

```swift
// No parameters
public func registerFunction<R>(_ name: String, _ closure: @escaping () -> R)

// One parameter
public func registerFunction<T1, R>(_ name: String, _ closure: @escaping (T1) -> R) where T1: LuaConvertible

// Two parameters
public func registerFunction<T1, T2, R>(_ name: String, _ closure: @escaping (T1, T2) -> R) where T1: LuaConvertible, T2: LuaConvertible

// Three parameters
public func registerFunction<T1, T2, T3, R>(_ name: String, _ closure: @escaping (T1, T2, T3) -> R) where T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible
```

**Parameters**:
- `name`: The name for the function in Lua
- `closure`: The Swift closure to expose to Lua

**Example**:
```swift
// Simple function
lua.registerFunction("greet") { name in
    return "Hello, \(name)!"
}

// Math function
lua.registerFunction("add") { (a: Int, b: Int) in
    return a + b
}

// Use in Lua
try lua.execute("""
    print(greet("World"))  -- Output: Hello, World!
    print(add(5, 3))       -- Output: 8
""")
```

## Print Output Management

### setPrintBufferPolicy(_:)

Configures how print output is buffered and managed.

```swift
public func setPrintBufferPolicy(_ policy: PrintBufferPolicy)
```

**Parameters**:
- `policy`: The buffer management policy

**Print Buffer Policies**:
```swift
public enum PrintBufferPolicy {
    case unlimited              // No limit (default)
    case truncateOldest        // Keep newest output when limit reached
    case truncateNewest        // Keep oldest output when limit reached  
    case maxSize(Int)          // Limit total buffer size
}
```

### setOutputHandler(_:)

Sets a handler to receive print output immediately as it's generated.

```swift
public func setOutputHandler(_ handler: @escaping PrintOutputHandler)
```

**Parameters**:
- `handler`: Closure called with each print output

**Example**:
```swift
lua.setOutputHandler { output in
    // Handle output immediately (e.g., update UI)
    print("Lua says: \(output)")
}
```

### clearPrintBuffer()

Clears the accumulated print buffer.

```swift
public func clearPrintBuffer()
```

### getCurrentPrintBuffer()

Returns the current contents of the print buffer without executing any code.

```swift
public func getCurrentPrintBuffer() -> String
```

## Memory Management

`LuaState` automatically manages the Lua runtime lifecycle. When a `LuaState` instance is deallocated, it properly closes the Lua state and frees all associated resources.

### Reference Cycles

Be aware of potential reference cycles when:
- Lua holds references to Swift objects
- Swift objects hold references to the LuaState
- Closures capture self or the LuaState

**Best Practice**:
```swift
class GameEngine {
    let lua: LuaState
    
    init() throws {
        lua = try LuaState()
        
        // Use weak self to avoid cycles
        lua.registerFunction("callback") { [weak self] in
            self?.handleCallback()
        }
    }
}
```

## Thread Safety

`LuaState` is **not** thread-safe. All operations on a single `LuaState` instance must be performed from the same thread. If you need Lua functionality from multiple threads, create separate `LuaState` instances for each thread.

## Common Patterns

### Error Handling
```swift
do {
    let result = try lua.execute("potentially_failing_code()")
} catch LuaError.syntax(let message) {
    print("Syntax error: \(message)")
} catch LuaError.runtime(let message) {
    print("Runtime error: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Loading Scripts from Files
```swift
extension LuaState {
    func executeFile(_ path: String) throws -> String {
        let code = try String(contentsOfFile: path)
        return try execute(code)
    }
}
```

### Sandboxing
```swift
// Remove potentially dangerous functions
try lua.execute("""
    os.execute = nil
    io = nil
    loadfile = nil
    dofile = nil
""")
```