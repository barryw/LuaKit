# Closure Bridging in LuaKit

LuaKit 1.2.0 introduces closure bridging functionality, allowing you to pass Swift closures to Lua as callable functions.

## Basic Usage

### Simple Closures

```swift
import LuaKit

let lua = try LuaState()

// Register a simple closure with no parameters
lua.globals["getCurrentTime"] = LuaFunction {
    return Date().timeIntervalSince1970
}

// Use from Lua
try lua.execute("print('Current time:', getCurrentTime())")
```

### Closures with Parameters

```swift
// Register a closure with parameters
lua.globals["formatName"] = LuaFunction { (first: String, last: String) in
    return "\(first) \(last)"
}

// Register using convenience method
lua.registerFunction("multiply") { (a: Int, b: Int) in
    return a * b
}

try lua.execute("""
    print(formatName("John", "Doe"))     -- "John Doe"
    print("6 × 7 =", multiply(6, 7))     -- "6 × 7 = 42"
""")
```

### Returning Swift Objects

```swift
@LuaBridgeable
class Point: LuaBridgeable {
    public var x: Double
    public var y: Double
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

lua.register(Point.self, as: "Point")

// Closure that returns a Swift object
lua.registerFunction("midpoint") { (x1: Double, y1: Double, x2: Double, y2: Double) in
    return Point(x: (x1 + x2) / 2, y: (y1 + y2) / 2)
}

try lua.execute("""
    local mid = midpoint(0, 0, 10, 10)
    print("Midpoint:", mid.x, mid.y)     -- "Midpoint: 5.0 5.0"
""")
```

## Supported Features

### Parameter Types
- Basic types: `Int`, `Double`, `String`, `Bool`
- Optional types: `String?`, `Int?`, etc.
- LuaBridgeable objects

### Return Types
- Basic types: `Int`, `Double`, `String`, `Bool`
- `Void` (no return value)
- Optional types
- LuaBridgeable objects
- Arrays of basic types (through LuaConvertible)

### Convenience Methods

LuaKit provides `registerFunction` methods for common cases:

```swift
// No parameters
lua.registerFunction("getName") {
    return "LuaKit"
}

// 1 parameter
lua.registerFunction("double") { (n: Int) in
    return n * 2
}

// 2 parameters
lua.registerFunction("max") { (a: Int, b: Int) in
    return a > b ? a : b
}

// 3 parameters
lua.registerFunction("clamp") { (value: Double, min: Double, max: Double) in
    return Swift.max(min, Swift.min(max, value))
}
```

## Advanced Usage

### Closures in Tables

```swift
let mathTable = lua.createTable()
mathTable["add"] = LuaFunction { (a: Int, b: Int) in a + b }
mathTable["subtract"] = LuaFunction { (a: Int, b: Int) in a - b }
mathTable["multiply"] = LuaFunction { (a: Int, b: Int) in a * b }
mathTable["divide"] = LuaFunction { (a: Double, b: Double) in a / b }

lua.globals.set("math2", to: mathTable)

try lua.execute("""
    print(math2.add(10, 5))          -- 15
    print(math2.subtract(10, 5))     -- 5
    print(math2.multiply(10, 5))     -- 50
    print(math2.divide(10, 5))       -- 2.0
""")
```

### Error Handling

```swift
lua.registerFunction("safeDivide") { (a: Double, b: Double) -> Double? in
    return b != 0 ? a / b : nil
}

try lua.execute("""
    local result = safeDivide(10, 0)
    if result == nil then
        print("Division by zero!")
    else
        print("Result:", result)
    end
""")
```

## Limitations

1. **Maximum 3 parameters**: Currently supports closures with 0-3 parameters. More can be added if needed.

2. **Type requirements**: Parameters must conform to `LuaConvertible` or be basic types.

3. **No automatic closure detection**: Closures must be explicitly wrapped in `LuaFunction`.

4. **Closure properties in @LuaBridgeable**: The macro doesn't yet support closure properties. Use manual registration for classes with closure properties.

## Example: Event Handling

```swift
// Create an event system
let events = lua.createTable()
var handlers: [String: [LuaFunction]] = [:]

lua.registerFunction("on") { (event: String, handler: LuaFunction) in
    if handlers[event] == nil {
        handlers[event] = []
    }
    handlers[event]?.append(handler)
}

lua.registerFunction("emit") { (event: String, data: String) in
    if let eventHandlers = handlers[event] {
        for handler in eventHandlers {
            // In practice, you'd call the handler with the data
            print("Would call handler for \(event) with data: \(data)")
        }
    }
}

// This example shows the concept - actual implementation would need
// to properly handle calling Lua functions from Swift
```

## Best Practices

1. **Use type-safe parameters**: Always specify parameter types explicitly for better error messages.

2. **Handle optionals properly**: Return optionals for operations that might fail.

3. **Keep closures simple**: Complex logic should be in regular methods, with thin closure wrappers.

4. **Document parameter expectations**: Lua is dynamically typed, so document what types your closures expect.

5. **Consider performance**: Closure bridging has overhead. For performance-critical code, consider using the C API directly.