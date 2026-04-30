//
//  LuaCallable.swift
//  LuaKit
//
//  Provides the ability to call Lua functions from Swift code.
//

import Foundation
import Lua

/// A reference to a Lua function that can be called from Swift.
///
/// `LuaCallable` allows you to get a reference to a Lua function and call it
/// with type-safe Swift arguments and return values.
///
/// Example:
/// ```swift
/// let lua = try LuaState()
/// try lua.execute("""
///     function greet(name)
///         return "Hello, " .. name .. "!"
///     end
/// """)
///
/// let greet = try lua.getFunction("greet")
/// let result: String = try greet.call("World")
/// print(result)  // "Hello, World!"
/// ```
public final class LuaCallable {
    private let reference: Int32
    private weak var luaState: LuaState?

    /// Creates a callable reference to a global Lua function.
    ///
    /// - Parameters:
    ///   - state: The Lua state containing the function.
    ///   - name: The name of the global function.
    /// - Throws: `LuaError.functionNotFound` if the global is not a function.
    public init(from state: LuaState, name: String) throws {
        let reference = try state.withLuaLock {
            let L = state.luaState
            lua_getglobal(L, name)

            guard lua_type(L, -1) == LUA_TFUNCTION else {
                let actualType = String(cString: lua_typename(L, lua_type(L, -1)))
                lua_pop(L, 1)
                throw LuaError.functionNotFound("Global '\(name)' is not a function (got \(actualType))")
            }

            return luaL_ref(L, luaRegistryIndex)
        }

        self.reference = reference
        self.luaState = state
    }

    /// Creates a callable reference to a function at a path (e.g., "Module.submodule.func").
    ///
    /// - Parameters:
    ///   - state: The Lua state containing the function.
    ///   - path: The dot-separated path to the function.
    /// - Throws: `LuaError.functionNotFound` if the path doesn't lead to a function.
    public init(from state: LuaState, path: String) throws {
        let components = path.split(separator: ".").map(String.init)

        guard !components.isEmpty else {
            throw LuaError.functionNotFound("Empty path")
        }

        let reference = try state.withLuaLock {
            let L = state.luaState

            // Get the first component from globals
            lua_getglobal(L, components[0])

            // Navigate through the remaining components
            for (index, component) in components.dropFirst().enumerated() {
                guard lua_type(L, -1) == LUA_TTABLE else {
                    let actualType = String(cString: lua_typename(L, lua_type(L, -1)))
                    lua_pop(L, 1)
                    let partialPath = components[0...index].joined(separator: ".")
                    throw LuaError.functionNotFound("'\(partialPath)' is not a table (got \(actualType))")
                }
                lua_getfield(L, -1, component)
                // Remove the parent table (equivalent to lua_remove)
                lua_rotate(L, -2, -1)
                lua_settop(L, -2)
            }

            guard lua_type(L, -1) == LUA_TFUNCTION else {
                let actualType = String(cString: lua_typename(L, lua_type(L, -1)))
                lua_pop(L, 1)
                throw LuaError.functionNotFound("'\(path)' is not a function (got \(actualType))")
            }

            return luaL_ref(L, luaRegistryIndex)
        }

        self.reference = reference
        self.luaState = state
    }

    deinit {
        if let luaState = luaState {
            luaState.withLuaLock {
                luaL_unref(luaState.luaState, luaRegistryIndex, reference)
            }
        }
    }

    // MARK: - Public Accessors

    /// The Lua state this callable belongs to, if still valid.
    public var state: LuaState? {
        return luaState
    }

    /// Pushes the referenced function onto the Lua stack.
    public func pushFunction() {
        guard let luaState = luaState else { return }
        luaState.withLuaLock {
            lua_rawgeti(luaState.luaState, luaRegistryIndex, lua_Integer(reference))
        }
    }

