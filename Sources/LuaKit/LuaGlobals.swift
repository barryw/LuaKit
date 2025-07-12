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
        let ref = luaL_ref(luaState, LUA_REGISTRYINDEX)
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
            default:
                lua_pushnil(L)
        }
    }
    
    private func pushBridgeable(_ bridgeable: LuaBridgeable, to L: OpaquePointer) {
        // Use the protocol's push method directly via type erasure
        let bridgeableType = type(of: bridgeable)
        bridgeableType.pushAny(bridgeable, to: L)
    }
    
    private func extractValue(from L: OpaquePointer, at index: Int32) -> Any? {
        let type = lua_type(L, index)
        
        switch type {
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
                // Return as opaque handle for now
                return "<table>"
            case LUA_TUSERDATA:
                // Could potentially extract the Swift object here
                return "<userdata>"
            default:
                break
        }
        
        return nil
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
        self.reference = luaL_ref(L, LUA_REGISTRYINDEX)
        self.luaState = luaState
    }
    
    deinit {
        // Clean up the reference when deallocated
        if let luaState = luaState {
            luaL_unref(luaState.luaState, LUA_REGISTRYINDEX, reference)
        }
    }
    
    func push() {
        guard let luaState = luaState else { return }
        lua_rawgeti(luaState.luaState, LUA_REGISTRYINDEX, lua_Integer(reference))
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
            luaL_unref(luaState.luaState, LUA_REGISTRYINDEX, reference)
        }
    }
    
    func push() {
        guard let luaState = luaState else { return }
        lua_rawgeti(luaState.luaState, LUA_REGISTRYINDEX, lua_Integer(reference))
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
            default:
                lua_pushnil(L)
        }
    }
    
    private func pushBridgeable(_ bridgeable: LuaBridgeable, to L: OpaquePointer) {
        // Use the protocol's push method directly via type erasure
        let bridgeableType = type(of: bridgeable)
        bridgeableType.pushAny(bridgeable, to: L)
    }
    
    private func extractValue(from L: OpaquePointer, at index: Int32) -> Any? {
        let type = lua_type(L, index)
        
        switch type {
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
            default:
                break
        }
        
        return nil
    }
}
