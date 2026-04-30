//
//  LuaTableSerialization.swift
//  LuaKit
//
//  Provides JSON and Codable serialization for Lua tables.
//

import Foundation
import Lua

// MARK: - LuaTable JSON Extension

public extension LuaTable {
    /// Converts the table to a JSON string.
    ///
    /// - Parameter prettyPrint: If true, formats the JSON with indentation.
    /// - Returns: A JSON string representation of the table.
    /// - Throws: If the table cannot be serialized to JSON.
    func toJSON(prettyPrint: Bool = false) throws -> String {
        let dict = toDictionary()
        let options: JSONSerialization.WritingOptions = prettyPrint ? [.prettyPrinted, .sortedKeys] : []
        let data = try JSONSerialization.data(withJSONObject: dict, options: options)
        guard let json = String(data: data, encoding: .utf8) else {
            throw LuaError.custom("Failed to encode JSON as UTF-8")
        }
        return json
    }

    /// Converts the table to a Swift dictionary.
    ///
    /// - Returns: A dictionary representation of the table.
    func toDictionary() -> [String: Any] {
        return withLuaState { L in
            extractTableAsDictionary(from: L, at: -1)
        } ?? [:]
    }

    /// Converts the table to an array if it has sequential integer keys.
    ///
    /// - Returns: An array if the table is array-like, nil otherwise.
    func toArray() -> [Any]? {
        return withLuaState { L in
            let len = Int(lua_rawlen(L, -1))

            guard len > 0 else {
                return nil
            }

            var result: [Any] = []
            for i in 1...len {
                lua_rawgeti(L, -1, lua_Integer(i))
                if let value = extractAny(from: L, at: -1) {
                    result.append(value)
                }
                lua_pop(L, 1)
            }

            return result
        } ?? nil
    }

    // MARK: - Private Helpers

    private func extractTableAsDictionary(from L: OpaquePointer, at index: Int32) -> [String: Any] {
        let tableIndex = lua_absindex(L, index)
        var dict: [String: Any] = [:]

        lua_pushnil(L)
        while lua_next(L, tableIndex) != 0 {
            // Get key as string (only support string keys for JSON)
            if lua_type(L, -2) == LUA_TSTRING,
               let key = luaString(L, at: -2),
               let value = extractAny(from: L, at: -1) {
                dict[key] = value
            } else if lua_type(L, -2) == LUA_TNUMBER {
                // Integer key - convert to string for JSON
                let keyNum = lua_tointegerx(L, -2, nil)
                if let value = extractAny(from: L, at: -1) {
                    dict[String(keyNum)] = value
                }
            }
            lua_pop(L, 1)
        }

        return dict
    }

    private func extractAny(from L: OpaquePointer, at index: Int32) -> Any? {
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
            return luaString(L, at: index)
        case LUA_TTABLE:
            // Check if array or dictionary
            let len = Int(lua_rawlen(L, index))
            if len > 0 {
                return extractArrayFromTable(from: L, at: index)
            } else {
                return extractTableAsDictionary(from: L, at: index)
            }
        case LUA_TNIL:
            return NSNull()
        default:
            break
        }

        return nil
    }

    private func extractArrayFromTable(from L: OpaquePointer, at index: Int32) -> [Any] {
        let tableIndex = lua_absindex(L, index)
        let len = Int(lua_rawlen(L, tableIndex))
        var array: [Any] = []

        for i in 1...len {
            lua_rawgeti(L, tableIndex, lua_Integer(i))
            if let value = extractAny(from: L, at: -1) {
                array.append(value)
            }
            lua_pop(L, 1)
        }

        return array
    }
}

// MARK: - LuaState JSON Extension

public extension LuaState {
    /// Loads a JSON string as a Lua table global.
    ///
    /// - Parameters:
    ///   - json: The JSON string to load.
    ///   - name: The name of the global variable to assign the table to.
    /// - Throws: If the JSON is invalid.
    func loadJSON(_ json: String, as name: String) throws {
        guard let data = json.data(using: .utf8) else {
            throw LuaError.invalidArgument("JSON string is not valid UTF-8")
        }
        try loadJSON(data, as: name)
    }

    /// Loads JSON data as a Lua table global.
    ///
    /// - Parameters:
    ///   - data: The JSON data to load.
    ///   - name: The name of the global variable to assign the table to.
    /// - Throws: If the JSON is invalid.
    func loadJSON(_ data: Data, as name: String) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        pushAny(object, to: luaState)
        lua_setglobal(luaState, name)
    }

    /// Decodes a Lua global as a Codable type.
    ///
    /// - Parameters:
    ///   - name: The name of the global variable.
    ///   - type: The type to decode as.
    /// - Returns: The decoded value.
    /// - Throws: If the global doesn't exist or cannot be decoded.
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let table = getTable(name) else {
            throw LuaError.custom("Global '\(name)' is not a table")
        }

        let dict = table.toDictionary()
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(type, from: data)
    }

    /// Encodes a Codable value as a Lua global table.
    ///
    /// - Parameters:
    ///   - value: The value to encode.
    ///   - name: The name of the global variable to assign.
    /// - Throws: If the value cannot be encoded.
    func encode<T: Encodable>(_ value: T, as name: String) throws {
        let data = try JSONEncoder().encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        pushAny(object, to: luaState)
        lua_setglobal(luaState, name)
    }

    // MARK: - Private Helpers

    private func pushAny(_ value: Any, to L: OpaquePointer) {
        switch value {
        case let bool as Bool:
            lua_pushboolean(L, bool ? 1 : 0)
        case let int as Int:
            lua_pushinteger(L, lua_Integer(int))
        case let int as Int64:
            lua_pushinteger(L, lua_Integer(int))
        case let double as Double:
            lua_pushnumber(L, double)
        case let float as Float:
            lua_pushnumber(L, Double(float))
        case let string as String:
            luaPushString(L, string)
        case let array as [Any]:
            pushArray(array, to: L)
        case let dict as [String: Any]:
            pushDictionary(dict, to: L)
        case is NSNull:
            lua_pushnil(L)
        default:
            // Try to convert to string
            luaPushString(L, String(describing: value))
        }
    }

    private func pushArray(_ array: [Any], to L: OpaquePointer) {
        lua_createtable(L, Int32(array.count), 0)
        for (index, element) in array.enumerated() {
            pushAny(element, to: L)
            lua_rawseti(L, -2, lua_Integer(index + 1))
        }
    }

    private func pushDictionary(_ dict: [String: Any], to L: OpaquePointer) {
        lua_createtable(L, 0, Int32(dict.count))
        for (key, value) in dict {
            luaPushString(L, key)
            pushAny(value, to: L)
            lua_settable(L, -3)
        }
    }
}
