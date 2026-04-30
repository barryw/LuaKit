//
//  LuaCallback.swift
//  LuaKit
//
//  Provides a thread-safe callback wrapper for Lua functions.
//

import Foundation
import Lua

/// A thread-safe wrapper for Lua functions that can be stored and called later.
///
/// `LuaCallback` is designed for callback patterns where a Lua function is passed
/// to Swift code and called later, potentially from different threads.
///
/// Example:
/// ```swift
/// class EventEmitter {
///     private var onEventCallback: LuaCallback?
///
///     func onEvent(_ callback: LuaCallback) {
///         self.onEventCallback = callback
///     }
///
///     func emit(_ value: Int) {
///         try? onEventCallback?.callVoid(value)
///     }
/// }
/// ```
public final class LuaCallback: @unchecked Sendable {
    private let reference: Int32
    private weak var luaState: LuaState?
    private let lock = NSLock()

    /// Creates a callback from a Lua function on the stack.
    ///
    /// The function at the given stack index is stored in the registry.
    ///
    /// - Parameters:
    ///   - state: The Lua state.
    ///   - stackIndex: The index of the function on the stack (default: -1, top of stack).
    /// - Throws: `LuaError.typeMismatch` if the value is not a function.
    public init(from state: LuaState, stackIndex: Int32 = -1) throws {
        let reference = try state.withLuaLock {
            let luaPointer = state.luaState

            guard lua_type(luaPointer, stackIndex) == LUA_TFUNCTION else {
                let actualType = String(cString: lua_typename(luaPointer, lua_type(luaPointer, stackIndex)))
                throw LuaError.typeMismatch(
                    expected: "function",
                    actual: actualType,
                    context: "Creating LuaCallback"
                )
            }

            // Push the function to the top if it's not already there
            if stackIndex != -1 {
                lua_pushvalue(luaPointer, stackIndex)
            }

            return luaL_ref(luaPointer, luaRegistryIndex)
        }

        self.reference = reference
        self.luaState = state
    }

    /// Creates a callback from a callable reference.
    ///
    /// - Parameter callable: An existing LuaCallable to convert to a callback.
    public init(from callable: LuaCallable) throws {
        guard let state = callable.state else {
            throw LuaError.stateInvalid
        }

        let reference = state.withLuaLock {
            let luaPointer = state.luaState
            // Push the callable's function onto the stack
            callable.pushFunction()
            return luaL_ref(luaPointer, luaRegistryIndex)
        }

        self.reference = reference
        self.luaState = state
    }

    deinit {
        lock.lock()
        let state = luaState
        lock.unlock()

        if let state {
            state.withLuaLock {
                luaL_unref(state.luaState, luaRegistryIndex, reference)
            }
        }
    }

    /// Returns whether the callback is still valid (Lua state is alive).
    public var isValid: Bool {
        lock.lock()
        defer { lock.unlock() }
        return luaState != nil
    }

    /// The Lua state this callback belongs to, if still valid.
    public var state: LuaState? {
        lock.lock()
        defer { lock.unlock() }
        return luaState
    }

    // MARK: - Private Helpers

    private func pushFunction(to luaPointer: OpaquePointer) {
        lua_rawgeti(luaPointer, luaRegistryIndex, lua_Integer(reference))
    }

    private func extractError(from luaPointer: OpaquePointer) -> LuaError {
        if let error = luaString(luaPointer, at: -1) {
            lua_pop(luaPointer, 1)
            return .runtime(error)
        }
        lua_pop(luaPointer, 1)
        return .runtime("Unknown error")
    }

    private func pullResult<R: LuaConvertible>(from luaPointer: OpaquePointer) throws -> R {
        guard let result = R.pull(from: luaPointer, at: -1) else {
            let actualType = String(cString: lua_typename(luaPointer, lua_type(luaPointer, -1)))
            lua_pop(luaPointer, 1)
            throw LuaError.typeMismatch(expected: String(describing: R.self), got: actualType)
        }
        lua_pop(luaPointer, 1)
        return result
    }

    private func validState() throws -> LuaState {
        lock.lock()
        defer { lock.unlock() }

        guard let state = luaState else {
            throw LuaError.stateInvalid
        }

        return state
    }

    private func callReturning<R: LuaConvertible>(
        argumentCount: Int32,
        pushArguments: (OpaquePointer) -> Void
    ) throws -> R {
        let state = try validState()

        return try state.withLuaLock {
            let luaPointer = state.luaState
            pushFunction(to: luaPointer)
            pushArguments(luaPointer)

            if state.protectedCall(argumentCount: argumentCount, resultCount: 1) != LUA_OK {
                throw extractError(from: luaPointer)
            }

            return try pullResult(from: luaPointer)
        }
    }

