//
//  LuaState.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

import Foundation
import Lua

public final class LuaState {
    private let L: OpaquePointer

    /// Internal access to the Lua state for extensions
    internal var luaState: OpaquePointer { L }

    public init() throws {
        guard let state = luaL_newstate() else {
            throw LuaError.memoryAllocation
        }
        self.L = state
        luaL_openlibs(L)
        setupPrintCapture()
        registerArrayProxyTypes()
    }

    deinit {
        lua_close(L)
    }

    private var printOutput: String = ""
    private var printHandler: ((String) -> Void)?
    private var maxPrintBufferSize: Int = 1_000_000  // 1MB default
    private var printBufferPolicy: PrintBufferPolicy = .unlimited
    
    /// Policy for managing print buffer size and behavior
    public enum PrintBufferPolicy {
        case unlimited
        case truncateOldest
        case truncateNewest
        case maxSize(Int)
    }
    
    /// Type alias for output handlers that receive print output immediately
    public typealias PrintOutputHandler = (String) -> Void

    public func setPrintHandler(_ handler: @escaping (String) -> Void) {
        self.printHandler = handler
    }
    
    /// Configure the print buffer policy for managing output accumulation
    public func setPrintBufferPolicy(_ policy: PrintBufferPolicy) {
        self.printBufferPolicy = policy
    }
    
    /// Set the output handler for streaming print output (replaces setPrintHandler with better naming)
    public func setOutputHandler(_ handler: @escaping PrintOutputHandler) {
        self.printHandler = handler
    }
    
    /// Clear the print buffer manually
    public func clearPrintBuffer() {
        printOutput = ""
    }
    
    /// Get current buffer contents without executing any code
    public func getCurrentPrintBuffer() -> String {
        return printOutput
    }

    private func setupPrintCapture() {
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            let state = LuaState.states[L]

            let n = lua_gettop(L)
            var output = ""

            for i in 1...n {
                if i > 1 { output += "\t" }

                if luaL_callmeta(L, i, "__tostring") != 0 {
                    if let str = lua_tolstring(L, -1, nil) {
                        output += String(cString: str)
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
                            if let str = lua_tolstring(L, i, nil) {
                                output += String(cString: str)
                            }
                        default:
                            if let str = luaL_tolstring(L, i, nil) {
                                output += String(cString: str)
                                lua_settop(L, -2)
                            }
                    }
                }
            }

            output += "\n"
            state?.printOutput += output
            state?.printHandler?(output)

            return 0
        }, 0)
        lua_setglobal(L, "print")

        LuaState.states[L] = self
    }

    private static var states: [OpaquePointer: LuaState] = [:]

    private func registerArrayProxyTypes() {
        // Register array proxy types for each supported element type
        LuaStringArrayProxy.register(in: self, as: "_StringArrayProxy")
        LuaIntArrayProxy.register(in: self, as: "_IntArrayProxy")
        LuaDoubleArrayProxy.register(in: self, as: "_DoubleArrayProxy")
        LuaBoolArrayProxy.register(in: self, as: "_BoolArrayProxy")
    }

    public func execute(_ code: String) throws -> String {
        // Don't reset buffer automatically - let user control this
        // printOutput = ""  // REMOVED - users can call clearPrintBuffer() if needed

        if luaL_loadstring(L, code) != LUA_OK {
            let error = getError()
            throw LuaError.syntax(error)
        }

        if lua_pcallk(L, 0, LUA_MULTRET, 0, 0, nil) != LUA_OK {
            let error = getError()
            throw LuaError.runtime(error)
        }

        return managePrintBuffer()
    }
    
    /// Manage print buffer according to configured policy
    private func managePrintBuffer() -> String {
        switch printBufferPolicy {
        case .unlimited:
            return printOutput
        case .truncateOldest:
            if printOutput.count > maxPrintBufferSize {
                let startIndex = printOutput.index(printOutput.startIndex, offsetBy: printOutput.count - maxPrintBufferSize)
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

    public func executeReturning<T: LuaConvertible>(_ code: String, as type: T.Type = T.self) throws -> T {
        if luaL_loadstring(L, code) != LUA_OK {
            let error = getError()
            throw LuaError.syntax(error)
        }

        if lua_pcallk(L, 0, 1, 0, 0, nil) != LUA_OK {
            let error = getError()
            throw LuaError.runtime(error)
        }

        guard let result = T.pull(from: L, at: -1) else {
            lua_settop(L, -2)
            throw LuaError.typeMismatch(expected: String(describing: T.self), got: luaTypeName(at: -1))
        }

        lua_settop(L, -2)
        return result
    }

    private func getError() -> String {
        if let errorStr = lua_tolstring(L, -1, nil) {
            let error = String(cString: errorStr)
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
        type.register(in: self, as: name)
    }
}

public protocol LuaConvertible {
    static func push(_ value: Self, to L: OpaquePointer)
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

extension String: LuaConvertible {
    public static func push(_ value: String, to L: OpaquePointer) {
        lua_pushstring(L, value)
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> String? {
        guard let cStr = lua_tolstring(L, index, nil) else { return nil }
        return String(cString: cStr)
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

