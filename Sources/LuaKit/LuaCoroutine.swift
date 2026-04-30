//
//  LuaCoroutine.swift
//  LuaKit
//
//  Provides a Swift wrapper for Lua coroutines with resume/yield support.
//

import Foundation
import Lua

/// A Swift wrapper for Lua coroutines (threads).
///
/// `LuaCoroutine` allows you to create and manage Lua coroutines from Swift,
/// supporting resume operations with typed return values.
///
/// Example:
/// ```swift
/// let coro = try lua.createCoroutine("""
///     for i = 1, 5 do
///         coroutine.yield(i * 10)
///     end
///     return "done"
/// """)
///
/// while coro.status == .suspended {
///     let value: Int = try coro.resume()
///     print(value)  // 10, 20, 30, 40, 50
/// }
/// ```
public final class LuaCoroutine: @unchecked Sendable {
    /// The status of a coroutine.
    public enum Status: Sendable {
        /// The coroutine is suspended (can be resumed).
        case suspended
        /// The coroutine is currently running.
        case running
        /// The coroutine has finished execution.
        case dead
    }

    /// The Lua thread (coroutine) state.
    private let thread: OpaquePointer
    /// Reference to the thread in the registry (to prevent GC).
    private let threadReference: Int32
    /// The parent Lua state.
    private weak var luaState: LuaState?
    /// Lock for thread safety.
    private let lock = NSLock()

    /// Creates a coroutine from Lua code.
    ///
    /// The code is compiled as a function and pushed onto the new coroutine's stack.
    ///
    /// - Parameters:
    ///   - state: The Lua state to create the coroutine in.
    ///   - code: The Lua code to execute in the coroutine.
    /// - Throws: `LuaError.syntax` if the code has syntax errors.
    public init(from state: LuaState, code: String) throws {
        let created = try state.withLuaLock {
            let L = state.luaState

            // Create a new thread (coroutine)
            guard let newThread = lua_newthread(L) else {
                throw LuaError.memoryAllocation
            }

            // Store thread reference to prevent garbage collection
            let threadReference = luaL_ref(L, luaRegistryIndex)

            // Load the code onto the new thread's stack
            let loadResult = luaL_loadstring(newThread, code)
            if loadResult != LUA_OK {
                let errorMsg = luaString(newThread, at: -1) ?? "Unknown coroutine syntax error"
                lua_pop(newThread, 1)
                luaL_unref(L, luaRegistryIndex, threadReference)
                throw LuaError.syntax(errorMsg)
            }

            state.registerThread(newThread)
            return (thread: newThread, reference: threadReference)
        }

        self.thread = created.thread
        self.threadReference = created.reference
        self.luaState = state
    }

    /// Creates a coroutine from an existing callable.
    ///
    /// - Parameter callable: The LuaCallable to run as a coroutine.
    /// - Throws: `LuaError.stateInvalid` if the callable's state is invalid.
    public init(from callable: LuaCallable) throws {
        guard let state = callable.state else {
            throw LuaError.stateInvalid
        }

        let created = try state.withLuaLock {
            let L = state.luaState

            // Create a new thread (coroutine)
            guard let newThread = lua_newthread(L) else {
                throw LuaError.memoryAllocation
            }

            // Store thread reference to prevent garbage collection
            let threadReference = luaL_ref(L, luaRegistryIndex)

            // Push the callable's function onto the main stack
            callable.pushFunction()

            // Move the function from the main stack to the coroutine's stack
            lua_xmove(L, newThread, 1)
            state.registerThread(newThread)
            return (thread: newThread, reference: threadReference)
        }

        self.thread = created.thread
        self.threadReference = created.reference
        self.luaState = state
    }

    deinit {
        lock.lock()
        let state = luaState
        lock.unlock()

        if let state {
            state.withLuaLock {
                state.unregisterThread(thread)
                luaL_unref(state.luaState, luaRegistryIndex, threadReference)
            }
        }
    }

    /// Returns whether the coroutine is still valid (Lua state is alive).
    public var isValid: Bool {
        lock.lock()
        defer { lock.unlock() }
        return luaState != nil
    }

    /// The current status of the coroutine.
    public var status: Status {
        lock.lock()
        guard let state = luaState else {
            lock.unlock()
            return .dead
        }
        defer { lock.unlock() }

        return state.withLuaLock {
            let luaStatus = lua_status(thread)

            switch luaStatus {
            case LUA_OK:
                // LUA_OK means the coroutine is either newly created or finished
                // Check if there's a function on the stack (newly created)
                if lua_gettop(thread) > 0 && lua_type(thread, 1) == LUA_TFUNCTION {
                    return .suspended
                }
                return .dead
            case LUA_YIELD:
                return .suspended
            default:
                // Any error status means the coroutine is dead
                return .dead
            }
        }
    }

    // MARK: - Private Helpers

    private func extractError() -> LuaError {
        if let error = luaString(thread, at: -1) {
            lua_pop(thread, 1)
            return .coroutineError(error)
        }
        lua_pop(thread, 1)
        return .coroutineError("Unknown coroutine error")
    }