    private func callReturning<R: LuaConvertible>(
        argumentCount: Int32,
        pushArguments: (OpaquePointer) -> Void
    ) throws -> R {
        guard let luaState = luaState else {
            throw LuaError.runtime("LuaState has been deallocated")
        }

        return try luaState.withLuaLock {
            let L = luaState.luaState
            pushFunction(to: L)
            pushArguments(L)

            if luaState.protectedCall(argumentCount: argumentCount, resultCount: 1) != LUA_OK {
                throw extractError(from: L)
            }

            return try pullResult(from: L)
        }
    }

    private func callDiscardingResult(
        argumentCount: Int32,
        pushArguments: (OpaquePointer) -> Void
    ) throws {
        guard let luaState = luaState else {
            throw LuaError.runtime("LuaState has been deallocated")
        }

        try luaState.withLuaLock {
            let L = luaState.luaState
            pushFunction(to: L)
            pushArguments(L)

            if luaState.protectedCall(argumentCount: argumentCount, resultCount: 0) != LUA_OK {
                throw extractError(from: L)
            }
        }
    }

    // MARK: - Call with Return Value

    /// Calls the Lua function with no arguments and returns the result.
    public func call<R: LuaConvertible>() throws -> R {
        try callReturning(argumentCount: 0) { _ in }
    }

    /// Calls the Lua function with one argument and returns the result.
    public func call<T1: LuaConvertible, R: LuaConvertible>(_ arg1: T1) throws -> R {
        try callReturning(argumentCount: 1) { L in
            T1.push(arg1, to: L)
        }
    }

