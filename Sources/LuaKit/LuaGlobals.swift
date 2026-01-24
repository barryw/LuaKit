//
//  LuaGlobals.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

import Foundation
import Lua

// MARK: - Global Variable Support

extension LuaState {
    /// Provides access to Lua global variables
    public var globals: LuaGlobals {
        get {
            return LuaGlobals(luaState: self)
        }
        set {
            // This setter exists only to enable subscript setters
            // The actual value is ignored since globals is computed
        }
    }

    /// Convert a Swift object to a Lua reference
    public func toReference<T: LuaBridgeable>(_ object: T) -> LuaReference {
        return LuaReference(object: object, luaState: self)
    }

    /// Create a Lua table
    public func createTable(arrayCount: Int = 0, dictCount: Int = 0) -> LuaTable {
        lua_createtable(luaState, Int32(arrayCount), Int32(dictCount))
        let ref = luaL_ref(luaState, luaRegistryIndex)
        return LuaTable(reference: ref, luaState: self)
    }
}

/// Provides subscript access to Lua global variables
public struct LuaGlobals {
    internal let luaState: LuaState

    init(luaState: LuaState) {
        self.luaState = luaState
    }

    public subscript(name: String) -> Any? {
        get {
            let L = luaState.luaState
            lua_getglobal(L, name)
            defer { lua_settop(L, -2) } // pop the value

            return extractValue(from: L, at: -1)
        }
        set {
            let L = luaState.luaState

            if let value = newValue {
                pushValue(value, to: L)
            } else {
                lua_pushnil(L)
            }

            lua_setglobal(L, name)
        }
    }

    /// Set a global variable with a LuaReference
    public func set(_ name: String, to reference: LuaReference) {
        reference.push()
        lua_setglobal(luaState.luaState, name)
    }

    /// Set a global variable with a LuaTable
    public func set(_ name: String, to table: LuaTable) {
        table.push()
        lua_setglobal(luaState.luaState, name)
    }

    private func pushValue(_ value: Any, to L: OpaquePointer) {
        switch value {
        case let bool as Bool:
            lua_pushboolean(L, bool ? 1 : 0)
        case let int as Int:
            lua_pushinteger(L, lua_Integer(int))
        case let double as Double:
            lua_pushnumber(L, double)
        case let string as String:
            lua_pushstring(L, string)
        case let function as LuaFunction:
            function.push(to: L)
        case let bridgeable as LuaBridgeable:
            pushBridgeable(bridgeable, to: L)
        case let reference as LuaReference:
            reference.push()
        case let table as LuaTable:
            table.push()
        // Array support - check specific types first for efficiency
        case let stringArray as [String]:
            pushArray(stringArray, to: L)
        case let intArray as [Int]:
            pushArray(intArray, to: L)
        case let doubleArray as [Double]:
            pushArray(doubleArray, to: L)
        case let boolArray as [Bool]:
            pushArray(boolArray, to: L)
        // Nested arrays and generic arrays via [Any]
        case let anyArray as [Any]:
            pushAnyArray(anyArray, to: L)
        // Dictionary support
        case let stringDict as [String: Any]:
            pushDictionary(stringDict, to: L)
        default:
            lua_pushnil(L)
        }
    }

    private func pushArray<T>(_ array: [T], to L: OpaquePointer) {
        lua_createtable(L, Int32(array.count), 0)
        for (index, element) in array.enumerated() {
            pushValue(element, to: L)
            lua_rawseti(L, -2, lua_Integer(index + 1))
        }
    }

    private func pushAnyArray(_ array: [Any], to L: OpaquePointer) {
        lua_createtable(L, Int32(array.count), 0)
        for (index, element) in array.enumerated() {
            pushValue(element, to: L)
            lua_rawseti(L, -2, lua_Integer(index + 1))
        }
    }

    private func pushDictionary(_ dict: [String: Any], to L: OpaquePointer) {
        lua_createtable(L, 0, Int32(dict.count))
        for (key, value) in dict {
            lua_pushstring(L, key)
            pushValue(value, to: L)
            lua_settable(L, -3)
        }
    }

    private func pushBridgeable(_ bridgeable: LuaBridgeable, to L: OpaquePointer) {
        // Use the protocol's push method directly via type erasure
        let bridgeableType = type(of: bridgeable)
        bridgeableType.pushAny(bridgeable, to: L)
    }

