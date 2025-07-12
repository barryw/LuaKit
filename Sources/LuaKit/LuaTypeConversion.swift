//
//  LuaTypeConversion.swift
//  LuaKit
//
//  Enhanced type conversion system with custom converters
//

import Foundation
import Lua

/// Protocol for custom type converters
public protocol LuaTypeConverter {
    associatedtype InputType
    associatedtype OutputType
    
    static func convert(_ input: InputType) throws -> OutputType
}

/// Registry for custom type converters
public class LuaTypeConverterRegistry {
    private static var converters: [String: Any] = [:]
    
    /// Register a custom converter
    public static func register<T: LuaTypeConverter>(_ converter: T.Type, name: String) {
        converters[name] = converter
    }
    
    /// Get a converter by name
    public static func getConverter(named name: String) -> Any? {
        return converters[name]
    }
}

// MARK: - Built-in Type Converters

/// String to UUID converter
public struct StringToUUIDConverter: LuaTypeConverter {
    public static func convert(_ input: String) throws -> UUID {
        guard let uuid = UUID(uuidString: input) else {
            throw LuaKitError.invalidArgument(
                LuaErrorContext(
                    functionName: "UUID conversion",
                    expectedType: "valid UUID string",
                    actualType: "string",
                    additionalInfo: "Invalid UUID format: '\(input)'"
                )
            )
        }
        return uuid
    }
}

/// String to Date converter (ISO8601)
public struct StringToDateConverter: LuaTypeConverter {
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    public static func convert(_ input: String) throws -> Date {
        guard let date = formatter.date(from: input) else {
            throw LuaKitError.invalidArgument(
                LuaErrorContext(
                    functionName: "Date conversion",
                    expectedType: "ISO8601 date string",
                    actualType: "string",
                    additionalInfo: "Invalid date format: '\(input)'",
                    hint: "Use format: YYYY-MM-DDTHH:MM:SS.sssZ"
                )
            )
        }
        return date
    }
}

/// String to URL converter
public struct StringToURLConverter: LuaTypeConverter {
    public static func convert(_ input: String) throws -> URL {
        guard let url = URL(string: input) else {
            throw LuaKitError.invalidArgument(
                LuaErrorContext(
                    functionName: "URL conversion",
                    expectedType: "valid URL string",
                    actualType: "string",
                    additionalInfo: "Invalid URL format: '\(input)'"
                )
            )
        }
        return url
    }
}

/// Number to TimeInterval converter
public struct NumberToTimeIntervalConverter: LuaTypeConverter {
    public static func convert(_ input: Double) throws -> TimeInterval {
        guard input >= 0 else {
            throw LuaKitError.invalidArgument(
                LuaErrorContext(
                    functionName: "TimeInterval conversion",
                    expectedType: "non-negative number",
                    actualType: "number",
                    additionalInfo: "TimeInterval cannot be negative: \(input)"
                )
            )
        }
        return TimeInterval(input)
    }
}

// MARK: - Enhanced LuaConvertible for common types

/// Make Date LuaConvertible
extension Date: LuaConvertible {
    public static func push(_ value: Date, to L: OpaquePointer) {
        // Push as ISO8601 string
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        lua_pushstring(L, formatter.string(from: value))
    }
    
    public static func pull(from L: OpaquePointer, at index: Int32) -> Date? {
        guard let string = String.pull(from: L, at: index) else { return nil }
        do {
            return try StringToDateConverter.convert(string)
        } catch {
            return nil
        }
    }
}

/// Make URL LuaConvertible
extension URL: LuaConvertible {
    public static func push(_ value: URL, to L: OpaquePointer) {
        lua_pushstring(L, value.absoluteString)
    }
    
    public static func pull(from L: OpaquePointer, at index: Int32) -> URL? {
        guard let string = String.pull(from: L, at: index) else { return nil }
        return URL(string: string)
    }
}

/// Make UUID LuaConvertible
extension UUID: LuaConvertible {
    public static func push(_ value: UUID, to L: OpaquePointer) {
        lua_pushstring(L, value.uuidString)
    }
    
    public static func pull(from L: OpaquePointer, at index: Int32) -> UUID? {
        guard let string = String.pull(from: L, at: index) else { return nil }
        return UUID(uuidString: string)
    }
}

/// Make Data LuaConvertible (as base64)
extension Data: LuaConvertible {
    public static func push(_ value: Data, to L: OpaquePointer) {
        lua_pushstring(L, value.base64EncodedString())
    }
    
