//
//  EnhancedMacros.swift
//  LuaMacros
//
//  Enhanced macro attributes for LuaKit
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - Enhanced Macro Declarations

/// Collection attribute for automatic collection methods
@attached(peer)
public macro LuaCollection(_ name: String) = #externalMacro(
    module: "LuaMacros",
    type: "LuaCollectionMacro"
)

/// Method alias attribute
@attached(peer)
public macro LuaAlias(_ names: String...) = #externalMacro(
    module: "LuaMacros",
    type: "LuaAliasMacro"
)

/// Factory method attribute
@attached(peer)
public macro LuaFactory() = #externalMacro(
    module: "LuaMacros",
    type: "LuaFactoryMacro"
)

/// Enhanced property attribute with validation
@attached(peer)
public macro LuaProperty(
    readOnly: Bool = false,
    validator: String? = nil,
    min: Double? = nil,
    max: Double? = nil,
    regex: String? = nil,
    enumValues: [String] = []
) = #externalMacro(
    module: "LuaMacros",
    type: "LuaPropertyMacro"
)

/// Async method attribute
@attached(peer)
public macro LuaAsync() = #externalMacro(
    module: "LuaMacros",
    type: "LuaAsyncMacro"
)

/// Documentation attributes
@attached(peer)
public macro LuaDoc(_ description: String) = #externalMacro(
    module: "LuaMacros",
    type: "LuaDocMacro"
)

@attached(peer)
public macro LuaParam(_ name: String, _ description: String) = #externalMacro(
    module: "LuaMacros",
    type: "LuaParamMacro"
)

/// Method chaining attribute
@attached(peer)
public macro LuaChainable() = #externalMacro(
    module: "LuaMacros",
    type: "LuaChainableMacro"
)

/// Type conversion attribute
@attached(peer)
public macro LuaConvert(from: Any.Type, using: String) = #externalMacro(
    module: "LuaMacros",
    type: "LuaConvertMacro"
)

/// Namespace attribute
@attached(member)
public macro LuaNamespace(_ name: String) = #externalMacro(
    module: "LuaMacros",
    type: "LuaNamespaceMacro"
)

/// Relationship attribute
@attached(peer)
public macro LuaRelationship(
    type: RelationshipType,
    inverse: String? = nil,
    cascade: CascadeType = .none
) = #externalMacro(
    module: "LuaMacros",
    type: "LuaRelationshipMacro"
)

// MARK: - Supporting Types

public enum RelationshipType {
    case oneToOne
    case oneToMany
    case manyToOne
    case manyToMany
}

public enum CascadeType {
    case none
    case delete
    case nullify
}

// MARK: - Enhanced LuaBridgeable with debug mode

// Note: The enhanced @LuaBridgeable is defined in LuaMacrosPlugin.swift