    private func extractValue(from L: OpaquePointer, at index: Int32) -> Any? {
        let luaType = lua_type(L, index)

        switch luaType {
        case LUA_TBOOLEAN:
            return lua_toboolean(L, index) != 0
        case LUA_TNUMBER:
            if lua_isinteger(L, index) != 0 {
                return Int(lua_tointegerx(L, index, nil))
            } else {
                return lua_tonumberx(L, index, nil)
            }
        case LUA_TSTRING:
            if let cStr = lua_tolstring(L, index, nil) {
                return String(cString: cStr)
            }
        case LUA_TTABLE:
            return extractTable(from: L, at: index)
        case LUA_TUSERDATA:
            // Could potentially extract the Swift object here
            return "<userdata>"
        default:
            break
        }

        return nil
    }

    private func extractTable(from L: OpaquePointer, at index: Int32) -> Any {
        let tableIndex = lua_absindex(L, index)
        let len = lua_rawlen(L, tableIndex)

        // Check if it's an array-like table (sequential integer keys starting at 1)
        if len > 0 {
            var array: [Any] = []
            for i in 1...len {
                lua_rawgeti(L, tableIndex, lua_Integer(i))
                if let value = extractValue(from: L, at: -1) {
                    array.append(value)
                }
                lua_pop(L, 1)
            }
            return array
        }

        // Otherwise, treat as dictionary
        var dict: [String: Any] = [:]
        lua_pushnil(L)
        while lua_next(L, tableIndex) != 0 {
            if let key = lua_tolstring(L, -2, nil),
               let value = extractValue(from: L, at: -1) {
                dict[String(cString: key)] = value
            }
            lua_pop(L, 1)
        }
        return dict
    }
}

// MARK: - Lua Reference (for custom types)

/// A reference to a Lua value stored in the registry
public class LuaReference {
    private let reference: Int32
    private weak var luaState: LuaState?

    init(reference: Int32, luaState: LuaState) {
        self.reference = reference
        self.luaState = luaState
    }

    init<T: LuaBridgeable>(object: T, luaState: LuaState) {
        let L = luaState.luaState
        type(of: object).push(object, to: L)
        self.reference = luaL_ref(L, luaRegistryIndex)
        self.luaState = luaState
    }

    deinit {
        // Clean up the reference when deallocated
        if let luaState = luaState {
            luaL_unref(luaState.luaState, luaRegistryIndex, reference)
        }
    }

    func push() {
        guard let luaState = luaState else { return }
        lua_rawgeti(luaState.luaState, luaRegistryIndex, lua_Integer(reference))
    }
}

// MARK: - Lua Table

/// Represents a Lua table
public class LuaTable {
    private let reference: Int32
    private weak var luaState: LuaState?

    init(reference: Int32, luaState: LuaState) {
        self.reference = reference
        self.luaState = luaState
    }

    deinit {
        // Clean up the reference when deallocated
        if let luaState = luaState {
            luaL_unref(luaState.luaState, luaRegistryIndex, reference)
        }
    }

    func push() {
        guard let luaState = luaState else { return }
        lua_rawgeti(luaState.luaState, luaRegistryIndex, lua_Integer(reference))
    }

    /// Internal accessor for the Lua state (used by extensions in other files)
    var state: LuaState? {
        return luaState
    }

    /// Internal accessor to push and get the Lua pointer
    func withLuaState<R>(_ body: (OpaquePointer) throws -> R) rethrows -> R? {
        guard let luaState = luaState else { return nil }
        let L = luaState.luaState
        push()
        defer { lua_pop(L, 1) }
        return try body(L)
    }

    /// Array-style access (1-indexed like Lua)
    public subscript(index: Int) -> Any? {
        get {
            guard let luaState = luaState else { return nil }
            let L = luaState.luaState

            push() // Push table
            lua_rawgeti(L, -1, lua_Integer(index))
            let value = extractValue(from: L, at: -1)
            lua_settop(L, -3) // Pop value and table

            return value
        }
        set {
            guard let luaState = luaState else { return }
            let L = luaState.luaState

            push() // Push table

            if let value = newValue {
                pushValue(value, to: L)
            } else {
                lua_pushnil(L)
            }

            lua_rawseti(L, -2, lua_Integer(index))
            lua_settop(L, -2) // Pop table
        }
    }

