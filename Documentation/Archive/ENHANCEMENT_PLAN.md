# LuaKit Enhancement Implementation Plan

## Overview

This document provides a detailed implementation plan for 15 LuaKit enhancements, organized by complexity, dependencies, and implementation approach. Since the specific enhancement requests were not provided, this plan covers the most valuable improvements based on the current codebase analysis.

## Enhancement Categories

### 1. Type System Enhancements

#### 1.1 Dictionary/Map Support
**Priority**: High  
**Complexity**: Medium  
**Type**: Runtime Library + Macro

**Implementation**:
- **Macro Changes**: Add dictionary property detection and code generation
- **Runtime Library**: Create `LuaDictionaryProxy` similar to `LuaArrayProxy`
- **New Types**: `LuaDictionaryProxy<Key: Hashable, Value: LuaBridgeable>`
- **Breaking Changes**: None

```swift
// Example usage after implementation
@LuaBridgeable
class Config {
    var settings: [String: String] = [:]
    var scores: [String: Int] = [:]
}
```

#### 1.2 Optional Type Support
**Priority**: High  
**Complexity**: Low  
**Type**: Runtime Library + Macro

**Implementation**:
- **Macro Changes**: Detect optional properties and generate nil-handling code
- **Runtime Library**: Extend `LuaValue` to handle nil conversions
- **Breaking Changes**: None

#### 1.3 Enum Support
**Priority**: Medium  
**Complexity**: Medium  
**Type**: Macro + Runtime

**Implementation**:
- **Macro Changes**: Generate enum case mappings
- **Runtime Library**: Add `LuaEnumBridgeable` protocol
- **New Protocol**: `protocol LuaEnumBridgeable: RawRepresentable where RawValue: LuaBridgeable`

### 2. Method & Function Enhancements

#### 2.1 Variadic Function Support
**Priority**: Low  
**Complexity**: High  
**Type**: Runtime Library

**Implementation**:
- **Runtime Library**: Extend `LuaFunction` to handle variable arguments
- **Breaking Changes**: None, but requires careful stack management

#### 2.2 Async/Await Support
**Priority**: High  
**Complexity**: High  
**Type**: Runtime Library + Macro

**Implementation**:
- **Macro Changes**: Detect async methods and generate wrapper code
- **Runtime Library**: Add coroutine support for async operations
- **New Types**: `LuaAsyncFunction`, `LuaCoroutine`
- **Dependencies**: Requires Lua coroutine integration

#### 2.3 Method Overloading
**Priority**: Low  
**Complexity**: Very High  
**Type**: Macro + Runtime

**Implementation**:
- **Macro Changes**: Generate disambiguation logic
- **Runtime Library**: Dynamic method resolution based on argument types
- **Breaking Changes**: Potential ambiguity in existing code

### 3. Protocol & Inheritance Support

#### 3.1 Protocol Conformance Bridging
**Priority**: Medium  
**Complexity**: High  
**Type**: Macro

**Implementation**:
- **Macro Changes**: Detect protocol conformances and expose methods
- **New Attributes**: `@LuaProtocol` for explicit protocol exposure
- **Breaking Changes**: None

#### 3.2 Class Inheritance Support
**Priority**: Medium  
**Complexity**: Medium  
**Type**: Macro + Runtime

**Implementation**:
- **Macro Changes**: Generate parent class method lookups
- **Runtime Library**: Metatable inheritance chain
- **Breaking Changes**: None

### 4. Advanced Features

#### 4.1 Custom Operators
**Priority**: Low  
**Complexity**: Medium  
**Type**: Runtime Library

**Implementation**:
- **Runtime Library**: Register custom metamethods
- **New Protocol**: `LuaOperatorBridgeable`
- **Example**: Enable `+`, `-`, `*` for custom types

#### 4.2 Computed Properties
**Priority**: Medium  
**Complexity**: Low  
**Type**: Macro

**Implementation**:
- **Macro Changes**: Detect and bridge computed properties
- **Breaking Changes**: None

#### 4.3 Property Observers (willSet/didSet)
**Priority**: Low  
**Complexity**: Medium  
**Type**: Macro

**Implementation**:
- **Macro Changes**: Generate wrapper code for property observers
- **Integration**: Works with existing property change notifications

### 5. Memory & Performance

#### 5.1 Weak References
**Priority**: High  
**Complexity**: Medium  
**Type**: Runtime Library

**Implementation**:
- **Runtime Library**: Add weak reference support in userdata
- **New Types**: `LuaWeakRef<T>`
- **Use Case**: Prevent retain cycles in callbacks

#### 5.2 Lazy Loading
**Priority**: Low  
**Complexity**: Medium  
**Type**: Runtime Library