    /// Calls the Lua function with two arguments and returns the result.
    public func call<T1: LuaConvertible, T2: LuaConvertible, R: LuaConvertible>(
        _ arg1: T1, _ arg2: T2
    ) throws -> R {
        try callReturning(argumentCount: 2) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
        }
    }

    /// Calls the Lua function with three arguments and returns the result.
    public func call<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible, R: LuaConvertible>(
        _ arg1: T1, _ arg2: T2, _ arg3: T3
    ) throws -> R {
        try callReturning(argumentCount: 3) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
            T3.push(arg3, to: L)
        }
    }

    /// Calls the Lua function with four arguments and returns the result.
    public func call<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible,
                     T4: LuaConvertible, R: LuaConvertible>(
        _ arg1: T1, _ arg2: T2, _ arg3: T3, _ arg4: T4
    ) throws -> R {
        try callReturning(argumentCount: 4) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
            T3.push(arg3, to: L)
            T4.push(arg4, to: L)
        }
    }

    /// Calls the Lua function with five arguments and returns the result.
    public func call<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible,
                     T4: LuaConvertible, T5: LuaConvertible, R: LuaConvertible>(
        _ arg1: T1, _ arg2: T2, _ arg3: T3, _ arg4: T4, _ arg5: T5
    ) throws -> R {
        try callReturning(argumentCount: 5) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
            T3.push(arg3, to: L)
            T4.push(arg4, to: L)
            T5.push(arg5, to: L)
        }
    }

    /// Calls the Lua function with six arguments and returns the result.
    public func call<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible,
                     T4: LuaConvertible, T5: LuaConvertible, T6: LuaConvertible, R: LuaConvertible>(
        _ arg1: T1, _ arg2: T2, _ arg3: T3, _ arg4: T4, _ arg5: T5, _ arg6: T6
    ) throws -> R {
        try callReturning(argumentCount: 6) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
            T3.push(arg3, to: L)
            T4.push(arg4, to: L)
            T5.push(arg5, to: L)
            T6.push(arg6, to: L)
        }
    }

    // MARK: - Call with Void Return

    /// Calls the Lua function with no arguments, ignoring any return value.
    public func callVoid() throws {
        try callDiscardingResult(argumentCount: 0) { _ in }
    }

    /// Calls the Lua function with one argument, ignoring any return value.
    public func callVoid<T1: LuaConvertible>(_ arg1: T1) throws {
        try callDiscardingResult(argumentCount: 1) { L in
            T1.push(arg1, to: L)
        }
    }

    /// Calls the Lua function with two arguments, ignoring any return value.
    public func callVoid<T1: LuaConvertible, T2: LuaConvertible>(_ arg1: T1, _ arg2: T2) throws {
        try callDiscardingResult(argumentCount: 2) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
        }
    }

    /// Calls the Lua function with three arguments, ignoring any return value.
    public func callVoid<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible>(
        _ arg1: T1, _ arg2: T2, _ arg3: T3
    ) throws {
        try callDiscardingResult(argumentCount: 3) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
            T3.push(arg3, to: L)
        }
    }

    /// Calls the Lua function with four arguments, ignoring any return value.
    public func callVoid<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible,
                         T4: LuaConvertible>(
        _ arg1: T1, _ arg2: T2, _ arg3: T3, _ arg4: T4
    ) throws {
        try callDiscardingResult(argumentCount: 4) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
            T3.push(arg3, to: L)
            T4.push(arg4, to: L)
        }
    }

    /// Calls the Lua function with five arguments, ignoring any return value.
    public func callVoid<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible,
                         T4: LuaConvertible, T5: LuaConvertible>(
        _ arg1: T1, _ arg2: T2, _ arg3: T3, _ arg4: T4, _ arg5: T5
    ) throws {
        try callDiscardingResult(argumentCount: 5) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
            T3.push(arg3, to: L)
            T4.push(arg4, to: L)
            T5.push(arg5, to: L)
        }
    }

    /// Calls the Lua function with six arguments, ignoring any return value.
    public func callVoid<T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible,
                         T4: LuaConvertible, T5: LuaConvertible, T6: LuaConvertible>(
        _ arg1: T1, _ arg2: T2, _ arg3: T3, _ arg4: T4, _ arg5: T5, _ arg6: T6
    ) throws {
        try callDiscardingResult(argumentCount: 6) { L in
            T1.push(arg1, to: L)
            T2.push(arg2, to: L)
            T3.push(arg3, to: L)
            T4.push(arg4, to: L)
            T5.push(arg5, to: L)
            T6.push(arg6, to: L)
        }
    }

    // MARK: - Private Helpers

    private func pushFunction(to L: OpaquePointer) {
        lua_rawgeti(L, luaRegistryIndex, lua_Integer(reference))
    }

    private func extractError(from L: OpaquePointer) -> LuaError {
        if let error = luaString(L, at: -1) {
            lua_pop(L, 1)
            return .runtime(error)
        }
        lua_pop(L, 1)
        return .runtime("Unknown error")
    }

    private func pullResult<R: LuaConvertible>(from L: OpaquePointer) throws -> R {
        guard let result = R.pull(from: L, at: -1) else {
            let actualType = String(cString: lua_typename(L, lua_type(L, -1)))
            lua_pop(L, 1)
            throw LuaError.typeMismatch(expected: String(describing: R.self), got: actualType)
        }
        lua_pop(L, 1)
        return result
    }
}

// MARK: - LuaState Extension

public extension LuaState {
    /// Gets a callable reference to a global Lua function.
    ///
    /// - Parameter name: The name of the global function.
    /// - Returns: A `LuaCallable` that can be used to call the function.
    /// - Throws: `LuaError.functionNotFound` if the global is not a function.
    func getFunction(_ name: String) throws -> LuaCallable {
        return try LuaCallable(from: self, name: name)
    }

    /// Gets a callable reference to a Lua function at a path.
    ///
    /// - Parameter path: The dot-separated path to the function (e.g., "Module.func").
    /// - Returns: A `LuaCallable` that can be used to call the function.
    /// - Throws: `LuaError.functionNotFound` if the path doesn't lead to a function.
    func getFunction(path: String) throws -> LuaCallable {
        return try LuaCallable(from: self, path: path)
    }
}
