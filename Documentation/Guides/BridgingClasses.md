# Bridging Swift Classes to Lua

This guide explains how to make your Swift classes accessible from Lua using the `@LuaBridgeable` macro.

## Basic Setup

### 1. Required Imports

Always include these imports when using `@LuaBridgeable`:

```swift
import Foundation
import Lua        // Required for generated code
import LuaKit
```

### 2. Basic Class Declaration

```swift
@LuaBridgeable
public class Person: LuaBridgeable {  // Must explicitly conform
    public var name: String
    public var age: Int
    
    public init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    
    public func greet() -> String {
        return "Hello, I'm \(name) and I'm \(age) years old."
    }
}
```

### 3. Register and Use

```swift
// Register the class
lua.register(Person.self, as: "Person")

// Use from Lua
try lua.execute("""
    local person = Person("Alice", 30)
    print(person:greet())
    
    person.age = 31
    print(person.name .. " is now " .. person.age .. " years old")
""")
```

## Property Types

### Supported Property Types

```swift
@LuaBridgeable
class DataTypes: LuaBridgeable {
    // Primitives
    var boolValue: Bool = true
    var intValue: Int = 42
    var doubleValue: Double = 3.14
    var stringValue: String = "Hello"
    
    // Arrays
    var stringArray: [String] = ["a", "b", "c"]
    var intArray: [Int] = [1, 2, 3]
    var doubleArray: [Double] = [1.1, 2.2, 3.3]
    var boolArray: [Bool] = [true, false, true]
    
    // Optionals
    var optionalString: String? = nil
    var optionalInt: Int? = 42
    
    // Objects
    var person: Person?  // Another LuaBridgeable class
}
```

### Property Access from Lua

```lua
local data = DataTypes()

-- Primitives
data.boolValue = false
data.intValue = 100
print(data.stringValue)  -- "Hello"

-- Arrays
data.stringArray = {"x", "y", "z"}
print(data.stringArray[1])  -- "x" (Lua arrays are 1-indexed)
print(#data.intArray)       -- 3 (array length)

-- Optionals
data.optionalString = "Now has value"
data.optionalInt = nil  -- Set to nil

-- Objects
data.person = Person("Bob", 25)
print(data.person:greet())
```

## Method Support

### Method Signatures

Methods can have 0-3 parameters and optional return values:

```swift
@LuaBridgeable
class Calculator: LuaBridgeable {
    // No parameters
    func getRandom() -> Double {
        return Double.random(in: 0...1)
    }
    
    // One parameter
    func square(_ n: Double) -> Double {
        return n * n
    }
    
    // Two parameters
    func add(_ a: Int, _ b: Int) -> Int {
        return a + b
    }
    
    // Three parameters
    func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(max, value))
    }
    
    // No return value
    func printResult(_ result: Double) {
        print("Result: \(result)")
    }
}
```

### Calling Methods from Lua

```lua
local calc = Calculator()

-- Call methods
local random = calc:getRandom()
local squared = calc:square(5)        -- 25
local sum = calc:add(10, 20)         -- 30
local clamped = calc:clamp(15, 0, 10) -- 10

-- Methods without return values
calc:printResult(squared)
```

## Property Observers

Track when Lua modifies your object properties:

```swift
@LuaBridgeable
class ObservableSettings: LuaBridgeable {
    var volume: Double = 0.5
    var difficulty: String = "normal"
    
    func luaPropertyWillChange(property: String, oldValue: Any?, newValue: Any?) {
        print("'\(property)' will change from \(oldValue ?? "nil") to \(newValue ?? "nil")")
    }
    
    func luaPropertyDidChange(property: String, from oldValue: Any?, to newValue: Any?) {
        switch property {
        case "volume":
            updateAudioSystem()
        case "difficulty":
            reconfigureGame()
        default:
            break
        }
    }
    
    private func updateAudioSystem() {
        print("Audio volume updated to \(volume)")
    }
    
    private func reconfigureGame() {
        print("Game difficulty changed to \(difficulty)")
    }
}
```

## Customization

### Excluding Members with @LuaIgnore

```swift
@LuaBridgeable
class SecureData: LuaBridgeable {
    var publicInfo: String = "This is visible"
    
    @LuaIgnore
    var secretKey: String = "This is hidden from Lua"
    
    @LuaIgnore
    private var internalState: Int = 0
    
    func publicMethod() -> String {
        return "Accessible from Lua"
    }
    
    @LuaIgnore
    func internalMethod() {
        // Not accessible from Lua
    }
}
```