    private func pullResult<R: LuaConvertible>() throws -> R {
        guard let result = R.pull(from: thread, at: -1) else {
            let actualType = String(cString: lua_typename(thread, lua_type(thread, -1)))
            lua_pop(thread, 1)
            throw LuaError.typeMismatch(expected: String(describing: R.self), got: actualType)
        }
        lua_pop(thread, 1)
        return result
    }

    private func withValidState<R>(_ body: (LuaState) throws -> R) throws -> R {
        lock.lock()
        guard let state = luaState else {
            lock.unlock()
            throw LuaError.stateInvalid
        }

        defer { lock.unlock() }
        return try state.withLuaLock {
            try body(state)
        }
    }

    // MARK: - Resume Methods

    /// Resumes the coroutine with no arguments and returns a value.
    ///
    /// - Returns: The yielded or returned value.
    /// - Throws: `LuaError.stateInvalid` if the state is invalid,
    ///           `LuaError.coroutineError` if the coroutine cannot be resumed.
    public func resume<R: LuaConvertible>() throws -> R {
        try withValidState { state in
            var nresults: Int32 = 0
            let result = state.protectedResume(thread: thread, argumentCount: 0, resultCount: &nresults)

            if result != LUA_OK && result != LUA_YIELD {
                throw extractError()
            }

            if nresults == 0 {
                throw LuaError.coroutineError("Coroutine did not return a value")
            }

            return try pullResult()
        }
    }

    /// Resumes the coroutine with one argument and returns a value.
    ///
    /// - Parameter arg1: The argument to pass to the coroutine.
    /// - Returns: The yielded or returned value.
    /// - Throws: `LuaError.stateInvalid` if the state is invalid.
    public func resume<T1: LuaConvertible, R: LuaConvertible>(_ arg1: T1) throws -> R {
        try withValidState { state in
            T1.push(arg1, to: thread)

            var nresults: Int32 = 0
            let result = state.protectedResume(thread: thread, argumentCount: 1, resultCount: &nresults)

            if result != LUA_OK && result != LUA_YIELD {
                throw extractError()
            }

            if nresults == 0 {
                throw LuaError.coroutineError("Coroutine did not return a value")
            }

            return try pullResult()
        }
    }

    /// Resumes the coroutine with two arguments and returns a value.
    public func resume<T1: LuaConvertible, T2: LuaConvertible, R: LuaConvertible>(
        _ arg1: T1,
        _ arg2: T2
    ) throws -> R {
        try withValidState { state in
            T1.push(arg1, to: thread)
            T2.push(arg2, to: thread)

            var nresults: Int32 = 0
            let result = state.protectedResume(thread: thread, argumentCount: 2, resultCount: &nresults)

            if result != LUA_OK && result != LUA_YIELD {
                throw extractError()
            }

            if nresults == 0 {
                throw LuaError.coroutineError("Coroutine did not return a value")
            }

            return try pullResult()
        }
    }

    // MARK: - Resume Void (ignore return value)

    /// Resumes the coroutine with no arguments, ignoring the return value.
    ///
    /// - Throws: `LuaError.stateInvalid` if the state is invalid.
    public func resumeVoid() throws {
        try withValidState { state in
            var nresults: Int32 = 0
            let result = state.protectedResume(thread: thread, argumentCount: 0, resultCount: &nresults)

            if result != LUA_OK && result != LUA_YIELD {
                throw extractError()
            }

            // Pop any results
            if nresults > 0 {
                lua_pop(thread, nresults)
            }
        }
    }

    /// Resumes the coroutine with one argument, ignoring the return value.
    public func resumeVoid<T1: LuaConvertible>(_ arg1: T1) throws {
        try withValidState { state in
            T1.push(arg1, to: thread)

            var nresults: Int32 = 0
            let result = state.protectedResume(thread: thread, argumentCount: 1, resultCount: &nresults)

            if result != LUA_OK && result != LUA_YIELD {
                throw extractError()
            }

            // Pop any results
            if nresults > 0 {
                lua_pop(thread, nresults)
            }
        }
    }
}

// MARK: - LuaState Extension

public extension LuaState {
    /// Creates a coroutine from Lua code.
    ///
    /// - Parameter code: The Lua code to execute in the coroutine.
    /// - Returns: A new `LuaCoroutine`.
    /// - Throws: `LuaError.syntax` if the code has syntax errors.
    func createCoroutine(_ code: String) throws -> LuaCoroutine {
        return try LuaCoroutine(from: self, code: code)
    }

    /// Creates a coroutine from a global function.
    ///
    /// - Parameter name: The name of the global function.
    /// - Returns: A new `LuaCoroutine`.
    /// - Throws: `LuaError.functionNotFound` if the function doesn't exist.
    func createCoroutine(from name: String) throws -> LuaCoroutine {
        let callable = try getFunction(name)
        return try LuaCoroutine(from: callable)
    }
}
