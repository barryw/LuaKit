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

private protocol AnyLuaTypeConverter: Sendable {
    var converterType: Any.Type { get }
    var inputType: Any.Type { get }
    var outputType: Any.Type { get }

    func convert(_ value: Any, converterName: String) throws -> Any
}

private struct LuaTypeConverterBox<Converter: LuaTypeConverter>: AnyLuaTypeConverter {
    let converterType: Any.Type = Converter.self
    let inputType: Any.Type = Converter.InputType.self
    let outputType: Any.Type = Converter.OutputType.self

    func convert(_ value: Any, converterName: String) throws -> Any {
        guard let typedValue = value as? Converter.InputType else {
            throw LuaError.invalidArgument(
                "Converter '\(converterName)' expected \(Converter.InputType.self), got \(type(of: value))"
            )
        }

        return try Converter.convert(typedValue)
    }
}

/// Registry for custom type converters.
///
/// Thread-safe for Swift 6 concurrency compliance.
public final class LuaTypeConverterRegistry: @unchecked Sendable {
    private struct Entry: Sendable {
        let converter: any AnyLuaTypeConverter
    }

    /// Thread-safe storage for converters
    private final class Storage: @unchecked Sendable {
        private var converters: [String: Entry] = [:]
        private let lock = NSLock()

        static let shared = Storage()

        func register<T: LuaTypeConverter>(_ converter: T.Type, name: String) {
            lock.lock()
            defer { lock.unlock() }
            converters[name] = Entry(converter: LuaTypeConverterBox<T>())
        }

        func getConverter(named name: String) -> Any? {
            lock.lock()
            defer { lock.unlock() }
            return converters[name]?.converter.converterType
        }

        func getDispatcher(named name: String) -> (any AnyLuaTypeConverter)? {
            lock.lock()
            defer { lock.unlock() }
            return converters[name]?.converter
        }
    }

    /// Register a custom converter
    public static func register<T: LuaTypeConverter>(_ converter: T.Type, name: String) {
        Storage.shared.register(converter, name: name)
    }

    /// Get a converter by name
    public static func getConverter(named name: String) -> Any? {
        return Storage.shared.getConverter(named: name)
    }

    fileprivate static func getDispatcher(named name: String) -> (any AnyLuaTypeConverter)? {
        return Storage.shared.getDispatcher(named: name)
    }
}

// MARK: - Built-in Type Converters

/// String to UUID converter
public struct StringToUUIDConverter: LuaTypeConverter, Sendable {
    public static func convert(_ input: String) throws -> UUID {
        guard let uuid = UUID(uuidString: input) else {
            throw LuaError.invalidArgument("Invalid UUID format: '\(input)'")
        }
        return uuid
    }
}

/// String to Date converter (ISO8601)
public struct StringToDateConverter: LuaTypeConverter, Sendable {
    /// ISO8601 date formatter. Using `nonisolated(unsafe)` because ISO8601DateFormatter
    /// is thread-safe for reading but not marked as Sendable in Foundation.
    private nonisolated(unsafe) static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public static func convert(_ input: String) throws -> Date {
        guard let date = formatter.date(from: input) else {
            throw LuaError.invalidArgument(
                "Invalid date format: '\(input)'. Use ISO8601 format: YYYY-MM-DDTHH:MM:SS.sssZ"
            )
        }
        return date
    }
}

/// String to URL converter
public struct StringToURLConverter: LuaTypeConverter, Sendable {
    public static func convert(_ input: String) throws -> URL {
        guard let url = URL(string: input) else {
            throw LuaError.invalidArgument("Invalid URL format: '\(input)'")
        }
        return url
    }
}

/// Number to TimeInterval converter
public struct NumberToTimeIntervalConverter: LuaTypeConverter, Sendable {
    public static func convert(_ input: Double) throws -> TimeInterval {
        guard input >= 0 else {
            throw LuaError.invalidArgument("TimeInterval cannot be negative: \(input)")
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
        luaPushString(L, formatter.string(from: value))
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
        luaPushString(L, value.absoluteString)
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> URL? {
        guard let string = String.pull(from: L, at: index) else { return nil }
        return URL(string: string)
    }
}

/// Make UUID LuaConvertible
extension UUID: LuaConvertible {
    public static func push(_ value: UUID, to L: OpaquePointer) {
        luaPushString(L, value.uuidString)
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> UUID? {
        guard let string = String.pull(from: L, at: index) else { return nil }
        return UUID(uuidString: string)
    }
}

/// Make Data LuaConvertible (as base64)
extension Data: LuaConvertible {
    public static func push(_ value: Data, to L: OpaquePointer) {
        luaPushString(L, value.base64EncodedString())
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
            if lua_type(L, -2) == LUA_TSTRING,
               let key = String.pull(from: L, at: -2),
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
public struct LuaConvert: Sendable {
    /// Convert a value using a registered converter
    public static func convert<T, U>(_ value: T, using converterName: String) throws -> U {
        guard let converter = LuaTypeConverterRegistry.getDispatcher(named: converterName) else {
            throw LuaError.invalidArgument("No converter registered with name '\(converterName)'")
        }

        let converted = try converter.convert(value, converterName: converterName)
        guard let typedResult = converted as? U else {
            throw LuaError.invalidArgument(
                "Converter '\(converterName)' returned \(type(of: converted)); expected \(U.self)"
            )
        }

        return typedResult
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
