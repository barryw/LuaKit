# LuaKit Enhancement Implementation Plan

## Overview
This document provides a detailed implementation plan for the 15 requested enhancements to LuaKit, organized by implementation approach, dependencies, and priority.

## Enhancement Categories

### A. Macro-Based Enhancements (Compile-Time)
These features are implemented through Swift macros and generate code at compile time.

### B. Runtime Enhancements
These features require runtime support and modifications to the core LuaKit library.

### C. Hybrid Enhancements
These features require both macro and runtime support.

## Implementation Groups

### Group 1: Core Infrastructure Enhancements (High Priority)
These form the foundation for other features.

#### 1.1 Better Error Messages (Enhancement #15)
**Type:** Runtime Enhancement  
**Complexity:** Low  
**Dependencies:** None  

**Implementation:**
```swift
// Enhanced LuaError enum
public enum LuaError: Error, CustomStringConvertible {
    case syntax(String, line: Int?, column: Int?)
    case runtime(String, stackTrace: [String])
    case typeMismatch(expected: String, got: String, context: String?)
    case propertyValidation(property: String, reason: String)
    case methodNotFound(method: String, on: String)
    case argumentMismatch(method: String, expected: Int, got: Int)
    case conversionFailure(from: String, to: String, value: Any?)
    
    public var description: String {
        switch self {
        case .typeMismatch(let expected, let got, let context):
            if let context = context {
                return "Type mismatch in \(context): expected \(expected), got \(got)"
            }
            return "Type mismatch: expected \(expected), got \(got)"
        // ... other cases
        }
    }
}

// Error context tracking
internal struct LuaErrorContext {
    static var current: String?
    
    static func withContext<T>(_ context: String, _ block: () throws -> T) rethrows -> T {
        let previous = current
        current = context
        defer { current = previous }
        return try block()
    }
}
```

#### 1.2 Debug Helpers (Enhancement #10)
**Type:** Hybrid Enhancement  
**Complexity:** Medium  
**Dependencies:** Better Error Messages  

**Macro Implementation:**
```swift
// In LuaMacros.swift
@attached(peer)
public macro LuaBridgeable(mode: LuaBridgeMode = .automatic, debug: Bool = false) = #externalMacro(module: "LuaMacros", type: "LuaBridgeableMacro")
```

**Runtime Implementation:**
```swift
// Debug logging protocol
public protocol LuaDebugLoggable {
    static var debugEnabled: Bool { get set }
    static func log(_ message: String, level: LuaDebugLevel)
}

public enum LuaDebugLevel {
    case info, warning, error, trace
}

// Generated debug code in macro
if BridgedClass.debugEnabled {
    BridgedClass.log("Calling method \(methodName) with \(args.count) arguments", level: .trace)
}
```

### Group 2: Type System Enhancements (High Priority)

#### 2.1 Methods Returning Different Types (Enhancement #1)
**Type:** Hybrid Enhancement  
**Complexity:** High  
**Dependencies:** Better Error Messages  

**Implementation Strategy:**
- Extend macro to analyze return types
- Generate appropriate push/pull code for each type
- Support Result<T, E>, Optional<T>, tuples, and custom types

**Macro Enhancement:**
```swift
// In LuaMacrosPlugin.swift
static func generateReturnHandling(for returnType: TypeSyntax) -> String {
    if returnType.isResultType {
        return generateResultHandling(returnType)
    } else if returnType.isOptionalType {
        return generateOptionalHandling(returnType)
    } else if returnType.isTupleType {
        return generateTupleHandling(returnType)
    }
    // ... existing handling
}

static func generateResultHandling(_ type: TypeSyntax) -> String {
    """
    switch result {
    case .success(let value):
        \(generatePushCode(for: value))
        return 1
    case .failure(let error):
        lua_pushnil(L)
        lua_pushstring(L, error.localizedDescription)
        return 2
    }
    """
}
```

#### 2.2 Automatic Enum Bridging (Enhancement #6)
**Type:** Hybrid Enhancement  
**Complexity:** Medium  
**Dependencies:** Type Conversion Helpers  

