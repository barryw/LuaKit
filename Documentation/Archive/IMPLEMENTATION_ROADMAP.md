# LuaKit Enhancement Implementation Roadmap

## Overview
This roadmap provides a step-by-step implementation guide with code structure, dependencies, and specific implementation details for each enhancement.

## Phase 1: Foundation (Week 1-2)
These enhancements form the foundation for other features and should be implemented first.

### 1.1 Better Error Messages (Enhancement #15)
**Priority:** Critical  
**Dependencies:** None  
**Files to Create/Modify:**

#### Create: `Sources/LuaKit/LuaError+Enhanced.swift`
```swift
import Foundation

// Enhanced error types with rich context
public struct LuaErrorContext {
    let file: String?
    let line: Int?
    let column: Int?
    let functionName: String?
    let suggestion: String?
}

public enum LuaError: Error {
    case syntax(String, context: LuaErrorContext? = nil)
    case runtime(String, context: LuaErrorContext? = nil)
    case typeMismatch(expected: String, got: String, parameter: String? = nil, context: LuaErrorContext? = nil)
    case argumentCount(expected: Int, got: Int, function: String)
    case propertyValidation(property: String, value: Any, reason: String)
    case methodNotFound(method: String, type: String, suggestions: [String] = [])
    case conversionFailure(from: Any.Type, to: Any.Type, value: Any?)
    case memoryAllocation
    case stackOverflow
    case custom(String, context: LuaErrorContext? = nil)
}

// Error formatting
extension LuaError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .typeMismatch(let expected, let got, let parameter, let context):
            var message = "Type mismatch"
            if let ctx = context, let function = ctx.functionName {
                message += " in \(function)"
            }
            if let param = parameter {
                message += " parameter '\(param)'"
            }
            message += ": expected \(expected), got \(got)"
            if let ctx = context, let suggestion = ctx.suggestion {
                message += "\nSuggestion: \(suggestion)"
            }
            return message
            
        case .methodNotFound(let method, let type, let suggestions):
            var message = "Method '\(method)' not found on \(type)"
            if !suggestions.isEmpty {
                message += "\nDid you mean: \(suggestions.joined(separator: ", "))"
            }
            return message
            
        // ... other cases
        }
    }
}

// Helper for Lua C API integration
public func luaError(_ L: OpaquePointer, _ error: LuaError) -> Int32 {
    lua_pushstring(L, error.description)
    return lua_error(L)
}
```

#### Modify: `Sources/LuaKit/LuaState.swift`
Add error context tracking:
```swift
// Add to LuaState class
private var errorContextStack: [LuaErrorContext] = []

public func withErrorContext<T>(_ context: LuaErrorContext, _ block: () throws -> T) rethrows -> T {
    errorContextStack.append(context)
    defer { _ = errorContextStack.popLast() }
    return try block()
}

private func enhancedError(from luaError: String) -> LuaError {
    // Parse Lua error string and enhance with context
    let context = errorContextStack.last
    
    // Parse line numbers from Lua errors like "[string "..."]:2: syntax error"
    if let match = luaError.firstMatch(of: /\[string ".*"\]:(\d+): (.*)/) {
        let line = Int(match.1)
        let message = String(match.2)
        return .syntax(message, context: LuaErrorContext(
            file: nil,
            line: line,
            column: nil,
            functionName: context?.functionName,
            suggestion: nil
        ))
    }
    
    return .runtime(luaError, context: context)
}
```

### 1.2 Type Conversion Helpers (Enhancement #13)
**Priority:** Critical  
**Dependencies:** Better Error Messages  
**Files to Create:**

