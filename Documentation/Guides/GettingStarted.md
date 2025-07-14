# Getting Started with LuaKit

This guide will walk you through the basics of using LuaKit to add Lua scripting to your Swift application.

## Installation

Add LuaKit to your Swift package dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit", from: "1.5.4")
]
```

Then add it to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["LuaKit"]
)
```

## Basic Usage

### 1. Import and Create a Lua State

```swift
import LuaKit

// Create a Lua interpreter instance
let lua = try LuaState()
```

### 2. Execute Lua Code

```swift
// Execute simple Lua code
let output = try lua.execute("""
    print("Hello from Lua!")
    return 42
""")
print("Output: \(output)")
```

### 3. Work with Global Variables

```swift
// Set Swift values as Lua globals
lua.globals["playerName"] = "Alice"
lua.globals["score"] = 1000
lua.globals["items"] = ["sword", "shield", "potion"]

// Execute Lua code that uses these globals
try lua.execute("""
    print("Player: " .. playerName)
    print("Score: " .. score)
    print("First item: " .. items[1])
""")

// Get values back from Lua
let updatedScore: Int? = lua.globals["score"]
```

### 4. Bridge Swift Classes to Lua

The most powerful feature of LuaKit is the ability to use Swift classes from Lua:

```swift
import Foundation
import Lua  // Required for generated code
import LuaKit

@LuaBridgeable
class GameCharacter: LuaBridgeable {
    var name: String
    var health: Int = 100
    var items: [String] = []
    
    init(name: String) {
        self.name = name
    }
    
    func attack(_ target: GameCharacter) {
        target.health -= 10
        print("\(name) attacks \(target.name)!")
    }
    
    func heal(_ amount: Int) {
        health = min(health + amount, 100)
        print("\(name) healed for \(amount) points")
    }
}

// Register the class with Lua
lua.register(GameCharacter.self, as: "Character")

// Use it from Lua
try lua.execute("""
    -- Create characters
    local hero = Character("Hero")
    local enemy = Character("Goblin")
    
    -- Use properties and methods
    hero:attack(enemy)
    print(enemy.name .. " health: " .. enemy.health)
    
    enemy:heal(5)
    print(enemy.name .. " health: " .. enemy.health)
    
    -- Add items
    hero.items = {"sword", "shield"}
    print("Hero has " .. #hero.items .. " items")
""")
```

### 5. Register Swift Functions

You can expose Swift functions to Lua:

```swift
// Simple function
lua.registerFunction("calculateDamage") { (baseDamage: Int, multiplier: Double) in
    return Int(Double(baseDamage) * multiplier)
}

// Function with string manipulation
lua.registerFunction("formatMessage") { (template: String, name: String) in
    return template.replacingOccurrences(of: "{name}", with: name)
}

// Use them from Lua
try lua.execute("""
    local damage = calculateDamage(10, 1.5)
    print("Damage dealt: " .. damage)
    
    local message = formatMessage("Welcome, {name}!", "Alice")
    print(message)
""")
```

## Common Patterns

### Configuration Files

```swift
// config.lua
let configScript = """
return {
    game = {
        title = "My Awesome Game",
        version = "1.0.0",
        difficulty = "normal"
    },
    graphics = {
        resolution = {width = 1920, height = 1080},
        fullscreen = false,
        vsync = true
    }
}
"""

// Load configuration
let config: [String: Any] = try lua.executeReturning(configScript)
```

### Event Handlers

```swift
@LuaBridgeable
class EventSystem: LuaBridgeable {
    private var handlers: [String: LuaFunction] = [:]
    
    func on(_ event: String, handler: LuaFunction) {
        handlers[event] = handler
    }
    
    func trigger(_ event: String, data: Any? = nil) {
        // Call Lua handler
        handlers[event]?.call(with: data)
    }
}
```

### Error Handling

```swift
do {
    try lua.execute("potentially_failing_code()")
} catch LuaError.syntax(let message) {
    print("Syntax error: \(message)")
    // Show error to user
} catch LuaError.runtime(let message) {
    print("Runtime error: \(message)")
    // Handle runtime error
} catch {
    print("Unexpected error: \(error)")
}
```

## Next Steps

- [Bridging Classes](BridgingClasses.md) - Deep dive into the @LuaBridgeable macro
- [Working with Functions](Functions.md) - Advanced function bridging
- [Error Handling](ErrorHandling.md) - Comprehensive error handling
- [Performance Tips](../API/Performance.md) - Optimization guidelines
- [Examples](../../Examples/) - Complete example projects

## Tips

1. **Always import `Lua`** when using `@LuaBridgeable` - the generated code requires it
2. **Explicitly conform to `LuaBridgeable`** after the macro: `class MyClass: LuaBridgeable`
3. **Use property observers** to track when Lua modifies your objects
4. **Be mindful of reference cycles** between Swift and Lua objects
5. **Validate user scripts** before execution in production environments