**Implementation:**
```swift
// Protocol for enum bridging
public protocol LuaEnumBridgeable: RawRepresentable, CaseIterable where RawValue: LuaConvertible {
    static var luaTypeName: String { get }
}

// Default implementation
extension LuaEnumBridgeable {
    public static func push(_ value: Self, to L: OpaquePointer) {
        RawValue.push(value.rawValue, to: L)
    }
    
    public static func pull(from L: OpaquePointer, at index: Int32) -> Self? {
        guard let rawValue = RawValue.pull(from: L, at: index) else { return nil }
        return Self(rawValue: rawValue)
    }
    
    public static func registerEnum(in state: LuaState, as name: String) {
        let L = state.luaState
        lua_createtable(L, 0, Int32(allCases.count))
        
        for case in allCases {
            lua_pushstring(L, String(describing: case))
            RawValue.push(case.rawValue, to: L)
            lua_settable(L, -3)
        }
        
        lua_setglobal(L, name)
    }
}
```

#### 2.3 Type Conversion Helpers (Enhancement #13)
**Type:** Runtime Enhancement  
**Complexity:** Low  
**Dependencies:** None  

**Implementation:**
```swift
// Type conversion protocol
public protocol LuaTypeConvertible {
    associatedtype LuaType: LuaConvertible
    func toLua() -> LuaType
    static func fromLua(_ value: LuaType) -> Self?
}

// Macro attribute
@attached(peer)
public macro LuaConvert(to: Any.Type, from: (Any) -> Any, to: (Any) -> Any) = #externalMacro(module: "LuaMacros", type: "LuaConvertMacro")

// Example usage
@LuaConvert(to: String.self, 
            from: { Color(hex: $0) }, 
            to: { $0.hexString })
struct Color {
    let r, g, b: Double
}
```

### Group 3: Method & Property Enhancements (Medium Priority)

#### 3.1 Collection/Array Method Syntax (Enhancement #2)
**Type:** Macro Enhancement  
**Complexity:** Medium  
**Dependencies:** None  

**Implementation:**
```swift
// Macro attribute
@attached(peer)
public macro LuaCollection() = #externalMacro(module: "LuaMacros", type: "LuaCollectionMacro")

// Usage
@LuaBridgeable
class Library {
    @LuaCollection
    var books: [Book] = []
}

// Generated code includes:
// - count property
// - get(index) method
// - set(index, value) method
// - append(value) method
// - remove(index) method
// - iterator support
```

#### 3.2 Method Aliases (Enhancement #3)
**Type:** Macro Enhancement  
**Complexity:** Low  
**Dependencies:** None  

**Implementation:**
```swift
// Macro attribute
@attached(peer)
public macro LuaAlias(_ name: String) = #externalMacro(module: "LuaMacros", type: "LuaAliasMacro")

// Usage
@LuaBridgeable
class Image {
    @LuaAlias("getPixel")
    func pixelAt(x: Int, y: Int) -> Color { ... }
}

// Macro generates additional method registration:
lua_pushstring(L, "getPixel")
lua_pushvalue(L, -2)  // Copy the function
lua_settable(L, -3)
```

#### 3.3 Property Validation Attributes (Enhancement #5)
**Type:** Hybrid Enhancement  
**Complexity:** Medium  
**Dependencies:** Better Error Messages  

**Implementation:**
```swift
// Validation attributes
@attached(peer)
public macro LuaProperty(
    readable: Bool = true,
    writable: Bool = true,
    min: Double? = nil,
    max: Double? = nil,
    pattern: String? = nil,
    validator: String? = nil
) = #externalMacro(module: "LuaMacros", type: "LuaPropertyMacro")

// Usage
@LuaBridgeable
class User {
    @LuaProperty(min: 0, max: 150)
    var age: Int = 0
    
    @LuaProperty(pattern: "^[a-zA-Z0-9]+$")
    var username: String = ""
    
    @LuaProperty(validator: "validateEmail")
    var email: String = ""
    
    func validateEmail(_ value: String) -> Result<Void, ValidationError> {
        // Custom validation logic
    }
}
```

#### 3.4 Method Chaining Support (Enhancement #12)
**Type:** Macro Enhancement  
**Complexity:** Low  
**Dependencies:** None  

**Implementation:**
```swift
// Macro attribute
@attached(peer)
public macro LuaChainable() = #externalMacro(module: "LuaMacros", type: "LuaChainableMacro")

// Usage
@LuaBridgeable
class Builder {
    @LuaChainable
    func setWidth(_ width: Int) -> Self {
        self.width = width
        return self
    }
}

// Macro ensures method returns self to Lua:
obj.methodName(args...)
push(obj, to: L)  // Push self instead of void
return 1
```

