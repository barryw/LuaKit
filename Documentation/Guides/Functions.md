# Working with Functions in LuaKit

This guide covers how to bridge functions between Swift and Lua, enabling powerful interoperability between the two languages.

## Swift Functions in Lua

### Registering Global Functions

LuaKit allows you to expose Swift functions as global Lua functions:

```swift
// Simple function with return value
lua.registerFunction("add") { (a: Int, b: Int) in
    return a + b
}

// Function with string manipulation
lua.registerFunction("greet") { (name: String) in
    return "Hello, \(name)!"
}

// Function with no parameters
lua.registerFunction("getRandomNumber") {
    return Int.random(in: 1...100)
}

// Use in Lua
try lua.execute("""
    print(add(5, 3))                    -- Output: 8
    print(greet("World"))               -- Output: Hello, World!
    print(getRandomNumber())            -- Output: (random number)
""")
```

### Function Parameter Limits

Currently, registered functions support 0-3 parameters:

```swift
// No parameters
lua.registerFunction("getCurrentTime") {
    return Date().timeIntervalSince1970
}

// One parameter
lua.registerFunction("double") { (n: Int) in
    return n * 2
}

// Two parameters
lua.registerFunction("power") { (base: Double, exponent: Double) in
    return pow(base, exponent)
}

// Three parameters
lua.registerFunction("clamp") { (value: Double, min: Double, max: Double) in
    return Swift.max(min, Swift.min(max, value))
}
```

### Supported Parameter Types

Function parameters must conform to `LuaConvertible`:
- `Bool`
- `Int`
- `Double`
- `String`
- Arrays of the above types
- Other `LuaBridgeable` objects

## Lua Functions in Swift

### Using LuaFunction

The `LuaFunction` class wraps Swift closures for use in Lua:

```swift
import LuaKit

// Create a function that can be stored in Lua
let myFunction = LuaFunction { (x: Int, y: Int) in
    return x + y
}

// Pass to Lua
lua.globals["myAdd"] = myFunction

// Use in Lua
try lua.execute("""
    local result = myAdd(10, 20)
    print(result)  -- Output: 30
""")
```

### Functions as Properties

You can add function properties to your bridged classes:

```swift
@LuaBridgeable
class MathHelper: LuaBridgeable {
    // Function property
    let calculate = LuaFunction { (op: String, a: Double, b: Double) in
        switch op {
        case "+": return a + b
        case "-": return a - b
        case "*": return a * b
        case "/": return b != 0 ? a / b : 0
        default: return 0
        }
    }
    
    // Regular method
    func simpleAdd(_ a: Int, _ b: Int) -> Int {
        return a + b
    }
}
```

```lua
local math = MathHelper()

-- Call function property
local result1 = math.calculate("+", 10, 5)  -- 15

-- Call regular method
local result2 = math:simpleAdd(10, 5)       -- 15
```

## Callbacks and Event Handlers

### Simple Callbacks

```swift
@LuaBridgeable
class Button: LuaBridgeable {
    private var clickHandler: LuaFunction?
    
    func onClick(_ handler: LuaFunction) {
        self.clickHandler = handler
    }
    
    func click() {
        // Trigger the Lua callback
        clickHandler?.call()
    }
}
```

```lua
local button = Button()

button:onClick(function()
    print("Button was clicked!")
end)

button:click()  -- Output: Button was clicked!
```

### Callbacks with Parameters

```swift
@LuaBridgeable
class EventEmitter: LuaBridgeable {
    private var handlers: [String: [LuaFunction]] = [:]
    
    func on(_ event: String, handler: LuaFunction) {
        handlers[event, default: []].append(handler)
    }
    
    func emit(_ event: String, data: Any? = nil) {
        for handler in handlers[event] ?? [] {
            handler.call(with: data)
        }
    }
}
```

```lua
local emitter = EventEmitter()

emitter:on("data", function(value)
    print("Received data: " .. tostring(value))
end)

emitter:emit("data", 42)        -- Output: Received data: 42
emitter:emit("data", "hello")    -- Output: Received data: hello
```

## Advanced Patterns

### Higher-Order Functions

```swift
lua.registerFunction("map") { (array: [Int], transform: LuaFunction) -> [Int] in
    return array.map { element in
        transform.call(with: element) as? Int ?? 0
    }
}

lua.registerFunction("filter") { (array: [Int], predicate: LuaFunction) -> [Int] in
    return array.filter { element in
        predicate.call(with: element) as? Bool ?? false
    }
}
```