    private func callDiscardingResult(
        argumentCount: Int32,
        pushArguments: (OpaquePointer) -> Void
    ) throws {
        let state = try validState()

        try state.withLuaLock {
            let luaPointer = state.luaState
            pushFunction(to: luaPointer)
            pushArguments(luaPointer)

            if state.protectedCall(argumentCount: argumentCount, resultCount: 0) != LUA_OK {
                throw extractError(from: luaPointer)
            }
        }
    }

    // MARK: - Call with Return Value

    /// Calls the Lua callback with no arguments and returns a value.
    ///
    /// - Returns: The return value converted to the specified type.
    /// - Throws: If the Lua state is invalid or the call fails.
    public func call<R: LuaConvertible>() throws -> R {
        try callReturning(argumentCount: 0) { _ in }
    }

    /// Calls the Lua callback with one argument and returns a value.
    public func call<T1: LuaConvertible, R: LuaConvertible>(_ arg1: T1) throws -> R {
        try callReturning(argumentCount: 1) { luaPointer in
            T1.push(arg1, to: luaPointer)
        }
    }

    /// Calls the Lua callback with two arguments and returns a value.
    public func call<T1: LuaConvertible, T2: LuaConvertible, R: LuaConvertible>(
        _ arg1: T1,
        _ arg2: T2
    ) throws -> R {
        try callReturning(argumentCount: 2) { luaPointer in
            T1.push(arg1, to: luaPointer)
            T2.push(arg2, to: luaPointer)
        }
    }

    /// Calls the Lua callback with three arguments and returns a value.
    public func call<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible, R: LuaConvertible>(
        _ arg1: T1,
        _ arg2: T2,
        _ arg3: T3
    ) throws -> R {
        try callReturning(argumentCount: 3) { luaPointer in
            T1.push(arg1, to: luaPointer)
            T2.push(arg2, to: luaPointer)
            T3.push(arg3, to: luaPointer)
        }
    }

    // MARK: - Call Void (No Return Value)

    /// Calls the Lua callback with no arguments, ignoring the return value.
    ///
    /// - Throws: If the Lua state is invalid or the call fails.
    public func callVoid() throws {
        try callDiscardingResult(argumentCount: 0) { _ in }
    }

    /// Calls the Lua callback with one argument, ignoring the return value.
    public func callVoid<T1: LuaConvertible>(_ arg1: T1) throws {
        try callDiscardingResult(argumentCount: 1) { luaPointer in
            T1.push(arg1, to: luaPointer)
        }
    }

    /// Calls the Lua callback with two arguments, ignoring the return value.
    public func callVoid<T1: LuaConvertible, T2: LuaConvertible>(_ arg1: T1, _ arg2: T2) throws {
        try callDiscardingResult(argumentCount: 2) { luaPointer in
            T1.push(arg1, to: luaPointer)
            T2.push(arg2, to: luaPointer)
        }
    }

    /// Calls the Lua callback with three arguments, ignoring the return value.
    public func callVoid<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible>(
        _ arg1: T1,
        _ arg2: T2,
        _ arg3: T3
    ) throws {
        try callDiscardingResult(argumentCount: 3) { luaPointer in
            T1.push(arg1, to: luaPointer)
            T2.push(arg2, to: luaPointer)
            T3.push(arg3, to: luaPointer)
        }
    }

    /// Calls the Lua callback with four arguments, ignoring the return value.
    public func callVoid<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible, T4: LuaConvertible>(
        _ arg1: T1,
        _ arg2: T2,
        _ arg3: T3,
        _ arg4: T4
    ) throws {
        try callDiscardingResult(argumentCount: 4) { luaPointer in
            T1.push(arg1, to: luaPointer)
            T2.push(arg2, to: luaPointer)
            T3.push(arg3, to: luaPointer)
            T4.push(arg4, to: luaPointer)
        }
    }
}

// MARK: - LuaState Extension

public extension LuaState {
    /// Creates a callback from the function at the top of the stack.
    ///
    /// - Returns: A `LuaCallback` wrapping the function.
    /// - Throws: `LuaError.typeMismatch` if the top of stack is not a function.
    func createCallback() throws -> LuaCallback {
        return try LuaCallback(from: self)
    }

    /// Creates a callback from a global function.
    ///
    /// - Parameter name: The name of the global function.
    /// - Returns: A `LuaCallback` wrapping the function.
    /// - Throws: `LuaError.functionNotFound` if the global is not a function.
    func getCallback(_ name: String) throws -> LuaCallback {
        try withLuaLock {
            lua_getglobal(luaState, name)

            guard lua_type(luaState, -1) == LUA_TFUNCTION else {
                let actualType = String(cString: lua_typename(luaState, lua_type(luaState, -1)))
                lua_pop(luaState, 1)
                throw LuaError.functionNotFound("Global '\(name)' is not a function (got \(actualType))")
            }

            return try LuaCallback(from: self)
        }
    }
}