### Group 4: API Enhancement Features (Medium Priority)

#### 4.1 Automatic Factory Methods (Enhancement #4)
**Type:** Hybrid Enhancement  
**Complexity:** Medium  
**Dependencies:** None  

**Implementation:**
```swift
// Factory protocol
public protocol LuaFactoryCreatable {
    associatedtype FactoryParameters
    static func createFrom(_ params: FactoryParameters) -> Self?
}

// Macro attribute
@attached(member, names: named(create))
public macro LuaFactory(_ params: String...) = #externalMacro(module: "LuaMacros", type: "LuaFactoryMacro")

// Usage
@LuaBridgeable
@LuaFactory("fromSize", "fromFile")
class Image {
    static func fromSize(width: Int, height: Int) -> Image? { ... }
    static func fromFile(path: String) -> Image? { ... }
}

// In Lua:
// local img1 = Image.fromSize(100, 100)
// local img2 = Image.fromFile("photo.jpg")
```

#### 4.2 Global Function Registration (Enhancement #8)
**Type:** Runtime Enhancement  
**Complexity:** Low  
**Dependencies:** None  

**Implementation:**
```swift
// In LuaState.swift
public extension LuaState {
    func registerGlobal<T: LuaConvertible>(
        _ name: String,
        _ function: @escaping () -> T
    ) {
        lua_pushcclosure(luaState, { L in
            guard let L = L else { return 0 }
            let result = function()
            T.push(result, to: L)
            return 1
        }, 0)
        lua_setglobal(luaState, name)
    }
    
    func registerGlobal<T: LuaConvertible, U: LuaConvertible>(
        _ name: String,
        _ function: @escaping (T) -> U
    ) {
        lua_pushcclosure(luaState, { L in
            guard let L = L else { return 0 }
            guard let arg = T.pull(from: L, at: 1) else {
                return luaError(L, "Invalid argument type")
            }
            let result = function(arg)
            U.push(result, to: L)
            return 1
        }, 0)
        lua_setglobal(luaState, name)
    }
}

// Usage:
state.registerGlobal("getCurrentTime") { Date().timeIntervalSince1970 }
state.registerGlobal("formatNumber") { (n: Double) in
    String(format: "%.2f", n)
}
```

#### 4.3 Namespace Support (Enhancement #14)
**Type:** Hybrid Enhancement  
**Complexity:** Medium  
**Dependencies:** None  

**Implementation:**
```swift
// Namespace protocol
public protocol LuaNamespace {
    static var namespaceName: String { get }
    static func registerNamespace(in state: LuaState)
}

// Macro attribute
@attached(extension, conformances: LuaNamespace)
public macro LuaNamespace(_ name: String) = #externalMacro(module: "LuaMacros", type: "LuaNamespaceMacro")

// Usage
@LuaNamespace("Graphics")
enum GraphicsNamespace {
    @LuaBridgeable
    class Color { ... }
    
    @LuaBridgeable
    class Image { ... }
    
    static func createGradient() -> Gradient { ... }
}

// In Lua:
// local red = Graphics.Color.new(1, 0, 0)
// local img = Graphics.Image.fromFile("test.png")
```

### Group 5: Advanced Features (Low Priority)

#### 5.1 Relationship Annotations (Enhancement #7)
**Type:** Macro Enhancement  
**Complexity:** High  
**Dependencies:** Better Error Messages, Type Conversion  

**Implementation:**
```swift
// Relationship attributes
@attached(peer)
public macro LuaRelationship(
    type: RelationshipType,
    target: Any.Type,
    inverse: String? = nil
) = #externalMacro(module: "LuaMacros", type: "LuaRelationshipMacro")

public enum RelationshipType {
    case oneToOne
    case oneToMany
    case manyToMany
}

// Usage
@LuaBridgeable
class Author {
    @LuaRelationship(type: .oneToMany, target: Book.self, inverse: "author")
    var books: [Book] = []
}

@LuaBridgeable
class Book {
    @LuaRelationship(type: .oneToOne, target: Author.self, inverse: "books")
    var author: Author?
}
```

#### 5.2 Async/Await Support (Enhancement #9)
**Type:** Hybrid Enhancement  
**Complexity:** Very High  
**Dependencies:** Better Error Messages  

