//
//  LuaBridgeable.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

import Foundation
import Lua

/// Error type for property validation failures
public struct PropertyValidationError: Error, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}

public protocol LuaBridgeable: AnyObject {
    static var metaTableName: String { get }
    static func register(in state: LuaState, as name: String)
    static func registerMethods(_ L: OpaquePointer)
    static func registerConstructor(_ L: OpaquePointer, name: String)
    static func luaNew(_ L: OpaquePointer) -> Int32
    static func pushAny(_ object: LuaBridgeable, to L: OpaquePointer)

    // Optional property change notifications
    func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError>
    func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?)
}

extension LuaBridgeable {
    public static var metaTableName: String {
        return String(describing: Self.self) + "_meta"
    }

    // Default implementations for property change notifications
    public func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        // Default implementation allows all changes
        return .success(())
    }

    public func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
        // Default implementation does nothing
    }

    public static func register(in state: LuaState, as name: String) {
        let L = state.luaState

        luaL_newmetatable(L, metaTableName)

        // First call registerMethods to let it set up custom __index if needed
        registerMethods(L)
        
        // Check if __index was already set by registerMethods (macro-generated classes)
        lua_pushstring(L, "__index")
        lua_rawget(L, -2)
        let hasCustomIndex = !lua_isnil(L, -1)
        lua_pop(L, 1)
        
        // Only set default __index if registerMethods didn't provide one
        if !hasCustomIndex {
            lua_pushstring(L, "__index")
            lua_pushvalue(L, -2)
            lua_settable(L, -3)
        }

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

        lua_getfield(L, luaRegistryIndex, metaTableName)
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
