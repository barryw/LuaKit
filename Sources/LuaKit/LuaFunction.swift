//
//  LuaFunction.swift
//  LuaKit
//
//  Provides closure bridging functionality to convert Swift closures to Lua functions
//

import Foundation
import Lua

/// A type-erased wrapper for Swift closures that can be called from Lua
public class LuaFunction {
    // Global registry of closures by ID
    private static var closures: [Int: (OpaquePointer) -> Int32] = [:]
    private static var retainedFunctions: [Int: LuaFunction] = [:]
    private static var nextId: Int = 1
    private static let lock = NSLock()
    
    private let id: Int
    
    /// Creates a Lua function from a Swift closure with no parameters
    public init<R>(_ closure: @escaping () -> R) {
        LuaFunction.lock.lock()
        defer { LuaFunction.lock.unlock() }
        
        self.id = LuaFunction.nextId
        LuaFunction.nextId += 1
        
        LuaFunction.closures[self.id] = { L in
            let result = closure()
            return LuaFunction.pushResult(result, to: L)
        }
    }
    
    /// Creates a Lua function from a Swift closure with one parameter
    public init<T1, R>(_ closure: @escaping (T1) -> R) where T1: LuaConvertible {
        LuaFunction.lock.lock()
        defer { LuaFunction.lock.unlock() }
        
        self.id = LuaFunction.nextId
        LuaFunction.nextId += 1
        
        LuaFunction.closures[self.id] = { L in
            guard let arg1 = T1.pull(from: L, at: 1) else {
                return luaError(L, "Expected \(T1.self) for argument 1")
            }
            let result = closure(arg1)
            return LuaFunction.pushResult(result, to: L)
        }
    }
    
    /// Creates a Lua function from a Swift closure with two parameters
    public init<T1, T2, R>(_ closure: @escaping (T1, T2) -> R) 
        where T1: LuaConvertible, T2: LuaConvertible {
        LuaFunction.lock.lock()
        defer { LuaFunction.lock.unlock() }
        
        self.id = LuaFunction.nextId
        LuaFunction.nextId += 1
        
        LuaFunction.closures[self.id] = { L in
            guard let arg1 = T1.pull(from: L, at: 1) else {
                return luaError(L, "Expected \(T1.self) for argument 1")
            }
            guard let arg2 = T2.pull(from: L, at: 2) else {
                return luaError(L, "Expected \(T2.self) for argument 2")
            }
            let result = closure(arg1, arg2)
            return LuaFunction.pushResult(result, to: L)
        }
    }
    
    /// Creates a Lua function from a Swift closure with three parameters
    public init<T1, T2, T3, R>(_ closure: @escaping (T1, T2, T3) -> R) 
        where T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible {
        LuaFunction.lock.lock()
        defer { LuaFunction.lock.unlock() }
        
        self.id = LuaFunction.nextId
        LuaFunction.nextId += 1
        
        LuaFunction.closures[self.id] = { L in
            guard let arg1 = T1.pull(from: L, at: 1) else {
                return luaError(L, "Expected \(T1.self) for argument 1")
            }
            guard let arg2 = T2.pull(from: L, at: 2) else {
                return luaError(L, "Expected \(T2.self) for argument 2")
            }
            guard let arg3 = T3.pull(from: L, at: 3) else {
                return luaError(L, "Expected \(T3.self) for argument 3")
            }
            let result = closure(arg1, arg2, arg3)
            return LuaFunction.pushResult(result, to: L)
        }
    }
    
    deinit {
        LuaFunction.lock.lock()
        defer { LuaFunction.lock.unlock() }
        LuaFunction.closures.removeValue(forKey: self.id)
        LuaFunction.retainedFunctions.removeValue(forKey: self.id)
    }
    