**Implementation:**
```swift
// Async protocol
public protocol LuaAsyncExecutable {
    func executeAsync(in state: LuaState, completion: @escaping (Result<LuaValue, Error>) -> Void)
}

// Macro attribute
@attached(peer)
public macro LuaAsync() = #externalMacro(module: "LuaMacros", type: "LuaAsyncMacro")

// Usage
@LuaBridgeable
class NetworkClient {
    @LuaAsync
    func fetchData(url: String) async throws -> Data {
        // Async implementation
    }
}

// Generated code creates promise/callback pattern:
// In Lua:
// client:fetchData("https://api.example.com", function(data, error)
//     if error then
//         print("Error: " .. error)
//     else
//         print("Got data: " .. #data .. " bytes")
//     end
// end)
```

#### 5.3 Documentation Attributes (Enhancement #11)
**Type:** Macro Enhancement  
**Complexity:** Low  
**Dependencies:** None  

**Implementation:**
```swift
// Documentation attributes
@attached(peer)
public macro LuaDoc(_ description: String) = #externalMacro(module: "LuaMacros", type: "LuaDocMacro")

@attached(peer)
public macro LuaParam(_ name: String, _ description: String) = #externalMacro(module: "LuaMacros", type: "LuaParamMacro")

// Usage
@LuaBridgeable
class ImageProcessor {
    @LuaDoc("Resizes the image to the specified dimensions")
    @LuaParam("width", "The target width in pixels")
    @LuaParam("height", "The target height in pixels")
    func resize(width: Int, height: Int) { ... }
}

// Macro generates:
// - Documentation table in Lua
// - Help function for runtime introspection
// - IDE completion hints (if supported)
```

## Implementation Phases

### Phase 1: Foundation (Week 1-2)
1. Better Error Messages (#15)
2. Debug Helpers (#10)
3. Type Conversion Helpers (#13)
4. Global Function Registration (#8)

### Phase 2: Core Features (Week 3-4)
1. Methods Returning Different Types (#1)
2. Method Aliases (#3)
3. Property Validation (#5)
4. Method Chaining (#12)

### Phase 3: Type System (Week 5-6)
1. Automatic Enum Bridging (#6)
2. Collection/Array Method Syntax (#2)
3. Automatic Factory Methods (#4)

### Phase 4: Advanced Features (Week 7-8)
1. Namespace Support (#14)
2. Documentation Attributes (#11)
3. Relationship Annotations (#7)

### Phase 5: Async Support (Week 9-10)
1. Async/Await Support (#9)

## Testing Strategy

### Unit Tests
- Test each enhancement in isolation
- Verify error handling and edge cases
- Test type conversions and validations

### Integration Tests
- Test combinations of features
- Verify macro-generated code correctness
- Test performance implications

### Example Test Structure
```swift
class EnhancementTests: XCTestCase {
    func testMethodReturnTypes() {
        // Test Result<T, E> returns
        // Test Optional returns
        // Test tuple returns
    }
    
    func testPropertyValidation() {
        // Test min/max validation
        // Test pattern validation
        // Test custom validators
    }
    
    func testAsyncMethods() {
        // Test async method calls
        // Test error propagation
        // Test cancellation
    }
}
```

## Migration Guide

### For Existing Code
1. Existing @LuaBridgeable code continues to work
2. New features are opt-in via additional attributes
3. Gradual migration path provided

### Breaking Changes
- None planned
- All enhancements are additive

## Performance Considerations

### Compile-Time Impact
- Macro processing adds ~10-20% to compile time
- Can be mitigated with incremental compilation

### Runtime Impact
- Validation adds minimal overhead (<5%)
- Debug logging can be disabled in release builds
- Async support uses efficient callback mechanisms

## Documentation Requirements

### API Documentation
- Document all new macros and attributes
- Provide usage examples for each feature
- Create migration guides

### Tutorial Series
1. "Getting Started with Enhanced LuaKit"
2. "Advanced Type Bridging"
3. "Building Type-Safe Lua APIs"
4. "Async Programming with LuaKit"

## Conclusion

This implementation plan provides a structured approach to adding all 15 requested enhancements to LuaKit. The phased approach ensures that foundational features are built first, with more complex features building on top of them. The plan prioritizes developer experience while maintaining backward compatibility and performance.