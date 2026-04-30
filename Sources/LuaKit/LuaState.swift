//
//  LuaState.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

import Foundation
import Lua
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class LuaState: @unchecked Sendable {
    private let L: OpaquePointer
    private let stateLock = NSRecursiveLock()
    private let memoryQuota: LuaMemoryQuota?
    private var sandboxConfigurationStorage: LuaSandboxConfiguration?
    private var activeSandboxConfiguration: LuaSandboxConfiguration?
    private var sandboxInstructionCount = 0
    private var sandboxDeadline: Date?

    /// Internal access to the Lua state for extensions
    internal var luaState: OpaquePointer { L }

    public convenience init() throws {
        try self.init(libraries: .all, sandbox: nil)
    }

    /// Initialize a Lua state with selective library loading.
    ///
    /// This initializer allows you to control which standard libraries are loaded,
    /// enabling sandboxed execution environments that don't have access to potentially
    /// dangerous functionality like file I/O or OS commands.
    ///
    /// - Parameter libraries: The libraries to load. Use `.all` for all libraries,
    ///   `.sandboxed` for a safe subset, or a custom combination.
    ///
    /// Example:
    /// ```swift
    /// // Full access (equivalent to LuaState())
    /// let lua = try LuaState(libraries: .all)
    ///
    /// // Sandboxed - no io, os, debug, package
    /// let sandbox = try LuaState(libraries: .sandboxed)
    ///
    /// // Custom selection
    /// let custom = try LuaState(libraries: [.base, .string, .math])
    /// ```
    public convenience init(libraries: LuaLibrary) throws {
        try self.init(libraries: libraries, sandbox: nil)
    }

    /// Initialize a Lua state with sandbox controls.
    ///
    /// Memory limits are enforced from state creation. Instruction and wall-time
    /// limits are enforced for each protected call made through `LuaState` and
    /// `LuaCallable`.
    public convenience init(sandbox configuration: LuaSandboxConfiguration = .default) throws {
        try self.init(libraries: configuration.libraries, sandbox: configuration)
    }

    private init(libraries: LuaLibrary, sandbox configuration: LuaSandboxConfiguration?) throws {
        let quota = configuration?.memoryLimitBytes.map(LuaMemoryQuota.init(limit:))
        let state: OpaquePointer?

        if let quota {
            state = lua_newstate(
                LuaState.memoryQuotaAllocator,
                Unmanaged.passUnretained(quota).toOpaque(),
                luaL_makeseed(nil)
            )
        } else {
            state = luaL_newstate()
        }

        guard let state else {
            throw LuaError.memoryAllocation
        }

        self.L = state
        self.memoryQuota = quota
        self.sandboxConfigurationStorage = configuration

        // Lua 5.5.0: Use luaL_openselectedlibs with the library bitmask.
        luaL_openselectedlibs(L, Int32(libraries.rawValue), 0)
        setupPrintCapture()
        registerArrayProxyTypes()

        if configuration?.removeUnsafeGlobals == true {
            removeUnsafeGlobals()
        }
    }

    deinit {
        withLuaLock {
            LuaState.stateStorage.unregister(L)
            lua_sethook(L, nil, 0, 0)
            lua_close(L)
        }
    }

    private var printOutput: String = ""
    private var printHandler: ((String) -> Void)?
    private var maxPrintBufferSize: Int = 1_000_000  // 1MB default
    private var printBufferPolicy: PrintBufferPolicy = .unlimited

    /// Policy for managing print buffer size and behavior
    public enum PrintBufferPolicy: Sendable {
        case unlimited
        case truncateOldest
        case truncateNewest
        case maxSize(Int)
    }

    /// Type alias for output handlers that receive print output immediately
    public typealias PrintOutputHandler = (String) -> Void

    /// Set a handler to receive Lua print output.
    ///
    /// The handler is called each time Lua's `print()` function is invoked.
    ///
    /// - Parameter handler: A closure that receives each line of print output.
    public func onPrint(_ handler: @escaping (String) -> Void) {
        withLuaLock {
            self.printHandler = handler
        }
    }

    @available(*, deprecated, renamed: "onPrint(_:)")
    public func setPrintHandler(_ handler: @escaping (String) -> Void) {
        withLuaLock {
            self.printHandler = handler
        }
    }

    /// Configure the print buffer policy for managing output accumulation
    public func setPrintBufferPolicy(_ policy: PrintBufferPolicy) {
        withLuaLock {
            self.printBufferPolicy = policy
        }
    }

    @available(*, deprecated, renamed: "onPrint(_:)")
    public func setOutputHandler(_ handler: @escaping PrintOutputHandler) {
        withLuaLock {
            self.printHandler = handler
        }
    }

    /// Clear the print buffer manually
    public func clearPrintBuffer() {
        withLuaLock {
            printOutput = ""
        }
    }

    /// Get current buffer contents without executing any code
    public func getCurrentPrintBuffer() -> String {
        withLuaLock {
            return printOutput
        }
    }

    private func setupPrintCapture() {
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            let state = LuaState.stateStorage[L]

            let n = lua_gettop(L)
            var output = ""

            if n > 0 {
                for i in 1...n {
                    if i > 1 { output += "\t" }

                    if luaL_callmeta(L, i, "__tostring") != 0 {
                        if let str = luaString(L, at: -1) {
                            output += str
                        }
                        lua_settop(L, -2)
                    } else {
                        let type = lua_type(L, i)
                        switch type {
                        case LUA_TNIL:
                            output += "nil"
                        case LUA_TBOOLEAN:
                            output += lua_toboolean(L, i) != 0 ? "true" : "false"
                        case LUA_TNUMBER:
                            if lua_isinteger(L, i) != 0 {
                                output += String(lua_tointegerx(L, i, nil))
                            } else {
                                output += String(lua_tonumberx(L, i, nil))
                            }
                        case LUA_TSTRING:
                            if let str = luaString(L, at: i) {
                                output += str
                            }
                        default:
                            if luaL_tolstring(L, i, nil) != nil {
                                if let str = luaString(L, at: -1) {
                                    output += str
                                }
                                lua_settop(L, -2)
                            }
                        }
                    }
                }
            }

            output += "\n"
            state?.withLuaLock {
                state?.printOutput += output
                state?.printHandler?(output)
            }

            return 0
        }, 0)
        lua_setglobal(L, "print")

        LuaState.stateStorage.register(self, for: L)
    }

    /// Thread-safe storage for LuaState lookup by raw pointer.
    /// This is needed for C callbacks (like print) to find the Swift LuaState.
    private final class StateStorage: @unchecked Sendable {
        private final class WeakState {
            weak var state: LuaState?

            init(_ state: LuaState) {
                self.state = state
            }
        }

        private var states: [OpaquePointer: WeakState] = [:]
        private let lock = NSLock()

        static let shared = StateStorage()

        subscript(_ L: OpaquePointer) -> LuaState? {
            get {
                lock.lock()
                defer { lock.unlock() }
                guard let state = states[L]?.state else {
                    states.removeValue(forKey: L)
                    return nil
                }
                return state
            }
        }

        func register(_ state: LuaState, for L: OpaquePointer) {
            lock.lock()
            defer { lock.unlock() }
            states[L] = WeakState(state)
        }

        func unregister(_ L: OpaquePointer) {
            lock.lock()
            defer { lock.unlock() }
            states.removeValue(forKey: L)
        }
    }

    private static var stateStorage: StateStorage { StateStorage.shared }

    /// Current sandbox configuration for this state, if one is active.
    public var sandboxConfiguration: LuaSandboxConfiguration? {
        withLuaLock {
            sandboxConfigurationStorage
        }
    }

    /// Current Lua allocator usage when the state was created with a memory limit.
    public var currentMemoryUsage: Int? {
        memoryQuota?.currentUsage
    }

    /// Peak Lua allocator usage when the state was created with a memory limit.
    public var peakMemoryUsage: Int? {
        memoryQuota?.peakUsage
    }

    /// Update instruction and wall-time sandbox controls for future protected calls.
    ///
    /// Memory limits cannot be changed after state creation because Lua's allocator
    /// is installed when the state is created.
    public func configureSandbox(_ configuration: LuaSandboxConfiguration?) {
        withLuaLock {
            sandboxConfigurationStorage = configuration
            if configuration?.removeUnsafeGlobals == true {
                removeUnsafeGlobals()
            }
        }
    }

    /// Execute direct Lua C API access while holding the state's serialization lock.
    ///
    /// This is useful for advanced integrations that need raw pointer access but
    /// still want the same per-state concurrency model used by LuaKit.
    public func withExclusiveAccess<R>(_ body: (OpaquePointer) throws -> R) rethrows -> R {
        try withLuaLock {
            try body(L)
        }
    }

    @discardableResult
    internal func withLuaLock<R>(_ body: () throws -> R) rethrows -> R {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try body()
    }

    @discardableResult
    internal func protectedCall(argumentCount: Int32, resultCount: Int32) -> Int32 {
        installSandboxHookIfNeeded(on: L)
        defer { clearSandboxHook(from: L) }
        return lua_pcallk(L, argumentCount, resultCount, 0, 0, nil)
    }

    @discardableResult
    internal func protectedResume(
        thread: OpaquePointer,
        argumentCount: Int32,
        resultCount: inout Int32
    ) -> Int32 {
        installSandboxHookIfNeeded(on: thread)
        defer { clearSandboxHook(from: thread) }
        return lua_resume(thread, nil, argumentCount, &resultCount)
    }

    internal func registerThread(_ thread: OpaquePointer) {
        LuaState.stateStorage.register(self, for: thread)
    }

    internal func unregisterThread(_ thread: OpaquePointer) {
        LuaState.stateStorage.unregister(thread)
    }

    private func installSandboxHookIfNeeded(on state: OpaquePointer) {
        guard let configuration = sandboxConfigurationStorage,
              configuration.instructionLimit != nil || configuration.wallTimeLimit != nil else {
            return
        }

        activeSandboxConfiguration = configuration
        sandboxInstructionCount = 0
        sandboxDeadline = configuration.wallTimeLimit.map { Date().addingTimeInterval($0) }
        lua_sethook(state, LuaState.sandboxHook, LUA_MASKCOUNT, Int32(configuration.hookInterval))
    }

    private func clearSandboxHook(from state: OpaquePointer) {
        guard activeSandboxConfiguration != nil else { return }
        lua_sethook(state, nil, 0, 0)
        activeSandboxConfiguration = nil
        sandboxInstructionCount = 0
        sandboxDeadline = nil
    }

    private func sandboxViolationMessage() -> String? {
        guard let configuration = activeSandboxConfiguration else { return nil }

        sandboxInstructionCount += configuration.hookInterval
        if let limit = configuration.instructionLimit, sandboxInstructionCount >= limit {
            return "Lua sandbox instruction limit exceeded (\(limit) instructions)"
        }

        if let deadline = sandboxDeadline, Date() >= deadline {
            return "Lua sandbox wall-time limit exceeded"
        }

        return nil
    }

    private static let sandboxHook: lua_Hook = { L, _ in
        guard let L,
              let state = LuaState.stateStorage[L] else {
            return
        }

        let message = state.withLuaLock {
            state.sandboxViolationMessage()
        }

        if let message {
            luaPushString(L, message)
            _ = lua_error(L)
        }
    }

    private func removeUnsafeGlobals() {
        let names = [
            "collectgarbage", "debug", "dofile", "io", "loadfile",
            "os", "package", "require"
        ]

        for name in names {
            lua_pushnil(L)
            lua_setglobal(L, name)
        }
    }

    private static let memoryQuotaAllocator: lua_Alloc = { userData, pointer, oldSize, newSize in
        guard let userData else {
            if newSize == 0 {
                free(pointer)
                return nil
            }
            return realloc(pointer, newSize)
        }

        let quota = Unmanaged<LuaMemoryQuota>.fromOpaque(userData).takeUnretainedValue()
        return quota.reallocate(pointer: pointer, oldSize: oldSize, newSize: newSize)
    }

    private final class LuaMemoryQuota: @unchecked Sendable {
        let limit: Int
        private var usedBytes = 0
        private var peakBytes = 0
        private let lock = NSLock()

        init(limit: Int) {
            self.limit = limit
        }

        var currentUsage: Int {
            lock.lock()
            defer { lock.unlock() }
            return usedBytes
        }

        var peakUsage: Int {
            lock.lock()
            defer { lock.unlock() }
            return peakBytes
        }

        func reallocate(pointer: UnsafeMutableRawPointer?, oldSize: Int, newSize: Int) -> UnsafeMutableRawPointer? {
            lock.lock()
            defer { lock.unlock() }

            if newSize == 0 {
                usedBytes = max(0, usedBytes - oldSize)
                free(pointer)
                return nil
            }

            let delta = newSize - oldSize
            if delta > 0 && usedBytes + delta > limit {
                return nil
            }

            guard let newPointer = realloc(pointer, newSize) else {
                return nil
            }

            usedBytes = max(0, usedBytes + delta)
            peakBytes = max(peakBytes, usedBytes)
            return newPointer
        }
    }

    private func registerArrayProxyTypes() {
        // Register array proxy types for each supported element type
        LuaStringArrayProxy.register(in: self, as: "_StringArrayProxy")
        LuaIntArrayProxy.register(in: self, as: "_IntArrayProxy")
        LuaDoubleArrayProxy.register(in: self, as: "_DoubleArrayProxy")
        LuaBoolArrayProxy.register(in: self, as: "_BoolArrayProxy")
    }

    @discardableResult
    public func execute(_ code: String) throws -> String {
        try withLuaLock {
            // Don't reset buffer automatically - let user control this
            // printOutput = ""  // REMOVED - users can call clearPrintBuffer() if needed
            let baseTop = lua_gettop(L)

            if luaL_loadstring(L, code) != LUA_OK {
                let error = getError()
                throw LuaError.syntax(error)
            }

            if protectedCall(argumentCount: 0, resultCount: LUA_MULTRET) != LUA_OK {
                let error = getError()
                throw LuaError.runtime(error)
            }

            lua_settop(L, baseTop)
            return managePrintBuffer()
        }
    }

    /// Manage print buffer according to configured policy
    private func managePrintBuffer() -> String {
        switch printBufferPolicy {
        case .unlimited:
            return printOutput
        case .truncateOldest:
            if printOutput.count > maxPrintBufferSize {
                let offset = printOutput.count - maxPrintBufferSize
                let startIndex = printOutput.index(printOutput.startIndex, offsetBy: offset)
                printOutput = String(printOutput[startIndex...])
            }
            return printOutput
        case .truncateNewest:
            if printOutput.count > maxPrintBufferSize {
                printOutput = String(printOutput.prefix(maxPrintBufferSize))
            }
            return printOutput
        case .maxSize(let size):
            if printOutput.count > size {
                printOutput = String(printOutput.prefix(size))
            }
            return printOutput
        }
    }

    /// Execute Lua code and return a typed result.
    ///
    /// - Parameters:
    ///   - code: The Lua code to execute.
    ///   - returning: The expected return type.
    /// - Returns: The result converted to the specified type.
    /// - Throws: `LuaError.syntax` if the code has syntax errors,
    ///           `LuaError.runtime` if execution fails,
    ///           `LuaError.typeMismatch` if the result cannot be converted.
    ///
    /// Example:
    /// ```swift
    /// let sum: Int = try lua.execute("return 10 + 20", returning: Int.self)
    /// ```
    public func execute<T: LuaConvertible>(_ code: String, returning type: T.Type) throws -> T {
        try withLuaLock {
            let baseTop = lua_gettop(L)

            if luaL_loadstring(L, code) != LUA_OK {
                let error = getError()
                lua_settop(L, baseTop)
                throw LuaError.syntax(error)
            }

            if protectedCall(argumentCount: 0, resultCount: 1) != LUA_OK {
                let error = getError()
                lua_settop(L, baseTop)
                throw LuaError.runtime(error)
            }

            guard let result = T.pull(from: L, at: -1) else {
                let actualType = luaTypeName(at: -1)
                lua_settop(L, baseTop)
                throw LuaError.typeMismatch(expected: String(describing: T.self), got: actualType)
            }

            lua_settop(L, baseTop)
            return result
        }
    }

    @available(*, deprecated, renamed: "execute(_:returning:)")
    public func executeReturning<T: LuaConvertible>(_ code: String, as type: T.Type = T.self) throws -> T {
        return try execute(code, returning: type)
    }

    private func getError() -> String {
        if let error = luaString(L, at: -1) {
            lua_settop(L, -2)
            return error
        }
        lua_settop(L, -2)
        return "Unknown error"
    }

    private func luaTypeName(at index: Int32) -> String {
        let type = lua_type(L, index)
        if let name = lua_typename(L, type) {
            return String(cString: name)
        }
        return "unknown"
    }

    public func register<T: LuaBridgeable>(_ type: T.Type, as name: String) {
        withLuaLock {
            type.register(in: self, as: name)
        }
    }
}