### Property Validation

```swift
@LuaBridgeable
class ValidatedObject: LuaBridgeable {
    private var _score: Int = 0
    
    var score: Int {
        get { _score }
        set {
            // Validate in setter
            _score = max(0, min(100, newValue))
        }
    }
    
    @LuaProperty(validator: "validateName")
    var playerName: String = "Player"
    
    func validateName(_ value: Any?) -> Bool {
        guard let name = value as? String else { return false }
        return !name.isEmpty && name.count <= 20
    }
}
```

## Inheritance

Subclasses inherit Lua bridging:

```swift
@LuaBridgeable
class Vehicle: LuaBridgeable {
    var speed: Double = 0
    
    func accelerate() {
        speed += 10
    }
}

@LuaBridgeable
class Car: Vehicle {
    var fuel: Double = 100
    
    override func accelerate() {
        if fuel > 0 {
            super.accelerate()
            fuel -= 1
        }
    }
}
```

```lua
local car = Car()
car:accelerate()  -- Uses overridden method
print(car.speed)  -- 10
print(car.fuel)   -- 99
```

## Best Practices

### 1. Keep Bridged APIs Simple

```swift
// ❌ Avoid complex parameter types
func processData(_ config: [String: [String: Any]], 
                 options: Set<CustomOption>) -> Result<Data, Error>

// ✅ Use simple types
func processData(configPath: String, 
                 options: [String]) -> Bool
```

### 2. Validate Input from Lua

```swift
@LuaBridgeable
class FileManager: LuaBridgeable {
    func readFile(_ path: String) -> String? {
        // Validate path
        guard !path.contains("..") else {
            print("Invalid path: \(path)")
            return nil
        }
        
        // Safe to proceed
        return try? String(contentsOfFile: path)
    }
}
```

### 3. Handle Nil Appropriately

```swift
@LuaBridgeable
class Database: LuaBridgeable {
    func findUser(id: Int) -> User? {
        // Return nil if not found - Lua will get nil
        return users[id]
    }
    
    func getUserName(id: Int) -> String {
        // Provide default for non-optional return
        return users[id]?.name ?? "Unknown"
    }
}
```

### 4. Document Lua API

```swift
@LuaBridgeable
class GameAPI: LuaBridgeable {
    /// Creates a new game object at the specified position
    /// @param x The X coordinate (0-1000)
    /// @param y The Y coordinate (0-1000)
    /// @param type The object type ("enemy", "item", "obstacle")
    /// @return The created GameObject or nil if failed
    func createObject(x: Double, y: Double, type: String) -> GameObject? {
        // Implementation
    }
}
```

## Common Patterns

### Factory Pattern

```swift
@LuaBridgeable
class EntityFactory: LuaBridgeable {
    func createPlayer(name: String) -> Player {
        let player = Player()
        player.name = name
        player.health = 100
        return player
    }
    
    func createEnemy(type: String) -> Enemy? {
        switch type {
        case "goblin": return Goblin()
        case "dragon": return Dragon()
        default: return nil
        }
    }
}
```

### Event System

```swift
@LuaBridgeable
class EventManager: LuaBridgeable {
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

### Configuration Object

```swift
@LuaBridgeable
class Config: LuaBridgeable {
    var settings: [String: Any] = [:]
    
    func get(_ key: String) -> Any? {
        return settings[key]
    }
    
    func set(_ key: String, value: Any) {
        settings[key] = value
        saveToFile()  // Persist changes
    }
    
    func getInt(_ key: String, default defaultValue: Int) -> Int {
        return settings[key] as? Int ?? defaultValue
    }
}
```

## Troubleshooting

### "Type does not conform to protocol 'LuaBridgeable'"

Add explicit conformance:
```swift
@LuaBridgeable
class MyClass: LuaBridgeable {  // Don't forget this!
    // ...
}
```

### "Use of unresolved identifier" errors

Add `import Lua` to your file.

### Properties not accessible from Lua

Check that properties are:
- Not marked `private`
- Not marked with `@LuaIgnore`
- Of a supported type

### Methods not callable from Lua

Ensure methods:
- Have 3 or fewer parameters
- Use only `LuaConvertible` parameter types
- Are not marked with `@LuaIgnore`