**Implementation**:
- **Runtime Library**: Defer object creation until accessed
- **New Attributes**: `@LuaLazy`

### 6. Developer Experience

#### 6.1 Better Error Messages
**Priority**: High  
**Complexity**: Low  
**Type**: Runtime Library + Macro

**Implementation**:
- **Macro Changes**: Generate more descriptive error contexts
- **Runtime Library**: Enhanced error reporting with Swift context
- **Breaking Changes**: None

#### 6.2 Debug Mode
**Priority**: Medium  
**Complexity**: Low  
**Type**: Runtime Library

**Implementation**:
- **Runtime Library**: Add verbose logging option
- **New API**: `lua.debugMode = true`

#### 6.3 Type Validation
**Priority**: Medium  
**Complexity**: Medium  
**Type**: Macro

**Implementation**:
- **Macro Changes**: Generate runtime type validation
- **New Attributes**: `@LuaValidate`

### 7. Additional Type Support

#### 7.1 Generic Type Support
**Priority**: Low  
**Complexity**: Very High  
**Type**: Macro + Runtime

**Implementation**:
- **Macro Changes**: Detect and handle generic type parameters
- **Runtime Library**: Dynamic type resolution
- **New Protocol**: `LuaGenericBridgeable<T>`
- **Example**: `class Container<T: LuaBridgeable>`

#### 7.2 Tuple Support
**Priority**: Low  
**Complexity**: Medium  
**Type**: Runtime Library

**Implementation**:
- **Runtime Library**: Convert Swift tuples to Lua tables
- **Macro Changes**: Detect tuple return types
- **Example**: `func getCoordinates() -> (x: Int, y: Int)`

### 8. Method Enhancements

#### 8.1 Closure Type Validation
**Priority**: Medium  
**Complexity**: Medium  
**Type**: Runtime Library

**Implementation**:
- **Runtime Library**: Runtime validation of closure parameters
- **Better error messages for type mismatches
- **Support for more parameter types

#### 8.2 Method Aliasing
**Priority**: Medium  
**Complexity**: Low  
**Type**: Macro

**Implementation**:
- **New Attribute**: `@LuaMethod(name: "customName")`
- **Macro Changes**: Use custom names in method registration
- **Example**: `@LuaMethod(name: "get_size") func getSize()`

### 9. Performance & Monitoring

#### 9.1 Performance Monitoring
**Priority**: Low  
**Complexity**: Medium  
**Type**: Runtime Library

**Implementation**:
- **Runtime Library**: Add performance tracking
- **New API**: `lua.performanceMetrics`
- **Metrics**: Call counts, execution time, memory usage

## Implementation Phases

### Phase 1: Core Type System (Week 1-2)
1. Dictionary/Map Support
2. Optional Type Support
3. Better Error Messages

### Phase 2: Advanced Types (Week 3-4)
1. Enum Support
2. Computed Properties
3. Weak References

### Phase 3: Async & Methods (Week 5-6)
1. Async/Await Support
2. Protocol Conformance
3. Class Inheritance

### Phase 4: Polish & Performance (Week 7-8)
1. Debug Mode
2. Type Validation
3. Performance optimizations

## Enhancement Summary (15 Items)

1. **Dictionary/Map Support** - Add support for [String: Any] dictionaries
2. **Optional Type Support** - Handle Swift optionals properly
3. **Enum Support** - Bridge Swift enums to Lua
4. **Async/Await Support** - Support async Swift methods
5. **Protocol Conformance** - Bridge protocol methods
6. **Class Inheritance** - Support inheritance hierarchies
7. **Custom Operators** - Enable operator overloading
8. **Computed Properties** - Support get/set computed properties
9. **Weak References** - Prevent retain cycles
10. **Better Error Messages** - Enhanced error reporting
11. **Generic Type Support** - Handle generic Swift types
12. **Tuple Support** - Bridge Swift tuples
13. **Closure Type Validation** - Improve closure parameter validation
14. **Method Aliasing** - Allow Lua method name customization
15. **Performance Monitoring** - Add performance metrics

## Compatibility Matrix

| Enhancement | Breaking Change | Migration Required | Priority |
|------------|----------------|-------------------|----------|
| Dictionary Support | No | No | High |
| Optional Support | No | No | High |
| Enum Support | No | No | Medium |
| Async Support | No | No | High |
| Protocol Conformance | No | No | Medium |
| Class Inheritance | No | No | Medium |
| Custom Operators | No | No | Low |
| Computed Properties | No | No | Medium |
| Weak References | No | No | High |
| Better Errors | No | No | High |
| Generic Types | Possible | Maybe | Low |
| Tuple Support | No | No | Low |
| Closure Validation | No | No | Medium |
| Method Aliasing | No | No | Medium |
| Performance Monitoring | No | No | Low |