#### Create: `Sources/LuaKit/LuaTypeConversion.swift`
```swift
import Foundation

// Base protocol for type conversion
public protocol LuaTypeConvertible {
    associatedtype LuaType: LuaConvertible
    func toLua() -> LuaType
    static func fromLua(_ value: LuaType) -> Self?
}

// Type converter protocol
public protocol LuaTypeConverter {
    associatedtype SwiftType
    associatedtype LuaType: LuaConvertible
    
    static func toLua(_ value: SwiftType) -> LuaType
    static func fromLua(_ value: LuaType) -> SwiftType?
}

// Built-in converters
public struct DateToTimestampConverter: LuaTypeConverter {
    public static func toLua(_ value: Date) -> Double {
        return value.timeIntervalSince1970
    }
    
    public static func fromLua(_ value: Double) -> Date? {
        return Date(timeIntervalSince1970: value)
    }
}

public struct ColorToHexConverter: LuaTypeConverter {
    public static func toLua(_ value: Color) -> String {
        return value.hexString
    }
    
    public static func fromLua(_ value: String) -> Color? {
        return Color(hex: value)
    }
}

// Conversion registry
public class LuaConversionRegistry {
    static let shared = LuaConversionRegistry()
    
    private var converters: [ObjectIdentifier: Any] = [:]
    
    public func register<T: LuaTypeConverter>(_ converter: T.Type, for type: T.SwiftType.Type) {
        converters[ObjectIdentifier(type)] = converter
    }
    
    public func converter<T>(for type: T.Type) -> Any? {
        return converters[ObjectIdentifier(type)]
    }
}
```

### 1.3 Debug Helpers (Enhancement #10)
**Priority:** High  
**Dependencies:** Better Error Messages  
**Files to Create:**

#### Create: `Sources/LuaKit/LuaDebug.swift`
```swift
import Foundation
import os.log

// Debug logging system
public enum LuaDebugLevel: Int, Comparable {
    case trace = 0
    case info = 1
    case warning = 2
    case error = 3
    
    public static func < (lhs: LuaDebugLevel, rhs: LuaDebugLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public protocol LuaDebuggable: AnyObject {
    static var debugLevel: LuaDebugLevel { get set }
    static var debugLogger: OSLog? { get set }
}

// Default implementation
extension LuaDebuggable {
    public static func log(_ message: String, level: LuaDebugLevel = .info, 
                          file: String = #file, line: Int = #line, function: String = #function) {
        guard level >= debugLevel else { return }
        
        let timestamp = Date()
        let className = String(describing: self)
        
        if let logger = debugLogger {
            os_log("%{public}@ [%{public}@] %{public}@:%d - %{public}@", 
                   log: logger, 
                   type: osLogType(for: level),
                   timestamp.description,
                   className,
                   file,
                   line,
                   message)
        } else {
            print("[\(timestamp)] [\(className)] \(file):\(line) - \(message)")
        }
    }
    
    private static func osLogType(for level: LuaDebugLevel) -> OSLogType {
        switch level {
        case .trace: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

// Performance tracking
public struct LuaPerformanceTracker {
    private let startTime: CFAbsoluteTime
    private let operation: String
    
    public init(_ operation: String) {
        self.operation = operation
        self.startTime = CFAbsoluteTimeGetCurrent()
    }
    
    public func end<T: LuaDebuggable>(in type: T.Type) {
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        type.log("\(operation) completed in \(String(format: "%.2f", elapsed))ms", level: .trace)
    }
}
```

### 1.4 Global Function Registration (Enhancement #8)
**Priority:** High  
**Dependencies:** Type Conversion Helpers  
**Files to Modify:**