    /// Dictionary-style access
    public subscript(key: String) -> Any? {
        get {
            guard let luaState = luaState else { return nil }
            let L = luaState.luaState

            push() // Push table
            lua_getfield(L, -1, key)
            let value = extractValue(from: L, at: -1)
            lua_settop(L, -3) // Pop value and table

            return value
        }
        set {
            guard let luaState = luaState else { return }
            let L = luaState.luaState

            push() // Push table

            if let value = newValue {
                pushValue(value, to: L)
            } else {
                lua_pushnil(L)
            }

            lua_setfield(L, -2, key)
            lua_settop(L, -2) // Pop table
        }
    }

    private func pushValue(_ value: Any, to L: OpaquePointer) {
        switch value {
        case let bool as Bool:
            lua_pushboolean(L, bool ? 1 : 0)
        case let int as Int:
            lua_pushinteger(L, lua_Integer(int))
        case let double as Double:
            lua_pushnumber(L, double)
        case let string as String:
            lua_pushstring(L, string)
        case let function as LuaFunction:
            function.push(to: L)
        case let bridgeable as LuaBridgeable:
            pushBridgeable(bridgeable, to: L)
        case let reference as LuaReference:
            reference.push()
        case let table as LuaTable:
            table.push()
        // Array support
        case let stringArray as [String]:
            pushArray(stringArray, to: L)
        case let intArray as [Int]:
            pushArray(intArray, to: L)
        case let doubleArray as [Double]:
            pushArray(doubleArray, to: L)
        case let boolArray as [Bool]:
            pushArray(boolArray, to: L)
        case let anyArray as [Any]:
            pushAnyArray(anyArray, to: L)
        // Dictionary support
        case let stringDict as [String: Any]:
            pushDictionary(stringDict, to: L)
        default:
            lua_pushnil(L)
        }
    }

    private func pushArray<T>(_ array: [T], to L: OpaquePointer) {
        lua_createtable(L, Int32(array.count), 0)
        for (index, element) in array.enumerated() {
            pushValue(element, to: L)
            lua_rawseti(L, -2, lua_Integer(index + 1))
        }
    }

    private func pushAnyArray(_ array: [Any], to L: OpaquePointer) {
        lua_createtable(L, Int32(array.count), 0)
        for (index, element) in array.enumerated() {
            pushValue(element, to: L)
            lua_rawseti(L, -2, lua_Integer(index + 1))
        }
    }

    private func pushDictionary(_ dict: [String: Any], to L: OpaquePointer) {
        lua_createtable(L, 0, Int32(dict.count))
        for (key, value) in dict {
            lua_pushstring(L, key)
            pushValue(value, to: L)
            lua_settable(L, -3)
        }
    }

    private func pushBridgeable(_ bridgeable: LuaBridgeable, to L: OpaquePointer) {
        // Use the protocol's push method directly via type erasure
        let bridgeableType = type(of: bridgeable)
        bridgeableType.pushAny(bridgeable, to: L)
    }

    private func extractValue(from L: OpaquePointer, at index: Int32) -> Any? {
        let luaType = lua_type(L, index)

        switch luaType {
        case LUA_TBOOLEAN:
            return lua_toboolean(L, index) != 0
        case LUA_TNUMBER:
            if lua_isinteger(L, index) != 0 {
                return Int(lua_tointegerx(L, index, nil))
            } else {
                return lua_tonumberx(L, index, nil)
            }
        case LUA_TSTRING:
            if let cStr = lua_tolstring(L, index, nil) {
                return String(cString: cStr)
            }
        case LUA_TTABLE:
            return extractTable(from: L, at: index)
        default:
            break
        }

        return nil
    }

    private func extractTable(from L: OpaquePointer, at index: Int32) -> Any {
        let tableIndex = lua_absindex(L, index)
        let len = lua_rawlen(L, tableIndex)

        // Check if it's an array-like table (sequential integer keys starting at 1)
        if len > 0 {
            var array: [Any] = []
            for i in 1...len {
                lua_rawgeti(L, tableIndex, lua_Integer(i))
                if let value = extractValue(from: L, at: -1) {
                    array.append(value)
                }
                lua_pop(L, 1)
            }
            return array
        }

        // Otherwise, treat as dictionary
        var dict: [String: Any] = [:]
        lua_pushnil(L)
        while lua_next(L, tableIndex) != 0 {
            if let key = lua_tolstring(L, -2, nil),
               let value = extractValue(from: L, at: -1) {
                dict[String(cString: key)] = value
            }
            lua_pop(L, 1)
        }
        return dict
    }
}

