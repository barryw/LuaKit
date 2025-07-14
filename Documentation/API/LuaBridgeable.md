# LuaBridgeable

Protocol that enables Swift classes to be used from Lua code. Used in conjunction with the `@LuaBridgeable` macro for automatic implementation.

## Declaration

```swift
public protocol LuaBridgeable: AnyObject {
    static func register(in lua: LuaState, as name: String)
    static func push(_ object: LuaBridgeable, to L: OpaquePointer)
    static func pull(from L: OpaquePointer, at index: Int32) -> Self?
}
```

## Overview

`LuaBridgeable` is the core protocol that enables Swift classes to be accessible from Lua. While you can implement this protocol manually, it's strongly recommended to use the `@LuaBridgeable` macro which generates the implementation automatically.

## Using @LuaBridgeable Macro (Recommended)

```swift
import Foundation
import Lua  // Required for generated code
import LuaKit

@LuaBridgeable
public class Person: LuaBridgeable {  // Must explicitly conform
    public var name: String
    public var age: Int
    
    public init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    
    public func greet() -> String {
        return "Hello, I'm \(name)!"
    }
}
```

### Important Requirements

1. **Import `Lua`** - The generated code requires the Lua module
2. **Explicit conformance** - Add `: LuaBridgeable` after your class declaration
3. **Supported members** - The macro recognizes `public` and `internal` properties/methods

## Property Support

### Supported Property Types

- **Primitives**: `Bool`, `Int`, `Double`, `String`
- **Arrays**: `[String]`, `[Int]`, `[Double]`, `[Bool]`
- **Optionals**: Any supported type wrapped in Optional
- **Objects**: Other `LuaBridgeable` classes

### Property Access from Lua

```swift
@LuaBridgeable
class GameItem: LuaBridgeable {
    var name: String = "Sword"
    var damage: Int = 10
    var magical: Bool = false
    var enchantments: [String] = []
}
```

```lua
-- Create and use from Lua
local item = GameItem()
print(item.name)        -- "Sword"
item.damage = 15
item.magical = true
item.enchantments = {"Fire", "Ice"}
```

## Method Support

### Supported Method Signatures

Methods can have:
- 0-3 parameters of `LuaConvertible` types
- Return types that are `LuaConvertible` or `Void`

```swift
@LuaBridgeable
class Calculator: LuaBridgeable {
    func add(_ a: Int, _ b: Int) -> Int {
        return a + b
    }
    
    func multiply(_ a: Double, _ b: Double) -> Double {
        return a * b
    }
    
    func formatResult(_ value: Double, prefix: String) -> String {
        return "\(prefix): \(value)"
    }
}
```

### Method Calls from Lua

```lua
local calc = Calculator()
local sum = calc:add(5, 3)                    -- 8
local product = calc:multiply(2.5, 4.0)       -- 10.0
local formatted = calc:formatResult(42, "Result")  -- "Result: 42"
```

## Property Change Notifications

Classes can optionally implement methods to observe property changes:

```swift
@LuaBridgeable
class ObservableObject: LuaBridgeable {
    var value: Int = 0
    
    // Called before property changes
    func luaPropertyWillChange(property: String, oldValue: Any?, newValue: Any?) {
        print("Property '\(property)' will change from \(oldValue ?? "nil") to \(newValue ?? "nil")")
    }
    
    // Called after property changes
    func luaPropertyDidChange(property: String, from oldValue: Any?, to newValue: Any?) {
        print("Property '\(property)' changed from \(oldValue ?? "nil") to \(newValue ?? "nil")")
    }
}
```

## Customization with Attributes

### @LuaIgnore

Exclude properties or methods from Lua:

```swift
@LuaBridgeable
class SecureObject: LuaBridgeable {
    var publicData: String = "visible"
    
    @LuaIgnore
    var privateData: String = "hidden"
    
    @LuaIgnore
    func internalMethod() {
        // Not accessible from Lua
    }
}
```

### @LuaProperty

Customize property behavior:

```swift
@LuaBridgeable
class ValidatedObject: LuaBridgeable {
    @LuaProperty(validator: "validateAge")
    var age: Int = 0
    
    func validateAge(_ value: Any?) -> Bool {
        guard let age = value as? Int else { return false }
        return age >= 0 && age <= 150
    }
}
```

## Memory Management

### Reference Cycles

Be aware of potential reference cycles:

```swift
@LuaBridgeable
class Node: LuaBridgeable {
    var parent: Node?  // Weak reference recommended
    var children: [Node] = []
}
```

### Best Practices

1. Use weak references for parent/child relationships
2. Clear Lua references when done
3. Avoid storing LuaState in bridged objects

## Performance Considerations

### Property Access

Each property access from Lua involves:
1. Method lookup in metatable
2. Type conversion
3. Actual property get/set

For performance-critical code, consider:
- Batching property updates
- Using methods instead of many property accesses
- Caching frequently accessed values in Lua

### Method Calls

Method calls are generally efficient, but consider:
- Parameter count affects performance
- Return value conversion has overhead
- Avoid frequent calls in tight loops

## Manual Implementation

While not recommended, you can implement `LuaBridgeable` manually:

```swift
public class ManualBridged: LuaBridgeable {
    var value: Int = 0
    
    public static func register(in lua: LuaState, as name: String) {
        // Create metatable
        // Register methods
        // Set up property access
    }
    
    public static func push(_ object: LuaBridgeable, to L: OpaquePointer) {
        // Push object to Lua stack
    }
    
    public static func pull(from L: OpaquePointer, at index: Int32) -> Self? {
        // Pull object from Lua stack
    }
}
```

## Common Patterns

### Factory Pattern

```swift
@LuaBridgeable
class ItemFactory: LuaBridgeable {
    func createWeapon(name: String, damage: Int) -> Weapon {
        let weapon = Weapon()
        weapon.name = name
        weapon.damage = damage
        return weapon
    }
}
```

### Builder Pattern

```swift
@LuaBridgeable
class CharacterBuilder: LuaBridgeable {
    private var character = Character()
    
    func withName(_ name: String) -> CharacterBuilder {
        character.name = name
        return self
    }
    
    func withClass(_ className: String) -> CharacterBuilder {
        character.className = className
        return self
    }
    
    func build() -> Character {
        return character
    }
}
```

## Troubleshooting

### "Type 'X' does not conform to protocol 'LuaBridgeable'"

**Solution**: Explicitly add `: LuaBridgeable` to your class declaration

### "Use of unresolved identifier" in generated code

**Solution**: Add `import Lua` to your file

### Properties not visible from Lua

**Possible causes**:
- Property is `private` (only `public` and `internal` are bridged)
- Property has `@LuaIgnore` attribute
- Property type is not supported

### Method not callable from Lua

**Possible causes**:
- Method is `private`
- Method has `@LuaIgnore` attribute
- Method signature not supported (too many parameters, unsupported types)