    public static func pull(from L: OpaquePointer, at index: Int32) -> Data? {
        guard let string = String.pull(from: L, at: index) else { return nil }
        return Data(base64Encoded: string)
    }
}

// MARK: - Optional Support

/// Protocol for optional types
public protocol OptionalProtocol {
    associatedtype Wrapped
    var optional: Wrapped? { get }
}

extension Optional: OptionalProtocol {
    public var optional: Wrapped? { self }
}

/// Make Optional LuaConvertible where Wrapped is LuaConvertible
extension Optional: LuaConvertible where Wrapped: LuaConvertible {
    public static func push(_ value: Wrapped?, to L: OpaquePointer) {
        if let value = value {
            Wrapped.push(value, to: L)
        } else {
            lua_pushnil(L)
        }
    }
    
    public static func pull(from L: OpaquePointer, at index: Int32) -> Wrapped?? {
        if lua_type(L, index) == LUA_TNIL {
            return .some(nil)
        }
        return Wrapped.pull(from: L, at: index)
    }
}

// MARK: - Dictionary Support

/// Make Dictionary LuaConvertible where Key is String and Value is LuaConvertible
extension Dictionary: LuaConvertible where Key == String, Value: LuaConvertible {
    public static func push(_ value: [String: Value], to L: OpaquePointer) {
        lua_createtable(L, 0, Int32(value.count))
        
        for (key, val) in value {
            Value.push(val, to: L)
            lua_setfield(L, -2, key)
        }
    }
    
    public static func pull(from L: OpaquePointer, at index: Int32) -> [String: Value]? {
        guard lua_type(L, index) == LUA_TTABLE else { return nil }
        
        var dict: [String: Value] = [:]
        let tableIndex = lua_absindex(L, index)
        
        lua_pushnil(L) // First key
        while lua_next(L, tableIndex) != 0 {
            // Key is at index -2, value at index -1
            if let key = String.pull(from: L, at: -2),
               let value = Value.pull(from: L, at: -1) {
                dict[key] = value
            }
            lua_pop(L, 1) // Remove value, keep key for next iteration
        }
        
        return dict
    }
}

// MARK: - Type Conversion Helpers

/// Helper functions for type conversion
public struct LuaConvert {
    /// Convert a value using a registered converter
    public static func convert<T, U>(_ value: T, using converterName: String) throws -> U {
        guard let converterType = LuaTypeConverterRegistry.getConverter(named: converterName) else {
            throw LuaKitError.invalidArgument(
                LuaErrorContext(
                    functionName: "convert",
                    expectedType: "registered converter",
                    actualType: "unknown",
                    additionalInfo: "No converter registered with name '\(converterName)'"
                )
            )
        }
        
        // This is a simplified version - in practice, we'd need more sophisticated type checking
        if let converter = converterType as? any LuaTypeConverter.Type {
            // Dynamic dispatch would be needed here
            throw LuaKitError.invalidArgument(
                LuaErrorContext(
                    functionName: "convert",
                    expectedType: "converter implementation",
                    actualType: "incomplete",
                    additionalInfo: "Converter dispatch not yet implemented"
                )
            )
        }
        
        throw LuaKitError.invalidArgument(
            LuaErrorContext(
                functionName: "convert",
                expectedType: "LuaTypeConverter",
                actualType: String(describing: type(of: converterType)),
                additionalInfo: "Invalid converter type"
            )
        )
    }
    
    /// Try to convert between common types automatically
    public static func autoConvert<T>(_ value: Any, to type: T.Type) -> T? {
        // Direct cast
        if let result = value as? T {
            return result
        }
        
        // String conversions
        if let string = value as? String {
            switch type {
            case is Int.Type:
                return Int(string) as? T
            case is Double.Type:
                return Double(string) as? T
            case is Bool.Type:
                return Bool(string) as? T
            case is UUID.Type:
                return UUID(uuidString: string) as? T
            case is URL.Type:
                return URL(string: string) as? T
            default:
                break
            }
        }
        
        // Number conversions
        if let number = value as? NSNumber {
            switch type {
            case is Int.Type:
                return number.intValue as? T
            case is Double.Type:
                return number.doubleValue as? T
            case is Bool.Type:
                return number.boolValue as? T
            case is Float.Type:
                return number.floatValue as? T
            default:
                break
            }
        }
        
        return nil
    }
}