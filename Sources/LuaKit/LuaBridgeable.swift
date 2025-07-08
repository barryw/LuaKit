//
//  LuaBridgeable.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

import Foundation
import CLua

public protocol LuaBridgeable: AnyObject {
    static var metaTableName: String { get }
    static func register(in state: LuaState, as name: String)
    static func registerMethods(_ L: OpaquePointer)
    static func registerConstructor(_ L: OpaquePointer, name: String)
    static func luaNew(_ L: OpaquePointer) -> Int32
    static func pushAny(_ object: LuaBridgeable, to L: OpaquePointer)
}

extension LuaBridgeable {
    public static var metaTableName: String {
        return String(describing: Self.self) + "_meta"
    }
    
    public static func register(in state: LuaState, as name: String) {
        let L = state.luaState
        
        luaL_newmetatable(L, metaTableName)
        
        lua_pushstring(L, "__index")
        lua_pushvalue(L, -2)
        lua_settable(L, -3)
        
        registerMethods(L)
        
        lua_pushstring(L, "__gc")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            if let userdata = lua_touserdata(L, 1) {
                userdata.assumingMemoryBound(to: AnyObject.self).deinitialize(count: 1)
            }
            return 0
        }, 0)
        lua_settable(L, -3)
        
        lua_settop(L, -2)
        
        registerConstructor(L, name: name)
    }
    
    
    
    public static func push(_ object: Self, to L: OpaquePointer) {
        let userdata = lua_newuserdatauv(L, MemoryLayout<AnyObject>.size, 0)
        userdata?.assumingMemoryBound(to: AnyObject.self).initialize(to: object)
        
        lua_getfield(L, LUA_REGISTRYINDEX, metaTableName)
        lua_setmetatable(L, -2)
    }
    
    public static func pushAny(_ object: LuaBridgeable, to L: OpaquePointer) {
        // Cast to Self and use the regular push method
        guard let typedObject = object as? Self else {
            lua_pushnil(L)
            return
        }
        push(typedObject, to: L)
    }
    
    public static func checkUserdata(_ L: OpaquePointer, at index: Int32) -> Self? {
        guard let userdata = luaL_testudata(L, index, metaTableName) else {
            return nil
        }
        
        let object = userdata.assumingMemoryBound(to: AnyObject.self).pointee
        return object as? Self
    }
}

public struct LuaMethod {
    let name: String
    let function: @convention(c) (OpaquePointer?) -> Int32
    
    public init(name: String, function: @escaping @convention(c) (OpaquePointer?) -> Int32) {
        self.name = name
        self.function = function
    }
}

public func registerLuaMethods(_ L: OpaquePointer, methods: [LuaMethod]) {
    for method in methods {
        lua_pushstring(L, method.name)
        lua_pushcclosure(L, method.function, 0)
        lua_settable(L, -3)
    }
}