#### Modify: `Sources/LuaKit/LuaState.swift`
Add global function registration methods:
```swift
// Add to LuaState extension
public extension LuaState {
    // Zero-argument function
    func registerGlobal<R: LuaConvertible>(_ name: String, _ function: @escaping () -> R) {
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            let result = function()
            R.push(result, to: L)
            return 1
        }, 0)
        lua_setglobal(L, name)
    }
    
    // One-argument function
    func registerGlobal<T1: LuaConvertible, R: LuaConvertible>(
        _ name: String, 
        _ function: @escaping (T1) -> R
    ) {
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let arg1 = T1.pull(from: L, at: 1) else {
                return luaError(L, .typeMismatch(
                    expected: String(describing: T1.self),
                    got: luaTypeName(L, at: 1),
                    parameter: "arg1",
                    context: LuaErrorContext(functionName: name)
                ))
            }
            let result = function(arg1)
            R.push(result, to: L)
            return 1
        }, 0)
        lua_setglobal(L, name)
    }
    
    // Two-argument function
    func registerGlobal<T1: LuaConvertible, T2: LuaConvertible, R: LuaConvertible>(
        _ name: String,
        _ function: @escaping (T1, T2) -> R
    ) {
        // Similar implementation...
    }
    
    // Three-argument function
    func registerGlobal<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible, R: LuaConvertible>(
        _ name: String,
        _ function: @escaping (T1, T2, T3) -> R
    ) {
        // Similar implementation...
    }
    
    // Void return functions
    func registerGlobal<T1: LuaConvertible>(_ name: String, _ function: @escaping (T1) -> Void) {
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let arg1 = T1.pull(from: L, at: 1) else {
                return luaError(L, .typeMismatch(
                    expected: String(describing: T1.self),
                    got: luaTypeName(L, at: 1),
                    parameter: "arg1",
                    context: LuaErrorContext(functionName: name)
                ))
            }
            function(arg1)
            return 0
        }, 0)
        lua_setglobal(L, name)
    }
}
```

## Phase 2: Macro Infrastructure (Week 3-4)

### 2.1 Enhanced Macro System
**Files to Modify:**

#### Modify: `Sources/LuaMacros/LuaMacrosPlugin.swift`
Add new macro types and enhance existing ones:

```swift
// Add new macro implementations
public struct LuaMethodMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Store metadata for the main macro to use
        guard let method = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.onlyApplicableToMethods
        }
        
        // Extract macro parameters
        let parameters = extractParameters(from: node)
        
        // Store metadata in context for LuaBridgeableMacro to use
        context.store(LuaMethodMetadata(
            name: method.name.text,
            alias: parameters.alias,
            chainable: parameters.chainable,
            async: parameters.async
        ))
        
        return []
    }
}

public struct LuaPropertyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let property = declaration.as(VariableDeclSyntax.self) else {
            throw MacroError.onlyApplicableToProperties
        }
        
        let parameters = extractParameters(from: node)
        
        // Generate validation helper method if needed
        var generated: [DeclSyntax] = []
        
        if parameters.hasValidation {
            let validationMethod = generateValidationMethod(
                for: property,
                parameters: parameters
            )
            generated.append(validationMethod)
        }
        
        return generated
    }
    
    static func generateValidationMethod(
        for property: VariableDeclSyntax,
        parameters: PropertyParameters
    ) -> DeclSyntax {
        let propertyName = property.bindings.first?.pattern.description ?? "unknown"
        
        var validationCode: [String] = []
        
        if let min = parameters.min {
            validationCode.append("""
                if value < \(min) {
                    return .failure(ValidationError("Value must be >= \(min)"))
                }
            """)
        }
        
        if let max = parameters.max {
            validationCode.append("""
                if value > \(max) {
                    return .failure(ValidationError("Value must be <= \(max)"))
                }
            """)
        }
        
        if let pattern = parameters.pattern {
            validationCode.append("""
                let regex = try! NSRegularExpression(pattern: "\(pattern)")
                let range = NSRange(location: 0, length: value.count)
                if regex.firstMatch(in: value, options: [], range: range) == nil {
                    return .failure(ValidationError("Value must match pattern: \(pattern)"))
                }
            """)
        }
        
        let body = validationCode.isEmpty ? "return .success(())" : validationCode.joined(separator: "\n    ")
        
        return DeclSyntax(stringLiteral: """
        private func validate_\(propertyName)(_ value: Any) -> Result<Void, ValidationError> {
            \(body)
        }
        """)
    }
}
```

### 2.2 Method Return Type Analysis
**Files to Modify:**

#### Enhance: `Sources/LuaMacros/LuaMacrosPlugin.swift`
Add sophisticated return type handling:

