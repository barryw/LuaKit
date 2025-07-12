//
//  LuaValue.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

import Foundation
import Lua

public enum LuaValue: Equatable, Hashable {
    case `nil`
    case boolean(Bool)
    case number(Double)
    case string(String)
    case table([String: LuaValue])
    case function
    case userdata
    case thread

    public func push(to L: OpaquePointer) {
        switch self {
            case .nil:
                lua_pushnil(L)
            case .boolean(let value):
                lua_pushboolean(L, value ? 1 : 0)
            case .number(let value):
                lua_pushnumber(L, value)
            case .string(let value):
                lua_pushstring(L, value)
            case .table(let dict):
                lua_createtable(L, 0, Int32(dict.count))
                for (key, value) in dict {
                    lua_pushstring(L, key)
                    value.push(to: L)
                    lua_settable(L, -3)
                }
            case .function, .userdata, .thread:
                fatalError("Cannot push \(self) type directly")
        }
    }

    public static func extract(from L: OpaquePointer, at index: Int32) -> LuaValue? {
        return pull(from: L, at: index)
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> LuaValue? {
        let type = lua_type(L, index)

        switch type {
            case LUA_TNIL:
                return .nil
            case LUA_TBOOLEAN:
                return .boolean(lua_toboolean(L, index) != 0)
            case LUA_TNUMBER:
                return .number(lua_tonumberx(L, index, nil))
            case LUA_TSTRING:
                guard let cStr = lua_tolstring(L, index, nil) else { return nil }
                return .string(String(cString: cStr))
            case LUA_TTABLE:
                var table: [String: LuaValue] = [:]

                lua_pushnil(L)
                while lua_next(L, index - 1) != 0 {
                    if let keyStr = lua_tolstring(L, -2, nil),
                       let value = LuaValue.pull(from: L, at: -1) {
                        table[String(cString: keyStr)] = value
                    }
                    lua_settop(L, -2)
                }

                return .table(table)
            case LUA_TFUNCTION:
                return .function
            case LUA_TUSERDATA:
                return .userdata
            case LUA_TTHREAD:
                return .thread
            default:
                return nil
        }
    }
}

extension LuaValue: LuaConvertible {
    public static func push(_ value: LuaValue, to L: OpaquePointer) {
        value.push(to: L)
    }
}

extension LuaValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .nil
    }
}

extension LuaValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}

extension LuaValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension LuaValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension LuaValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension LuaValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, LuaValue)...) {
        var dict: [String: LuaValue] = [:]
        for (key, value) in elements {
            dict[key] = value
        }
        self = .table(dict)
    }
}