    /// Pushes the function onto the Lua stack
    func push(to L: OpaquePointer) {
        // Keep a strong reference to self
        LuaFunction.lock.lock()
        LuaFunction.retainedFunctions[self.id] = self
        LuaFunction.lock.unlock()
        
        // Create a Lua table to hold the function ID
        lua_createtable(L, 0, 1)
        
        // Store the function ID in the table
        lua_pushinteger(L, lua_Integer(self.id))
        lua_setfield(L, -2, "_luakit_function_id")
        
        // Create metatable
        lua_createtable(L, 0, 1)
        
        // Set __call metamethod
        lua_pushstring(L, "__call")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the function table (first argument)
            guard lua_type(L, 1) == LUA_TTABLE else {
                return luaError(L, "Invalid function object")
            }
            
            // Get the function ID from the table
            lua_getfield(L, 1, "_luakit_function_id")
            let id = Int(lua_tointegerx(L, -1, nil))
            lua_settop(L, -2) // Pop the ID
            
            // Remove the function table from arguments
            lua_remove(L, 1)
            
            // Look up and call the closure
            LuaFunction.lock.lock()
            let closure = LuaFunction.closures[id]
            LuaFunction.lock.unlock()
            
            guard let closure = closure else {
                return luaError(L, "Function no longer exists")
            }
            
            return closure(L)
        }, 0)
        lua_settable(L, -3)
        
        // Set __gc metamethod to release the retained reference
        lua_pushstring(L, "__gc")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the function ID from the table
            lua_getfield(L, 1, "_luakit_function_id")
            let id = Int(lua_tointegerx(L, -1, nil))
            
            // Release the retained reference
            LuaFunction.lock.lock()
            LuaFunction.retainedFunctions.removeValue(forKey: id)
            LuaFunction.lock.unlock()
            
            return 0
        }, 0)
        lua_settable(L, -3)
        
        // Set the metatable
        lua_setmetatable(L, -2)
    }
    
    /// Helper method to push results onto the Lua stack
    private static func pushResult<R>(_ result: R, to L: OpaquePointer) -> Int32 {
        // Check for Void first
        if result is Void {
            return 0
        }
        
        // Check for concrete types before protocols
        switch result {
        case let bool as Bool:
            lua_pushboolean(L, bool ? 1 : 0)
            return 1
        case let int as Int:
            lua_pushinteger(L, lua_Integer(int))
            return 1
        case let double as Double:
            lua_pushnumber(L, double)
            return 1
        case let string as String:
            lua_pushstring(L, string)
            return 1
        case let optional as Any?:
            if let value = optional {
                return pushResult(value, to: L)
            } else {
                lua_pushnil(L)
                return 1
            }
        case let bridgeable as LuaBridgeable:
            type(of: bridgeable).pushAny(bridgeable, to: L)
            return 1
        default:
            lua_pushnil(L)
            return 1
        }
    }
}

// MARK: - Convenience methods for common closure types

public extension LuaState {
    /// Registers a Swift closure as a global Lua function
    func registerFunction<R>(_ name: String, _ closure: @escaping () -> R) {
        let function = LuaFunction(closure)
        function.push(to: luaState)
        lua_setglobal(luaState, name)
    }
    
    /// Registers a Swift closure with one parameter as a global Lua function
    func registerFunction<T1, R>(_ name: String, _ closure: @escaping (T1) -> R) 
        where T1: LuaConvertible {
        let function = LuaFunction(closure)
        function.push(to: luaState)
        lua_setglobal(luaState, name)
    }
    
    /// Registers a Swift closure with two parameters as a global Lua function
    func registerFunction<T1, T2, R>(_ name: String, _ closure: @escaping (T1, T2) -> R) 
        where T1: LuaConvertible, T2: LuaConvertible {
        let function = LuaFunction(closure)
        function.push(to: luaState)
        lua_setglobal(luaState, name)
    }
    
    /// Registers a Swift closure with three parameters as a global Lua function
    func registerFunction<T1, T2, T3, R>(_ name: String, _ closure: @escaping (T1, T2, T3) -> R) 
        where T1: LuaConvertible, T2: LuaConvertible, T3: LuaConvertible {
        let function = LuaFunction(closure)
        function.push(to: luaState)
        lua_setglobal(luaState, name)
    }
}

// Define lua_remove since it's a macro in C
private func lua_remove(_ L: OpaquePointer, _ idx: Int32) {
    lua_rotate(L, idx, -1)
    lua_settop(L, -2)
}