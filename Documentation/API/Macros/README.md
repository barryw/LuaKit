# LuaKit Macros

LuaKit provides several Swift macros to simplify Lua bridging and customize behavior.

## Available Macros

### [@LuaBridgeable](LuaBridgeable.md)
The primary macro for making Swift classes accessible from Lua. Automatically generates all necessary bridging code.

### [@LuaIgnore](LuaIgnore.md)
Excludes specific properties or methods from Lua bridging.

### [@LuaProperty](LuaProperty.md)
Customizes property behavior, including validation and custom accessors.

### [@LuaMethod](LuaMethod.md)
Customizes method bridging, including aliasing and parameter handling.

## Quick Reference

```swift
import Foundation
import Lua  // Required for generated code
import LuaKit

@LuaBridgeable
class MyClass: LuaBridgeable {
    // Basic property - automatically bridged
    var name: String = "Default"
    
    // Ignored property - not accessible from Lua
    @LuaIgnore
    var internalState: Int = 0
    
    // Property with validation
    @LuaProperty(validator: "validateAge")
    var age: Int = 0
    
    // Method with custom name in Lua
    @LuaMethod(name: "greet")
    func sayHello() -> String {
        return "Hello, \(name)!"
    }
    
    // Ignored method
    @LuaIgnore
    private func internalLogic() {
        // Not accessible from Lua
    }
    
    // Validation function for age property
    func validateAge(_ value: Any?) -> Bool {
        guard let age = value as? Int else { return false }
        return age >= 0 && age <= 150
    }
}
```

## Macro Requirements

1. **@LuaBridgeable Requirements**:
   - Must `import Lua` in your file
   - Class must explicitly conform to `LuaBridgeable` protocol
   - Works with classes (not structs or enums)

2. **Visibility**:
   - The macro recognizes `public` and `internal` members
   - `private` members are never bridged
   - Use `@LuaIgnore` to exclude public/internal members

3. **Supported Types**:
   - Properties: Bool, Int, Double, String, arrays, optionals, LuaBridgeable objects
   - Methods: Up to 3 parameters of LuaConvertible types

## Common Patterns

### Selective Bridging
```swift
@LuaBridgeable
class APIController: LuaBridgeable {
    // Public API for Lua
    var publicData: String = "accessible"
    
    // Internal implementation details
    @LuaIgnore
    var cache: [String: Any] = [:]
    
    @LuaIgnore
    var networkSession: URLSession = .shared
}
```

### Validated Properties
```swift
@LuaBridgeable
class Settings: LuaBridgeable {
    @LuaProperty(validator: "validateVolume")
    var volume: Double = 0.5
    
    func validateVolume(_ value: Any?) -> Bool {
        guard let vol = value as? Double else { return false }
        return vol >= 0.0 && vol <= 1.0
    }
}
```

### Method Aliases
```swift
@LuaBridgeable
class MathUtils: LuaBridgeable {
    @LuaMethod(name: "pow")
    func power(_ base: Double, _ exponent: Double) -> Double {
        return pow(base, exponent)
    }
}
```

## Troubleshooting

### "Use of unresolved identifier" in generated code
**Solution**: Add `import Lua` to your file

### "Type does not conform to protocol 'LuaBridgeable'"
**Solution**: Add explicit conformance: `class MyClass: LuaBridgeable`

### Properties/methods not visible from Lua
**Check**:
- Not marked with `@LuaIgnore`
- Not `private`
- Of a supported type
- Within method parameter limits (0-3 parameters)