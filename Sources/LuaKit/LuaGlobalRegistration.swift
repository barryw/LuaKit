//
//  LuaGlobalRegistration.swift
//  LuaKit
//
//  Enhanced global function and value registration
//

import Foundation
import Lua

/// Enhanced global registration methods
public extension LuaState {
    // MARK: - Type-safe Global Registration

    /// Register a global value with type safety
    func registerGlobal<T: LuaConvertible>(_ name: String, _ value: T) {
        T.push(value, to: luaState)
        lua_setglobal(luaState, name)

        if LuaDebugConfig.isEnabled {
            LuaDebugConfig.log("Registered global '\(name)' with value: \(value)", level: .info)
        }
    }

    /// Register a global LuaBridgeable instance
    func registerGlobal<T: LuaBridgeable>(_ name: String, _ value: T) {
        globals[name] = value

        if LuaDebugConfig.isEnabled {
            LuaDebugConfig.log("Registered global '\(name)' with type: \(type(of: value))", level: .info)
        }
    }

    /// Register multiple globals at once
    func registerGlobals(_ globals: [String: Any]) {
        for (name, value) in globals {
            self.globals[name] = value

            if LuaDebugConfig.isEnabled {
                LuaDebugConfig.log("Registered global '\(name)'", level: .verbose)
            }
        }
    }

    // MARK: - Namespace Support

    /// Register a namespace table
    func registerNamespace(_ name: String) -> LuaNamespace {
        let namespace = LuaNamespace(luaState: self, name: name)
        let table = createTable()
        globals.set(name, to: table)

        if LuaDebugConfig.isEnabled {
            LuaDebugConfig.log("Created namespace '\(name)'", level: .info)
        }

        return namespace
    }

    /// Register values under a namespace
    func registerInNamespace(_ namespace: String, name: String, value: Any) {
        // Ensure namespace exists
        let L = luaState
        lua_getglobal(L, namespace)

        if lua_type(L, -1) != LUA_TTABLE {
            lua_pop(L, 1)
            // Create namespace if it doesn't exist
            lua_createtable(L, 0, 0)
            lua_pushvalue(L, -1) // Duplicate table reference
            lua_setglobal(L, namespace)
        }

        // Set value in namespace
        pushValue(value, to: L)
        lua_setfield(L, -2, name)
        lua_pop(L, 1) // Pop namespace table

        if LuaDebugConfig.isEnabled {
            LuaDebugConfig.log("Registered '\(name)' in namespace '\(namespace)'", level: .verbose)
        }
    }

    // MARK: - Function Registration with Documentation

    /// Register a documented global function
    func registerDocumentedFunction(
        _ name: String,
        description: String,
        parameters: [(name: String, type: String, description: String)] = [],
        returns: String? = nil,
        function: LuaFunction
    ) {
        // Register the function
        function.push(to: luaState)
        lua_setglobal(luaState, name)

        // Store documentation metadata
        let docKey = "__luakit_doc_\(name)"
        let doc = LuaFunctionDocumentation(
            name: name,
            description: description,
            parameters: parameters,
            returns: returns
        )

        globals[docKey] = doc.toJSON()

        if LuaDebugConfig.isEnabled {
            LuaDebugConfig.log("Registered documented function '\(name)'", level: .info)
        }
    }

    // MARK: - Enum Registration

    /// Register an enum type with string conversion
    func registerEnum<T: RawRepresentable>(_ enumType: T.Type, as name: String) where T.RawValue == String {
        let table = createTable()

        // Use reflection to get all cases
        if let caseIterable = enumType as? any CaseIterable.Type {
            for enumCase in caseIterable.allCases {
                if let value = enumCase as? T {
                    table[value.rawValue] = value.rawValue
                }
            }
        }

        globals.set(name, to: table)

        if LuaDebugConfig.isEnabled {
            LuaDebugConfig.log("Registered enum '\(name)'", level: .info)
        }
    }

    // MARK: - Private Helpers

    private func pushValue(_ value: Any, to L: OpaquePointer) {
        switch value {
        case let bool as Bool:
            lua_pushboolean(L, bool ? 1 : 0)
        case let int as Int:
            lua_pushinteger(L, lua_Integer(int))
        case let double as Double:
            lua_pushnumber(L, double)
        case let string as String:
            lua_pushstring(L, string)
        case let function as LuaFunction:
            function.push(to: L)
        case let bridgeable as LuaBridgeable:
            type(of: bridgeable).pushAny(bridgeable, to: L)
        case let reference as LuaReference:
            reference.push()
        case let table as LuaTable:
            table.push()
        default:
            lua_pushnil(L)
        }
    }
}

/// Represents a Lua namespace
public class LuaNamespace {
    public let name: String
    private weak var luaState: LuaState?

    init(luaState: LuaState, name: String) {
        self.name = name
        self.luaState = luaState
    }

    /// Register a value in this namespace
    public func register(_ name: String, _ value: Any) {
        luaState?.registerInNamespace(self.name, name: name, value: value)
    }

    /// Create a sub-namespace
    public func namespace(_ name: String) -> LuaNamespace? {
        guard let luaState = luaState else { return nil }

        let fullName = "\(self.name).\(name)"
        luaState.registerInNamespace(self.name, name: name, value: luaState.createTable())

        return LuaNamespace(luaState: luaState, name: fullName)
    }
}

/// Documentation for a Lua function
public struct LuaFunctionDocumentation {
    public let name: String
    public let description: String
    public let parameters: [(name: String, type: String, description: String)]
    public let returns: String?

    func toJSON() -> String {
        var json = "{"
        json += "\"name\":\"\(name)\","
        json += "\"description\":\"\(description)\","
        json += "\"parameters\":["

        for (index, param) in parameters.enumerated() {
            if index > 0 { json += "," }
            json += "{\"name\":\"\(param.name)\",\"type\":\"\(param.type)\",\"description\":\"\(param.description)\"}"
        }

        json += "]"

        if let returns = returns {
            json += ",\"returns\":\"\(returns)\""
        }

        json += "}"
        return json
    }
}

// LuaGlobals is defined in LuaGlobals.swift - extending it here
extension LuaGlobals {
    /// Create a namespace builder
    public func namespace(_ name: String) -> LuaNamespaceBuilder {
        return LuaNamespaceBuilder(luaState: self.luaState, name: name)
    }
}

/// Fluent builder for namespaces
public class LuaNamespaceBuilder {
    private let name: String
    private let luaState: LuaState
    private var items: [(String, Any)] = []

    init(luaState: LuaState, name: String) {
        self.name = name
        self.luaState = luaState
    }

    /// Add an item to the namespace
    public func add(_ name: String, _ value: Any) -> LuaNamespaceBuilder {
        items.append((name, value))
        return self
    }

    /// Add a function to the namespace
    public func function(_ name: String, _ closure: @escaping () -> Any) -> LuaNamespaceBuilder {
        items.append((name, LuaFunction(closure)))
        return self
    }

    /// Build the namespace
    public func build() {
        _ = luaState.registerNamespace(name)
        for (itemName, value) in items {
            luaState.registerInNamespace(name, name: itemName, value: value)
        }
    }
}