## Testing Strategy

For each enhancement:
1. Unit tests in `Tests/LuaKitTests/`
2. Example in `Examples/`
3. Public API test in `Tests/LuaKitPublicAPITests/`
4. Documentation update

## Migration Guide Template

For each enhancement that requires migration:

```markdown
## Migrating to [Feature Name]

### What Changed
[Description of changes]

### Before
```swift
// Old code
```

### After
```swift
// New code
```

### Automatic Migration
[If applicable, describe any automatic migration tools]
```

## Detailed Implementation Breakdown

### Macro vs Runtime Classification

**Macro-Only Enhancements:**
- Method Aliasing (attribute parsing)
- Computed Properties (detection and code generation)
- Protocol Conformance (detection)
- Class Inheritance (hierarchy detection)

**Runtime-Only Enhancements:**
- Weak References (memory management)
- Performance Monitoring (metrics collection)
- Debug Mode (logging infrastructure)
- Custom Operators (metamethod registration)

**Both Macro and Runtime:**
- Dictionary Support (type detection + proxy implementation)
- Optional Support (type detection + nil handling)
- Enum Support (case mapping + value conversion)
- Async/Await (method detection + coroutine support)
- Generic Types (type parameter handling + runtime resolution)
- Tuple Support (type detection + table conversion)
- Better Errors (context generation + error formatting)
- Closure Validation (type checking at both levels)

### Dependencies Between Features

**Independent Features (can be implemented in any order):**
- Better Error Messages
- Debug Mode
- Performance Monitoring
- Method Aliasing
- Weak References

**Features with Dependencies:**
- Generic Types → Requires enhanced type system
- Async/Await → Requires coroutine infrastructure
- Class Inheritance → Requires metatable chaining
- Protocol Conformance → Requires inheritance support
- Custom Operators → Requires enhanced metamethod support

### Risk Assessment

**Low Risk (unlikely to break existing code):**
- Dictionary Support
- Optional Support
- Better Error Messages
- Debug Mode
- Computed Properties
- Method Aliasing
- Performance Monitoring

**Medium Risk (may require careful implementation):**
- Enum Support (name collision potential)
- Weak References (memory management changes)
- Closure Validation (stricter type checking)
- Protocol Conformance (method resolution order)

**High Risk (potential breaking changes):**
- Generic Types (type system overhaul)
- Async/Await (execution model changes)
- Class Inheritance (metatable structure changes)
- Custom Operators (operator precedence issues)

## Implementation Examples

### Example 1: Dictionary Support Implementation

**Macro Changes (LuaMacrosPlugin.swift):**
```swift
// Detect dictionary properties
if propType.contains("[String:") {
    let valueType = extractDictionaryValueType(propType)
    codeLines.append("let proxy = LuaDictionaryProxy<String, \(valueType)>(")
    // ... proxy initialization
}
```

**Runtime Library (New file: LuaDictionaryProxy.swift):**
```swift
public class LuaDictionaryProxy<Key: Hashable, Value: LuaBridgeable> {
    private let getter: () -> [Key: Value]
    private let setter: ([Key: Value]) -> Void
    
    // Lua metamethods for dictionary operations
    static func push(_ proxy: LuaDictionaryProxy, to L: OpaquePointer) {
        // Implementation
    }
}
```

### Example 2: Optional Support Implementation

**Macro Changes:**
```swift
// Detect optional types
if propType.contains("?") {
    codeLines.append("if let value = obj.\(propName) {")
    codeLines.append("    // Push non-nil value")
    codeLines.append("} else {")
    codeLines.append("    lua_pushnil(L)")
    codeLines.append("}")
}
```

### Example 3: Async/Await Support

**Runtime Library (LuaCoroutine.swift):**
```swift
public class LuaCoroutine {
    private let continuation: CheckedContinuation<LuaValue, Error>
    
    public func resume(with value: LuaValue) {
        continuation.resume(returning: value)
    }
}
```

**Macro Changes:**
```swift
// Detect async methods
if method.modifiers.contains(where: { $0.name.text == "async" }) {
    // Generate coroutine wrapper
}
```

### Example 4: Method Aliasing

**Usage:**
```swift
@LuaBridgeable
class API {
    @LuaMethod(name: "get_user_data")
    func getUserData() -> [String: Any] { }
}
```

**Macro Implementation:**
```swift
// Check for @LuaMethod attribute
if let luaMethodAttr = getAttribute(method, "LuaMethod") {
    let customName = extractNameParameter(luaMethodAttr)
    // Use customName instead of method.name
}
```