```swift
// Add return type analyzer
struct ReturnTypeAnalyzer {
    static func analyze(_ type: TypeSyntax) -> ReturnTypeInfo {
        let typeString = type.description.trimmingCharacters(in: .whitespaces)
        
        if typeString.starts(with: "Result<") {
            return .result(parseResultType(typeString))
        } else if typeString.hasSuffix("?") {
            return .optional(parseOptionalType(typeString))
        } else if typeString.starts(with: "(") && typeString.hasSuffix(")") {
            return .tuple(parseTupleType(typeString))
        } else if typeString == "Void" || typeString.isEmpty {
            return .void
        } else {
            return .simple(typeString)
        }
    }
    
    static func generatePushCode(for info: ReturnTypeInfo, resultVar: String = "result") -> String {
        switch info {
        case .void:
            return "return 0"
            
        case .simple(let type):
            return """
            \(type).push(\(resultVar), to: L)
            return 1
            """
            
        case .optional(let innerType):
            return """
            if let value = \(resultVar) {
                \(innerType).push(value, to: L)
            } else {
                lua_pushnil(L)
            }
            return 1
            """
            
        case .result(let success, let failure):
            return """
            switch \(resultVar) {
            case .success(let value):
                \(success).push(value, to: L)
                lua_pushnil(L)
                return 2
            case .failure(let error):
                lua_pushnil(L)
                lua_pushstring(L, String(describing: error))
                return 2
            }
            """
            
        case .tuple(let types):
            var code: [String] = []
            for (index, type) in types.enumerated() {
                code.append("\(type).push(\(resultVar).\(index), to: L)")
            }
            code.append("return \(types.count)")
            return code.joined(separator: "\n")
        }
    }
}

enum ReturnTypeInfo {
    case void
    case simple(String)
    case optional(String)
    case result(success: String, failure: String)
    case tuple([String])
}
```

## Phase 3: Collection & Property Features (Week 5-6)

### 3.1 Collection Support Macro
**Files to Create:**

#### Create: `Sources/LuaKit/LuaCollectionProxy.swift`
```swift
// Base protocol for collection proxies
public protocol LuaCollectionProxy: LuaBridgeable {
    associatedtype Element
    associatedtype Owner: AnyObject
    
    var owner: Owner { get }
    var propertyName: String { get }
}

// Generic implementation
public struct LuaGenericCollectionProxy<Owner: AnyObject, Element: LuaConvertible>: LuaCollectionProxy {
    public let owner: Owner
    public let propertyName: String
    private let getter: () -> [Element]
    private let setter: ([Element]) -> Void
    
    // Collection methods
    public var count: Int {
        return getter().count
    }
    
    public func get(_ index: Int) -> Element? {
        let array = getter()
        guard index >= 1 && index <= array.count else { return nil }
        return array[index - 1]  // Convert from Lua 1-based indexing
    }
    
    public func set(_ index: Int, _ value: Element) {
        var array = getter()
        guard index >= 1 && index <= array.count else { return }
        array[index - 1] = value
        setter(array)
    }
    
    public func append(_ value: Element) {
        var array = getter()
        array.append(value)
        setter(array)
    }
    
    public func remove(_ index: Int) -> Element? {
        var array = getter()
        guard index >= 1 && index <= array.count else { return nil }
        let removed = array.remove(at: index - 1)
        setter(array)
        return removed
    }
}
```

### 3.2 Property Validation Runtime
**Files to Create:**

