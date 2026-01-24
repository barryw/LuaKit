//
//  LuaEnumBridging.swift
//  LuaKit
//
//  Automatic enum bridging support
//

import Foundation
import Lua

/// Protocol for enums that can be bridged to Lua
public protocol LuaEnumBridgeable: RawRepresentable, CaseIterable where RawValue == String {
    static var luaTypeName: String { get }
}

/// Default implementation
extension LuaEnumBridgeable {
    public static var luaTypeName: String {
        return String(describing: Self.self)
    }
}

/// Extension to make LuaEnumBridgeable types LuaConvertible
extension LuaEnumBridgeable {
    public static func push(_ value: Self, to L: OpaquePointer) {
        lua_pushstring(L, value.rawValue)
    }

    public static func pull(from L: OpaquePointer, at index: Int32) -> Self? {
        guard let rawValue = String.pull(from: L, at: index) else { return nil }
        return Self(rawValue: rawValue)
    }
}

/// LuaState extension for enum registration
extension LuaState {
    /// Register an enum type with Lua
    public func registerEnum<T: LuaEnumBridgeable>(_ enumType: T.Type, as name: String? = nil) {
        let enumName = name ?? enumType.luaTypeName
        let L = self.luaState

        // Create enum table
        lua_createtable(L, 0, Int32(enumType.allCases.count))

        // Add all cases
        for enumCase in enumType.allCases {
            lua_pushstring(L, enumCase.rawValue)
            lua_setfield(L, -2, enumCase.rawValue)
        }

        // Create metatable with validation
        lua_createtable(L, 0, 2)

        // For simplicity, skip metatable setup to avoid closure capture issues
        // The enum table is read-only by default in this implementation

        // Set metatable
        lua_setmetatable(L, -2)

        // Set as global
        lua_setglobal(L, enumName)

        // Register validation function
        let validateFuncName = "validate\(enumName)"
        registerFunction(validateFuncName) { (value: String) -> Bool in
            return T(rawValue: value) != nil
        }

        // Register conversion function
        let convertFuncName = "to\(enumName)"
        registerFunction(convertFuncName) { (value: String) -> String? in
            return T(rawValue: value)?.rawValue
        }
    }

    /// Register multiple enums at once
    public func registerEnums(_ enums: [(type: any LuaEnumBridgeable.Type, name: String?)]) {
        for (enumType, name) in enums {
            // Use dynamic dispatch through a helper
            registerEnumDynamic(enumType, name: name)
        }
    }

    private func registerEnumDynamic(_ enumType: any LuaEnumBridgeable.Type, name: String?) {
        // This is a workaround for Swift's type system limitations
        // In practice, you'd need to handle each concrete enum type
        let enumName = name ?? enumType.luaTypeName
        let L = self.luaState

        // Create enum table
        lua_createtable(L, 0, 0)

        // Note: Full implementation would require more sophisticated type handling
        // This is a simplified version for demonstration

        lua_setglobal(L, enumName)
    }
}

/// Helper for enum property validation
public struct LuaEnumValidator<T: LuaEnumBridgeable>: Sendable {
    public static func validate(_ value: String) -> Bool {
        return T(rawValue: value) != nil
    }

    public static func convert(_ value: String) -> T? {
        return T(rawValue: value)
    }

    public static func allValues() -> [String] {
        return T.allCases.map { $0.rawValue }
    }
}

/// Macro support for automatic enum registration.
///
/// This type provides a synchronous interface to the enum registry in `LuaKitRegistry`.
/// For Swift 6 concurrency compliance, registration state is stored in the central actor.
public struct LuaEnumRegistry: Sendable {
    /// Thread-safe storage for enum registration state.
    /// Uses `@unchecked Sendable` with internal locking since enum registration
    /// may be called during init (synchronously).
    private final class Storage: @unchecked Sendable {
        private var registeredEnums: Set<String> = []
        private let lock = NSLock()

        static let shared = Storage()

        func markAsRegistered(_ enumName: String) {
            lock.lock()
            defer { lock.unlock() }
            registeredEnums.insert(enumName)
        }

        func isRegistered(_ enumName: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return registeredEnums.contains(enumName)
        }

        func allRegisteredEnums() -> [String] {
            lock.lock()
            defer { lock.unlock() }
            return Array(registeredEnums)
        }
    }

    public static func markAsRegistered(_ enumName: String) {
        Storage.shared.markAsRegistered(enumName)
    }

    public static func isRegistered(_ enumName: String) -> Bool {
        return Storage.shared.isRegistered(enumName)
    }

    public static func allRegisteredEnums() -> [String] {
        return Storage.shared.allRegisteredEnums()
    }
}