// MARK: - LuaTable Sequence Conformance

extension LuaTable: Sequence {
    /// An iterator for LuaTable that yields (key, value) pairs
    public struct Iterator: IteratorProtocol {
        private weak var luaState: LuaState?
        private let reference: Int32
        private var hasStarted: Bool = false
        private var isExhausted: Bool = false

        init(table: LuaTable) {
            self.luaState = table.luaState
            self.reference = table.reference
        }

        public mutating func next() -> (key: LuaValue, value: LuaValue)? {
            guard let luaState = luaState, !isExhausted else { return nil }
            let L = luaState.luaState

            // Push table
            lua_rawgeti(L, luaRegistryIndex, lua_Integer(reference))
            let tableIndex = lua_gettop(L)

            if !hasStarted {
                // First iteration: push nil as initial key
                lua_pushnil(L)
                hasStarted = true
            } else {
                // Subsequent iterations: push nil (key was consumed)
                lua_pushnil(L)
            }

            if lua_next(L, tableIndex) != 0 {
                // Stack now has: table, key, value
                let value = LuaValue.pull(from: L, at: -1) ?? .nil
                let key = LuaValue.pull(from: L, at: -2) ?? .nil

                // Pop value and key, leave table for cleanup
                lua_pop(L, 2)
                lua_pop(L, 1) // Pop table

                return (key: key, value: value)
            } else {
                // Iteration complete
                isExhausted = true
                lua_pop(L, 1) // Pop table
                return nil
            }
        }
    }

    public func makeIterator() -> Iterator {
        return Iterator(table: self)
    }

    /// The number of elements in the table (using rawlen for array-like tables)
    public var count: Int {
        guard let luaState = luaState else { return 0 }
        let L = luaState.luaState

        push()
        let len = Int(lua_rawlen(L, -1))
        lua_pop(L, 1)

        // If rawlen returns 0, count manually using iteration
        if len == 0 {
            var count = 0
            push()
            lua_pushnil(L)
            while lua_next(L, -2) != 0 {
                count += 1
                lua_pop(L, 1) // Pop value, keep key
            }
            lua_pop(L, 1) // Pop table
            return count
        }

        return len
    }

    /// All keys in the table
    public var keys: [LuaValue] {
        guard let luaState = luaState else { return [] }
        let L = luaState.luaState
        var result: [LuaValue] = []

        push()
        let tableIndex = lua_gettop(L)
        lua_pushnil(L)

        while lua_next(L, tableIndex) != 0 {
            if let key = LuaValue.pull(from: L, at: -2) {
                result.append(key)
            }
            lua_pop(L, 1) // Pop value, keep key
        }

        lua_pop(L, 1) // Pop table
        return result
    }

    /// All values in the table
    public var values: [LuaValue] {
        guard let luaState = luaState else { return [] }
        let L = luaState.luaState
        var result: [LuaValue] = []

        push()
        let tableIndex = lua_gettop(L)
        lua_pushnil(L)

        while lua_next(L, tableIndex) != 0 {
            if let value = LuaValue.pull(from: L, at: -1) {
                result.append(value)
            }
            lua_pop(L, 1) // Pop value, keep key
        }

        lua_pop(L, 1) // Pop table
        return result
    }

    /// Check if the table is empty
    public var isEmpty: Bool {
        guard let luaState = luaState else { return true }
        let L = luaState.luaState

        push()
        lua_pushnil(L)
        let hasNext = lua_next(L, -2) != 0
        if hasNext {
            lua_pop(L, 2) // Pop key and value
        }
        lua_pop(L, 1) // Pop table

        return !hasNext
    }

    /// Check if the table contains a specific key
    public func contains(key: String) -> Bool {
        return self[key] != nil
    }

    /// Check if the table contains a specific index
    public func contains(index: Int) -> Bool {
        return self[index] != nil
    }
}

// MARK: - LuaState Table Access Extension

public extension LuaState {
    /// Gets a LuaTable reference to a global table
    func getTable(_ name: String) -> LuaTable? {
        lua_getglobal(luaState, name)
        guard lua_type(luaState, -1) == LUA_TTABLE else {
            lua_pop(luaState, 1)
            return nil
        }
        let ref = luaL_ref(luaState, luaRegistryIndex)
        return LuaTable(reference: ref, luaState: self)
    }
}