#### Create: `Sources/LuaKit/LuaValidation.swift`
```swift
public struct ValidationError: Error {
    public let message: String
    public let property: String?
    public let value: Any?
    
    public init(_ message: String, property: String? = nil, value: Any? = nil) {
        self.message = message
        self.property = property
        self.value = value
    }
}

// Validation protocols
public protocol LuaValidatable {
    func validate<T>(_ value: T, for property: String) -> Result<Void, ValidationError>
}

// Built-in validators
public struct LuaValidators {
    public static func range<T: Comparable>(_ value: T, min: T? = nil, max: T? = nil) -> Result<Void, ValidationError> {
        if let min = min, value < min {
            return .failure(ValidationError("Value \(value) is below minimum \(min)"))
        }
        if let max = max, value > max {
            return .failure(ValidationError("Value \(value) exceeds maximum \(max)"))
        }
        return .success(())
    }
    
    public static func pattern(_ value: String, _ pattern: String) -> Result<Void, ValidationError> {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return .failure(ValidationError("Invalid regex pattern"))
        }
        
        let range = NSRange(location: 0, length: value.count)
        if regex.firstMatch(in: value, options: [], range: range) != nil {
            return .success(())
        }
        
        return .failure(ValidationError("Value '\(value)' does not match pattern '\(pattern)'"))
    }
}
```

## Phase 4: Advanced Features (Week 7-8)

### 4.1 Enum Bridging
**Files to Create:**

#### Create: `Sources/LuaKit/LuaEnum.swift`
```swift
// Protocol for automatic enum bridging
public protocol LuaEnumBridgeable: RawRepresentable, CaseIterable, LuaConvertible 
    where RawValue: LuaConvertible {
}

// Default implementation
public extension LuaEnumBridgeable {
    static func push(_ value: Self, to L: OpaquePointer) {
        RawValue.push(value.rawValue, to: L)
    }
    
    static func pull(from L: OpaquePointer, at index: Int32) -> Self? {
        guard let rawValue = RawValue.pull(from: L, at: index) else { return nil }
        return Self(rawValue: rawValue)
    }
    
    static func register(in state: LuaState, as name: String) {
        let L = state.luaState
        
        // Create enum table
        lua_createtable(L, 0, Int32(allCases.count * 2))
        
        // Register each case
        for enumCase in allCases {
            // caseName = rawValue
            let caseName = String(describing: enumCase)
            lua_pushstring(L, caseName)
            RawValue.push(enumCase.rawValue, to: L)
            lua_settable(L, -3)
            
            // rawValue = caseName (reverse lookup)
            RawValue.push(enumCase.rawValue, to: L)
            lua_pushstring(L, caseName)
            lua_settable(L, -3)
        }
        
        // Add iterator metamethod
        lua_createtable(L, 0, 1)
        lua_pushstring(L, "__pairs")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Push iterator function
            lua_pushcclosure(L, { L in
                guard let L = L else { return 0 }
                
                // Get current index
                let index = lua_tointegerx(L, 2, nil)
                let cases = Array(Self.allCases)
                
                if index < cases.count {
                    let enumCase = cases[Int(index)]
                    lua_pushinteger(L, index + 1)
                    lua_pushstring(L, String(describing: enumCase))
                    RawValue.push(enumCase.rawValue, to: L)
                    return 3
                }
                
                return 0
            }, 0)
            
            // Push table (first argument to iterator)
            lua_pushvalue(L, 1)
            
            // Push initial index (0)
            lua_pushinteger(L, 0)
            
            return 3
        }, 0)
        lua_settable(L, -3)
        
        lua_setmetatable(L, -2)
        lua_setglobal(L, name)
    }
}
```

### 4.2 Namespace Support
**Files to Create:**