/// A type that can be converted to and from Lua values.
///
/// This protocol is already implemented for common Swift types:
/// - `Bool`, `Int`, `Double`, `String`
/// - `[T]` where T: LuaConvertible
/// - `[String: T]` where T: LuaConvertible
/// - `Optional<T>` where T: LuaConvertible
///
/// Most users don't need to implement this protocol directly. Instead, use the
/// `@LuaBridgeable` macro for custom classes and structs.
///
/// - Note: Advanced users implementing this protocol must `import Lua` to access
///   the `OpaquePointer` type. This is the raw Lua state pointer.
public protocol LuaConvertible {
    /// Push a value onto the Lua stack.
    /// - Parameters:
    ///   - value: The value to push.
    ///   - L: The raw Lua state pointer (requires `import Lua`).
    static func push(_ value: Self, to L: OpaquePointer)

    /// Pull a value from the Lua stack.
    /// - Parameters:
    ///   - L: The raw Lua state pointer (requires `import Lua`).
    ///   - index: The stack index.
    /// - Returns: The converted value, or `nil` if conversion failed.
    static func pull(from L: OpaquePointer, at index: Int32) -> Self?
}

extension Bool: LuaConvertible {
    public static func push(_ value: Bool, to L: OpaquePointer) {
        lua_pushboolean(L, value ? 1 : 0)
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> Bool? {
        guard lua_type(L, index) == LUA_TBOOLEAN else { return nil }
        return lua_toboolean(L, index) != 0
    }
}

extension Int: LuaConvertible {
    public static func push(_ value: Int, to L: OpaquePointer) {
        lua_pushinteger(L, lua_Integer(value))
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> Int? {
        guard lua_type(L, index) == LUA_TNUMBER else { return nil }
        return Int(lua_tointegerx(L, index, nil))
    }
}

extension Double: LuaConvertible {
    public static func push(_ value: Double, to L: OpaquePointer) {
        lua_pushnumber(L, lua_Number(value))
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> Double? {
        guard lua_type(L, index) == LUA_TNUMBER else { return nil }
        return Double(lua_tonumberx(L, index, nil))
    }
}

extension Float: LuaConvertible {
    public static func push(_ value: Float, to L: OpaquePointer) {
        lua_pushnumber(L, lua_Number(value))
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> Float? {
        guard lua_type(L, index) == LUA_TNUMBER else { return nil }
        return Float(lua_tonumberx(L, index, nil))
    }
}

extension String: LuaConvertible {
    public static func push(_ value: String, to L: OpaquePointer) {
        luaPushString(L, value)
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> String? {
        return luaString(L, at: index)
    }
}

// MARK: - Array Support

extension Array: LuaConvertible where Element: LuaConvertible {
    public static func push(_ value: [Element], to L: OpaquePointer) {
        lua_createtable(L, Int32(value.count), 0)
        for (index, element) in value.enumerated() {
            Element.push(element, to: L)
            lua_rawseti(L, -2, lua_Integer(index + 1))  // Lua arrays are 1-indexed
        }
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> [Element]? {
        guard lua_type(L, index) == LUA_TTABLE else { return nil }

        var array: [Element] = []
        let tableIndex = lua_absindex(L, index)

        // Get array length
        let len = lua_rawlen(L, tableIndex)

        // Handle empty arrays
        if len == 0 {
            return array
        }

        for i in 1...len {
            lua_rawgeti(L, tableIndex, lua_Integer(i))
            if let element = Element.pull(from: L, at: -1) {
                array.append(element)
            } else {
                // If we can't convert an element, fail the whole array
                lua_pop(L, 1)
                return nil
            }
            lua_pop(L, 1)
        }

        return array
    }
}