```lua
-- Map example
local numbers = {1, 2, 3, 4, 5}
local doubled = map(numbers, function(x) return x * 2 end)
-- doubled = {2, 4, 6, 8, 10}

-- Filter example
local evens = filter(numbers, function(x) return x % 2 == 0 end)
-- evens = {2, 4}
```

### Async Operations

```swift
@LuaBridgeable
class AsyncOperations: LuaBridgeable {
    func fetchData(_ callback: LuaFunction) {
        // Simulate async operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let data = ["status": "success", "value": 42]
            callback.call(with: data)
        }
    }
    
    func delay(_ seconds: Double, callback: LuaFunction) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            callback.call()
        }
    }
}
```

```lua
local async = AsyncOperations()

async:fetchData(function(data)
    print("Received: " .. data.status)  -- After 1 second
end)

async:delay(2, function()
    print("2 seconds have passed!")
end)
```

### Function Factories

```swift
lua.registerFunction("createMultiplier") { (factor: Int) -> LuaFunction in
    return LuaFunction { (value: Int) in
        return value * factor
    }
}
```

```lua
local double = createMultiplier(2)
local triple = createMultiplier(3)

print(double(5))   -- 10
print(triple(5))   -- 15
```

## Error Handling in Functions

### Returning Optionals

```swift
lua.registerFunction("safeDivide") { (a: Double, b: Double) -> Double? in
    guard b != 0 else { return nil }
    return a / b
}
```

```lua
local result = safeDivide(10, 2)   -- 5
local invalid = safeDivide(10, 0)  -- nil

if invalid == nil then
    print("Cannot divide by zero")
end
```

### Error Propagation

```swift
@LuaBridgeable
class FileReader: LuaBridgeable {
    func readFile(_ path: String, onSuccess: LuaFunction, onError: LuaFunction) {
        do {
            let content = try String(contentsOfFile: path)
            onSuccess.call(with: content)
        } catch {
            onError.call(with: error.localizedDescription)
        }
    }
}
```

```lua
local reader = FileReader()

reader:readFile("/path/to/file",
    function(content)
        print("File content: " .. content)
    end,
    function(error)
        print("Error: " .. error)
    end
)
```

## Performance Considerations

### Function Call Overhead

Each function call between Swift and Lua involves:
1. Parameter conversion (Swift → Lua or Lua → Swift)
2. Stack manipulation
3. Return value conversion

For performance-critical code:
- Minimize the number of cross-language calls
- Batch operations when possible
- Consider moving hot loops entirely to one language

### Caching Functions

```swift
// Less efficient - function created each call
lua.execute("result = calculate(function(x) return x * 2 end, 5)")

// More efficient - function cached
lua.execute("""
    local double = function(x) return x * 2 end
    result = calculate(double, 5)
""")
```

## Best Practices

### 1. Type Safety

Always validate inputs from Lua:

```swift
lua.registerFunction("processNumber") { (value: Any) -> String in
    guard let number = value as? Double else {
        return "Error: Expected number"
    }
    return "Processed: \(number)"
}
```

### 2. Memory Management

Be careful with captured references:

```swift
class DataProcessor {
    func setupLua(_ lua: LuaState) {
        // ❌ Captures self strongly
        lua.registerFunction("process") { [self] data in
            self.processData(data)
        }
        
        // ✅ Weak capture prevents cycles
        lua.registerFunction("process") { [weak self] data in
            self?.processData(data) ?? "Processor deallocated"
        }
    }
}
```

### 3. Documentation

Document your Lua API:

```swift
/// Calculates the distance between two points
/// @param x1 The x-coordinate of the first point
/// @param y1 The y-coordinate of the first point
/// @param x2 The x-coordinate of the second point
/// @param y2 The y-coordinate of the second point
/// @return The Euclidean distance between the points
lua.registerFunction("distance") { (x1: Double, y1: Double, x2: Double, y2: Double) in
    let dx = x2 - x1
    let dy = y2 - y1
    return sqrt(dx * dx + dy * dy)
}
```

## Next Steps

- Explore [Closure Bridging Example](../../Examples/ClosureBridgingExample.swift) for more patterns
- Learn about [Error Handling](ErrorHandling.md) with functions
- See [API Reference](../API/LuaFunction.md) for complete details