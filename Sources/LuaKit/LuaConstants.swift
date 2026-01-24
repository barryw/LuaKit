//
//  LuaConstants.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

import Foundation
import Lua

// Lua constants that are defined as macros and not available in Swift
// Lua 5.5 changed LUA_REGISTRYINDEX from -1001000 to -(INT_MAX/2 + 1000)
public let luaRegistryIndex: Int32 = -(Int32.max / 2 + 1000)

// Helper functions for macros
public func lua_pop(_ L: OpaquePointer, _ n: Int32) {
    lua_settop(L, -n - 1)
}

public func lua_newtable(_ L: OpaquePointer) {
    lua_createtable(L, 0, 0)
}

public func lua_tostring(_ L: OpaquePointer, _ index: Int32) -> UnsafePointer<CChar>? {
    return lua_tolstring(L, index, nil)
}

public func lua_tonumber(_ L: OpaquePointer, _ index: Int32) -> lua_Number {
    return lua_tonumberx(L, index, nil)
}

public func lua_tointeger(_ L: OpaquePointer, _ index: Int32) -> lua_Integer {
    return lua_tointegerx(L, index, nil)
}

public func lua_pcall(_ L: OpaquePointer, _ nargs: Int32, _ nresults: Int32, _ errfunc: Int32) -> Int32 {
    return lua_pcallk(L, nargs, nresults, errfunc, 0, nil)
}

public func luaGetMetatable(_ L: OpaquePointer, _ name: String) {
    lua_getfield(L, luaRegistryIndex, name)
}

public func luaError(_ L: OpaquePointer, _ message: String) -> Int32 {
    lua_pushstring(L, message)
    return lua_error(L)
}
