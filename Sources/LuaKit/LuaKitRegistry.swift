//
//  LuaKitRegistry.swift
//  LuaKit
//
//  Central actor managing all shared mutable state for thread-safe access.
//  This enables Swift 6 strict concurrency compliance.
//

import Foundation

/// Central registry actor for LuaKit shared mutable state that can be accessed asynchronously.
///
/// This actor provides thread-safe access to global registries used throughout LuaKit,
/// including enum registration, type converters, and property validators.
///
/// Note: Closure storage is handled separately by `LuaClosureStorage` because
/// C callbacks require synchronous access which actors cannot provide.
///
/// By centralizing async-safe mutable shared state in a single actor, we achieve:
/// - Full Swift 6 strict concurrency compliance
/// - Clear ownership semantics
/// - Elimination of manual lock management
public actor LuaKitRegistry {
    /// Shared singleton instance
    public static let shared = LuaKitRegistry()

    // MARK: - Enum Registry (from LuaEnumBridging)

    /// Set of registered enum type names
    private var registeredEnums: Set<String> = []

    /// Checks if an enum type is already registered
    func isEnumRegistered(_ typeName: String) -> Bool {
        registeredEnums.contains(typeName)
    }

    /// Marks an enum type as registered
    func registerEnum(_ typeName: String) {
        registeredEnums.insert(typeName)
    }

    // MARK: - Type Converters (from LuaTypeConversion)

    /// Custom type converters by type identifier
    private var converters: [ObjectIdentifier: any LuaTypeConverterProtocol] = [:]

    /// Registers a custom type converter
    func registerConverter<T>(_ converter: any LuaTypeConverterProtocol, for type: T.Type) {
        converters[ObjectIdentifier(type)] = converter
    }

    /// Retrieves a converter for a type
    func getConverter<T>(for type: T.Type) -> (any LuaTypeConverterProtocol)? {
        converters[ObjectIdentifier(type)]
    }

    // MARK: - Property Validators (from LuaPropertyValidation)

    /// Property validators by key
    private var validators: [String: any PropertyValidatorProtocol] = [:]

    /// Property metadata by key
    private var propertyMetadata: [String: PropertyMetadataProtocol] = [:]

    /// Registers a property validator
    func registerValidator(_ validator: any PropertyValidatorProtocol, forKey key: String) {
        validators[key] = validator
    }

    /// Retrieves a validator for a key
    func getValidator(forKey key: String) -> (any PropertyValidatorProtocol)? {
        validators[key]
    }

    /// Registers property metadata
    func registerMetadata(_ metadata: PropertyMetadataProtocol, forKey key: String) {
        propertyMetadata[key] = metadata
    }

    /// Retrieves metadata for a key
    func getMetadata(forKey key: String) -> PropertyMetadataProtocol? {
        propertyMetadata[key]
    }

    // MARK: - State Tracking (from LuaState)

    /// Weak references to active LuaState instances
    private var states: [ObjectIdentifier: WeakLuaStateRef] = [:]

    /// Registers a LuaState instance
    func registerState(_ state: LuaState) {
        states[ObjectIdentifier(state)] = WeakLuaStateRef(state)
    }

    /// Unregisters a LuaState instance
    func unregisterState(_ state: LuaState) {
        states.removeValue(forKey: ObjectIdentifier(state))
    }

    /// Returns count of active states (for debugging)
    func activeStateCount() -> Int {
        // Clean up deallocated states while counting
        states = states.filter { $0.value.state != nil }
        return states.count
    }

    // MARK: - Async Handles (from LuaAsyncSupport)

    /// Active async operation handles
    private var asyncHandles: [UUID: LuaAsyncHandleProtocol] = [:]

    /// Registers an async handle
    func registerAsyncHandle(_ handle: LuaAsyncHandleProtocol, id: UUID) {
        asyncHandles[id] = handle
    }

    /// Retrieves an async handle
    func getAsyncHandle(id: UUID) -> LuaAsyncHandleProtocol? {
        asyncHandles[id]
    }

    /// Removes an async handle
    func removeAsyncHandle(id: UUID) {
        asyncHandles.removeValue(forKey: id)
    }

}

// MARK: - Closure Storage (Synchronous Access Required)

/// Thread-safe storage for Lua function closures.
///
/// This class is separate from `LuaKitRegistry` because C callbacks from Lua
/// require **synchronous** access to closure storage, which actors cannot provide.
/// Uses `@unchecked Sendable` with internal locking for Swift 6 compliance.
public final class LuaClosureStorage: @unchecked Sendable {
    /// Shared singleton instance
    public static let shared = LuaClosureStorage()

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// Registered closures by ID
    private var closures: [Int: (OpaquePointer) -> Int32] = [:]

    /// Retained function objects to prevent deallocation
    private var retainedFunctions: [Int: LuaFunction] = [:]

    /// Next available closure ID
    private var nextClosureId: Int = 1

    private init() {}

    /// Registers a closure and returns its ID
    public func registerClosure(_ closure: @escaping (OpaquePointer) -> Int32) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextClosureId
        nextClosureId += 1
        closures[id] = closure
        return id
    }

    /// Retrieves a closure by ID (returns nil if not found)
    public func getClosure(id: Int) -> ((OpaquePointer) -> Int32)? {
        lock.lock()
        defer { lock.unlock() }
        return closures[id]
    }

    /// Removes a closure by ID
    public func removeClosure(id: Int) {
        lock.lock()
        defer { lock.unlock() }
        closures.removeValue(forKey: id)
    }

    /// Retains a LuaFunction to prevent deallocation while Lua holds a reference
    public func retainFunction(_ function: LuaFunction, id: Int) {
        let replacedFunction: LuaFunction?
        lock.lock()
        replacedFunction = retainedFunctions.updateValue(function, forKey: id)
        lock.unlock()

        _ = replacedFunction
    }

    /// Releases a retained LuaFunction
    public func releaseFunction(id: Int) {
        let removedFunction: LuaFunction?
        lock.lock()
        removedFunction = retainedFunctions.removeValue(forKey: id)
        lock.unlock()

        _ = removedFunction
    }

    /// Removes both closure and retained function for an ID (used in deinit)
    public func removeAll(id: Int) {
        let removedFunction: LuaFunction?
        lock.lock()
        closures.removeValue(forKey: id)
        removedFunction = retainedFunctions.removeValue(forKey: id)
        lock.unlock()

        _ = removedFunction
    }
}

// MARK: - Supporting Types

/// Weak reference wrapper for LuaState
final class WeakLuaStateRef: @unchecked Sendable {
    weak var state: LuaState?

    init(_ state: LuaState) {
        self.state = state
    }
}

/// Protocol for type converters (Sendable-compatible)
public protocol LuaTypeConverterProtocol: Sendable {
    func push(value: Any, to state: OpaquePointer) -> Bool
    func pull(from state: OpaquePointer, at index: Int32) -> Any?
}

/// Protocol for property validators (Sendable-compatible)
public protocol PropertyValidatorProtocol: Sendable {
    func validate(_ value: Any) -> Bool
}

/// Protocol for property metadata (Sendable-compatible)
public protocol PropertyMetadataProtocol: Sendable {
    var isReadOnly: Bool { get }
    var propertyName: String { get }
}

/// Protocol for async handles (Sendable-compatible)
public protocol LuaAsyncHandleProtocol: Sendable {
    var id: UUID { get }
    func cancel()
}