#### Create: `Sources/LuaKit/LuaNamespace.swift`
```swift
// Namespace protocol
public protocol LuaNamespaceProvider {
    static var namespaceName: String { get }
    static func registerContents(in namespace: LuaNamespace)
}

public class LuaNamespace {
    private let L: OpaquePointer
    private let name: String
    private var registeredTypes: Set<String> = []
    
    init(L: OpaquePointer, name: String) {
        self.L = L
        self.name = name
        
        // Create namespace table
        lua_createtable(L, 0, 0)
        lua_setglobal(L, name)
    }
    
    public func register<T: LuaBridgeable>(_ type: T.Type, as name: String) {
        guard !registeredTypes.contains(name) else { return }
        registeredTypes.insert(name)
        
        // Get namespace table
        lua_getglobal(L, self.name)
        
        // Create type table
        lua_createtable(L, 0, 1)
        
        // Add constructor
        lua_pushstring(L, "new")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            return T.luaNew(L)
        }, 0)
        lua_settable(L, -3)
        
        // Add factory methods if available
        if let factoryType = type as? LuaFactoryProvider.Type {
            for (methodName, method) in factoryType.factoryMethods {
                lua_pushstring(L, methodName)
                lua_pushcclosure(L, method, 0)
                lua_settable(L, -3)
            }
        }
        
        // Set in namespace
        lua_setfield(L, -2, name)
        
        // Pop namespace table
        lua_pop(L, 1)
    }
    
    public func registerFunction(_ name: String, _ function: @escaping lua_CFunction) {
        lua_getglobal(L, self.name)
        lua_pushstring(L, name)
        lua_pushcclosure(L, function, 0)
        lua_settable(L, -3)
        lua_pop(L, 1)
    }
}
```

#### Create: `Sources/LuaMacros/LuaNamespaceMacro.swift`
```swift
public struct LuaNamespaceMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.onlyApplicableToEnums
        }
        
        let namespaceName = extractNamespaceName(from: node)
        
        // Generate namespace provider conformance
        let extensionDecl = try ExtensionDeclSyntax("""
        extension \(enumDecl.name): LuaNamespaceProvider {
            static var namespaceName: String { "\(namespaceName)" }
            
            static func registerContents(in namespace: LuaNamespace) {
                // Register nested types
                \(generateTypeRegistrations(from: enumDecl))
                
                // Register namespace functions
                \(generateFunctionRegistrations(from: enumDecl))
            }
        }
        """)
        
        return [extensionDecl]
    }
}
```

## Phase 5: Async Support (Week 9-10)

### 5.1 Async/Await Bridge
**Files to Create:**

#### Create: `Sources/LuaKit/LuaAsync.swift`
```swift
import Foundation

// Async execution protocol
public protocol LuaAsyncExecutor {
    func executeAsync<T: LuaConvertible>(
        _ block: @escaping () async throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    )
}

// Default async executor using Task
public struct DefaultLuaAsyncExecutor: LuaAsyncExecutor {
    public func executeAsync<T: LuaConvertible>(
        _ block: @escaping () async throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        Task {
            do {
                let result = try await block()
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// Promise-style wrapper for Lua
public class LuaPromise {
    private let L: OpaquePointer
    private var thenCallback: Int = LUA_NOREF
    private var catchCallback: Int = LUA_NOREF
    
    init(L: OpaquePointer) {
        self.L = L
    }
    
    deinit {
        if thenCallback != LUA_NOREF {
            luaL_unref(L, LUA_REGISTRYINDEX, thenCallback)
        }
        if catchCallback != LUA_NOREF {
            luaL_unref(L, LUA_REGISTRYINDEX, catchCallback)
        }
    }
    
    public func then(_ ref: Int) -> Self {
        if thenCallback != LUA_NOREF {
            luaL_unref(L, LUA_REGISTRYINDEX, thenCallback)
        }
        thenCallback = ref
        return self
    }
    
    public func `catch`(_ ref: Int) -> Self {
        if catchCallback != LUA_NOREF {
            luaL_unref(L, LUA_REGISTRYINDEX, catchCallback)
        }
        catchCallback = ref
        return self
    }
    
    func resolve<T: LuaConvertible>(_ value: T) {
        guard thenCallback != LUA_NOREF else { return }
        
        lua_rawgeti(L, LUA_REGISTRYINDEX, lua_Integer(thenCallback))
        T.push(value, to: L)
        
        if lua_pcall(L, 1, 0, 0) != LUA_OK {
            // Handle error
            let error = String(cString: lua_tolstring(L, -1, nil)!)
            print("Promise then callback error: \(error)")
            lua_pop(L, 1)
        }
    }
    
    func reject(_ error: Error) {
        guard catchCallback != LUA_NOREF else { return }
        
        lua_rawgeti(L, LUA_REGISTRYINDEX, lua_Integer(catchCallback))
        lua_pushstring(L, error.localizedDescription)
        
        if lua_pcall(L, 1, 0, 0) != LUA_OK {
            // Handle error
            let error = String(cString: lua_tolstring(L, -1, nil)!)
            print("Promise catch callback error: \(error)")
            lua_pop(L, 1)
        }
    }
}
```

