# LuaKit API Reference

Complete API documentation for LuaKit v1.5.4.

## Core Classes

### [LuaState](LuaState.md)
The main entry point for Lua interaction. Manages the Lua runtime and provides methods for executing code and managing globals.

### [LuaValue](LuaValue.md)
Type-safe wrapper for Lua values, supporting conversion between Swift and Lua types.

### [LuaBridgeable](LuaBridgeable.md)
Protocol for Swift classes that can be bridged to Lua. Used with the `@LuaBridgeable` macro.

### [LuaFunction](LuaFunction.md)
Enables Swift closures to be called from Lua code.

### [LuaError](LuaError.md)
Error types thrown by LuaKit operations.

## Protocols

### [LuaConvertible](LuaConvertible.md)
Protocol for types that can be converted between Swift and Lua.

### [LuaPropertyObserver](LuaPropertyObserver.md)
Optional protocol for observing property changes on bridged objects.

## Macros

### [@LuaBridgeable](Macros/LuaBridgeable.md)
Swift macro that automatically generates Lua bridging code for your classes.

### [@LuaProperty](Macros/LuaProperty.md)
Customize property bridging behavior.

### [@LuaMethod](Macros/LuaMethod.md)
Customize method bridging behavior.

### [@LuaIgnore](Macros/LuaIgnore.md)
Exclude properties or methods from Lua bridging.

## Type Bridging

### [Supported Types](TypeBridging.md)
- Primitive types (Bool, Int, Double, String)
- Arrays of supported types
- Dictionaries with String keys
- Optional values
- LuaBridgeable objects

### [Custom Type Conversion](CustomTypes.md)
How to implement custom type conversions.

## Advanced Features

### [Property Change Notifications](PropertyNotifications.md)
Track when Lua modifies Swift object properties.

### [Array Proxy](ArrayProxy.md)
Efficient array bridging with element access.

### [Global Variables](Globals.md)
Managing Lua global variables from Swift.

### [Tables](Tables.md)
Working with Lua tables.

### [Error Handling](ErrorHandling.md)
Comprehensive error handling strategies.

### [Memory Management](MemoryManagement.md)
Understanding reference cycles and memory management.

### [Performance](Performance.md)
Performance considerations and optimization tips.

## Quick Reference

### Creating a Lua State
```swift
let lua = try LuaState()
```

### Executing Lua Code
```swift
let result = try lua.execute("return 1 + 2")
```

### Registering a Class
```swift
lua.register(MyClass.self, as: "MyClass")
```

### Setting Globals
```swift
lua.globals["myVar"] = 42
```

### Getting Globals
```swift
let value: Int? = lua.globals["myVar"]
```