//
//  LuaErrorContext.swift
//  LuaKit
//
//  Enhanced error handling with detailed context and helpful messages
//

import Foundation
import Lua

/// Provides detailed error context for better debugging
public struct LuaErrorContext {
    public let functionName: String
    public let argumentIndex: Int?
    public let expectedType: String
    public let actualType: String
    public let additionalInfo: String?
    public let hint: String?

    public init(
        functionName: String,
        argumentIndex: Int? = nil,
        expectedType: String,
        actualType: String,
        additionalInfo: String? = nil,
        hint: String? = nil
    ) {
        self.functionName = functionName
        self.argumentIndex = argumentIndex
        self.expectedType = expectedType
        self.actualType = actualType
        self.additionalInfo = additionalInfo
        self.hint = hint
    }

    /// Generates a detailed error message
    public func generateMessage() -> String {
        var message = "Error"

        if let index = argumentIndex {
            message += ": Invalid argument #\(index) to '\(functionName)'"
        } else {
            message += " in '\(functionName)'"
        }

        message += "\nExpected: \(expectedType)"
        message += "\nGot: \(actualType)"

        if let info = additionalInfo {
            message += "\n\(info)"
        }

        if let hint = hint {
            message += "\n\nHint: \(hint)"
        }

        return message
    }
}

/// Enhanced error types with context
public enum LuaKitError: Error, CustomStringConvertible {
    case invalidArgument(LuaErrorContext)
    case invalidReturnType(expected: String, got: String, function: String)
    case missingRequiredParameter(parameter: String, function: String)
    case validationFailed(property: String, value: Any, reason: String)
    case enumConversionFailed(type: String, value: String, validValues: [String])
    case asyncOperationFailed(function: String, reason: String)

    public var description: String {
        switch self {
        case .invalidArgument(let context):
            return context.generateMessage()

        case let .invalidReturnType(expected, got, function):
            return "Error: Invalid return type from '\(function)'\nExpected: \(expected)\nGot: \(got)"

        case let .missingRequiredParameter(parameter, function):
            return "Error: Missing required parameter '\(parameter)' for function '\(function)'"

        case let .validationFailed(property, value, reason):
            return "Error: Validation failed for property '\(property)'\nValue: \(value)\nReason: \(reason)"

        case let .enumConversionFailed(type, value, validValues):
            let validList = validValues.joined(separator: ", ")
            return "Error: Invalid value '\(value)' for enum type '\(type)'\nValid values: \(validList)"

        case let .asyncOperationFailed(function, reason):
            return "Error: Async operation '\(function)' failed\nReason: \(reason)"
        }
    }
}

/// Helper functions for enhanced error reporting
public extension OpaquePointer {
    /// Get the Lua type name at the given index
    func luaTypeName(at index: Int32) -> String {
        let type = lua_type(self, index)
        switch type {
        case LUA_TNIL:
            return "nil"
        case LUA_TBOOLEAN:
            return "boolean"
        case LUA_TNUMBER:
            if lua_isinteger(self, index) != 0 {
                return "integer"
            } else {
                return "number"
            }
        case LUA_TSTRING:
            return "string"
        case LUA_TTABLE:
            // Try to identify special table types
            if let metatableName = getMetatableName(at: index) {
                return metatableName
            }
            return "table"
        case LUA_TFUNCTION:
            return "function"
        case LUA_TUSERDATA:
            if let metatableName = getMetatableName(at: index) {
                return metatableName
            }
            return "userdata"
        case LUA_TTHREAD:
            return "thread"
        case LUA_TLIGHTUSERDATA:
            return "light userdata"
        default:
            return "unknown"
        }
    }

    /// Get the metatable name if it exists
    private func getMetatableName(at index: Int32) -> String? {
        guard lua_getmetatable(self, index) != 0 else { return nil }
        defer { lua_pop(self, 1) } // Pop metatable

        lua_pushstring(self, "__name")
        lua_rawget(self, -2)

        if let name = lua_tostring(self, -1) {
            let result = String(cString: name)
            lua_pop(self, 1) // Pop name
            return result
        }

        lua_pop(self, 1) // Pop nil
        return nil
    }

    /// Get descriptive value representation
    func luaValueDescription(at index: Int32) -> String {
        let type = lua_type(self, index)
        switch type {
        case LUA_TNIL:
            return "nil"
        case LUA_TBOOLEAN:
            return lua_toboolean(self, index) != 0 ? "true" : "false"
        case LUA_TNUMBER:
            if lua_isinteger(self, index) != 0 {
                return String(lua_tointeger(self, index))
            } else {
                return String(lua_tonumber(self, index))
            }
        case LUA_TSTRING:
            if let str = lua_tostring(self, index) {
                return "\"\(String(cString: str))\""
            }
            return "string"
        case LUA_TTABLE:
            return luaTypeName(at: index)
        case LUA_TFUNCTION:
            return "function"
        default:
            return luaTypeName(at: index)
        }
    }
}

/// Enhanced error reporting function
public func luaDetailedError(
    _ L: OpaquePointer,
    functionName: String,
    argumentIndex: Int? = nil,
    expectedType: String,
    actualType: String? = nil,
    additionalInfo: String? = nil,
    hint: String? = nil
) -> Int32 {
    let resolvedActualType = actualType ?? {
        if let index = argumentIndex {
            return L.luaTypeName(at: Int32(index))
        }
        return "unknown"
    }()

    let context = LuaErrorContext(
        functionName: functionName,
        argumentIndex: argumentIndex,
        expectedType: expectedType,
        actualType: resolvedActualType,
        additionalInfo: additionalInfo,
        hint: hint
    )

    lua_pushstring(L, context.generateMessage())
    return lua_error(L)
}

/// Type validation helper
public func validateLuaType(
    _ L: OpaquePointer,
    at index: Int32,
    expectedTypes: [Int32],
    functionName: String,
    parameterName: String? = nil
) -> Bool {
    let actualType = lua_type(L, index)
    if expectedTypes.contains(actualType) {
        return true
    }

    let expectedTypeNames = expectedTypes.map { type in
        switch type {
        case LUA_TNIL: return "nil"
        case LUA_TBOOLEAN: return "boolean"
        case LUA_TNUMBER: return "number"
        case LUA_TSTRING: return "string"
        case LUA_TTABLE: return "table"
        case LUA_TFUNCTION: return "function"
        case LUA_TUSERDATA: return "userdata"
        default: return "unknown"
        }
    }.joined(separator: " or ")

    let actualTypeName = L.luaTypeName(at: index)
    let actualValue = L.luaValueDescription(at: index)

    let paramInfo = parameterName.map { "parameter '\($0)'" } ?? "argument #\(index)"

    _ = luaDetailedError(
        L,
        functionName: functionName,
        argumentIndex: Int(index),
        expectedType: expectedTypeNames,
        actualType: "\(actualTypeName) (\(actualValue))",
        additionalInfo: "Invalid \(paramInfo)"
    )

    return false
}