## Testing Infrastructure

### Create Test Suite Structure
**Files to Create:**

#### Create: `Tests/LuaKitEnhancementTests/ErrorMessageTests.swift`
```swift
import XCTest
@testable import LuaKit

class ErrorMessageTests: XCTestCase {
    func testTypeMismatchError() {
        let state = try! LuaState()
        
        // Register a function expecting Int
        state.registerGlobal("testFunc") { (n: Int) in n * 2 }
        
        // Call with wrong type
        XCTAssertThrowsError(try state.execute("""
            testFunc("not a number")
        """)) { error in
            guard let luaError = error as? LuaError,
                  case .typeMismatch(let expected, let got, let param, _) = luaError else {
                XCTFail("Expected type mismatch error")
                return
            }
            
            XCTAssertEqual(expected, "Int")
            XCTAssertEqual(got, "string")
            XCTAssertEqual(param, "arg1")
        }
    }
}
```

#### Create: `Tests/LuaKitEnhancementTests/CollectionTests.swift`
```swift
import XCTest
@testable import LuaKit

@LuaBridgeable
class TestLibrary {
    @LuaCollection
    var books: [String] = []
}

class CollectionTests: XCTestCase {
    func testCollectionMethods() throws {
        let state = try LuaState()
        state.register(TestLibrary.self, as: "Library")
        
        let output = try state.execute("""
            local lib = Library.new()
            
            -- Test append
            lib.books:append("Book 1")
            lib.books:append("Book 2")
            
            -- Test count
            print("Count: " .. lib.books.count)
            
            -- Test get
            print("First: " .. lib.books:get(1))
            
            -- Test array syntax
            lib.books[2] = "Book 2 Updated"
            print("Updated: " .. lib.books[2])
            
            -- Test iteration
            for i, book in lib.books:iter() do
                print(i .. ": " .. book)
            end
        """)
        
        XCTAssertTrue(output.contains("Count: 2"))
        XCTAssertTrue(output.contains("First: Book 1"))
        XCTAssertTrue(output.contains("Updated: Book 2 Updated"))
    }
}
```

## Migration Guide

### For Users Upgrading from 1.x

1. **No Breaking Changes**: All existing code continues to work
2. **Opt-in Features**: New features require explicit attributes
3. **Gradual Migration**: Can adopt features incrementally

### Migration Steps:

```swift
// Step 1: Update error handling (optional but recommended)
do {
    try state.execute(code)
} catch let error as LuaError {
    // Now you get rich error information
    print(error.description)
}

// Step 2: Add debug support (optional)
@LuaBridgeable(debug: true)
class MyClass { }

// Step 3: Use new attributes as needed
@LuaBridgeable
class EnhancedClass {
    @LuaProperty(min: 0, max: 100)
    var progress: Int = 0
    
    @LuaAlias("calc")
    func calculate() -> Double { }
    
    @LuaCollection
    var items: [String] = []
}
```

## Performance Optimization

### Compile-Time Optimizations
1. Use `@inlinable` for frequently-called conversion functions
2. Precompute validation patterns at compile time
3. Generate specialized code for common types

### Runtime Optimizations
1. Cache type converters in a global registry
2. Use lazy initialization for debug infrastructure
3. Optimize collection proxy allocation

## Conclusion

This implementation roadmap provides a clear path to implementing all 15 enhancements in LuaKit. The phased approach ensures each feature is built on a solid foundation, with proper testing and documentation at each step.