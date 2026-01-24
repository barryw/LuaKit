//
//  LuaMacros.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

/// Bridging mode for LuaBridgeable classes
public enum LuaBridgeMode {
    /// Bridge all public members by default (can opt-out with @LuaIgnore)
    case automatic
    /// Only bridge members explicitly marked with @LuaOnly
    case explicit
}

/// A macro that generates Lua bridging boilerplate for Swift classes.
///
/// This macro eliminates the need to manually implement LuaBridgeable methods
/// by automatically generating luaNew, registerConstructor, and registerMethods
/// based on the class structure.
///
/// Usage:
/// ```swift
/// // Bridge all public members (default)
/// @LuaBridgeable
/// public class Image {
///     public var width: Int        // ✅ Bridged
///     public var height: Int       // ✅ Bridged
///     private var cache: Data      // ❌ Not bridged (private)
///
///     @LuaIgnore
///     public var internalId: UUID  // ❌ Not bridged (opt-out)
///
///     public init(width: Int, height: Int) { ... }
///
///     public func resize(width: Int, height: Int) { ... }  // ✅ Bridged
///
///     @LuaIgnore
///     public func destroy() { ... }  // ❌ Not bridged (opt-out)
/// }
///
/// // Bridge only explicitly marked members
/// @LuaBridgeable(mode: .explicit)
/// public class SecureData {
///     @LuaOnly
///     public var publicInfo: String  // ✅ Bridged (opt-in)
///
///     public var secretKey: String   // ❌ Not bridged (not marked)
///
///     @LuaOnly
///     public func getPublicData() -> String { ... }  // ✅ Bridged (opt-in)
///
///     public func deleteAll() { ... }  // ❌ Not bridged (not marked)
/// }
/// ```
@attached(member, names: named(luaNew), named(registerConstructor), named(registerMethods))
public macro LuaBridgeable(mode: LuaBridgeMode = .automatic) = #externalMacro(
module: "LuaMacros",
type: "LuaBridgeableMacro"
)

/// A macro that prevents a method or property from being exposed to Lua.
///
/// Use this in automatic mode to opt-out specific members from Lua bridging.
///
/// Usage:
/// ```swift
/// @LuaBridgeable  // automatic mode (default)
/// public class BankAccount {
///     public var balance: Double       // ✅ Bridged
///
///     @LuaIgnore
///     public var accountNumber: String // ❌ Not bridged (sensitive data)
///
///     public func deposit(_ amount: Double) { ... }  // ✅ Bridged
///
///     @LuaIgnore
///     public func deleteAccount() { ... }  // ❌ Not bridged (dangerous operation)
/// }
/// ```
@attached(peer)
public macro LuaIgnore() = #externalMacro(module: "LuaMacros", type: "LuaIgnoreMacro")

/// A macro that explicitly marks a method or property to be exposed to Lua.
///
/// Use this in explicit mode to opt-in specific members for Lua bridging.
///
/// Usage:
/// ```swift
/// @LuaBridgeable(mode: .explicit)
/// public class SecureDocument {
///     @LuaOnly
///     public var title: String         // ✅ Bridged (explicitly marked)
///
///     public var encryptedContent: Data // ❌ Not bridged (not marked)
///
///     @LuaOnly
///     public func getTitle() -> String { ... }  // ✅ Bridged (explicitly marked)
///
///     public func decrypt() -> String { ... }   // ❌ Not bridged (not marked)
/// }
/// ```
@attached(peer)
public macro LuaOnly() = #externalMacro(module: "LuaMacros", type: "LuaOnlyMacro")

/// A macro that marks a method to be exposed to Lua with specific options.
///
/// This provides fine-grained control over method exposure.
@attached(peer)
public macro LuaMethod() = #externalMacro(module: "LuaMacros", type: "LuaMethodMacro")

/// A macro that marks a property to be exposed to Lua with specific options.
///
/// Usage:
/// ```swift
/// @LuaProperty(readable: true, writable: false)
/// var readOnlyProperty: String
/// ```
@attached(peer)
public macro LuaProperty(readable: Bool = true, writable: Bool = false) = #externalMacro(
module: "LuaMacros",
type: "LuaPropertyMacro"
)

/// A macro that specifies constructor parameters for Lua object creation.
///
/// Usage:
/// ```swift
/// @LuaConstructor(parameters: [.int, .int])
/// init(width: Int, height: Int) { ... }
/// ```
@attached(peer)
public macro LuaConstructor(parameters: [LuaParameterType]) = #externalMacro(module: "LuaMacros", type: "LuaConstructorMacro")

/// Supported Lua parameter types for automatic conversion
public enum LuaParameterType {
    case int
    case double
    case string
    case bool
}

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

/// Async method attribute
@attached(peer)
public macro LuaAsync() = #externalMacro(
    module: "LuaMacros",
    type: "LuaAsyncMacro"
)

/// Documentation attribute
@attached(peer)
public macro LuaDoc(_ description: String) = #externalMacro(
    module: "LuaMacros",
    type: "LuaDocMacro"
)

/// Parameter documentation attribute
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

/// Relationship types for LuaRelationship macro
public enum RelationshipType: Sendable {
    case oneToOne
    case oneToMany
    case manyToOne
    case manyToMany
}

/// Cascade types for relationship handling
public enum CascadeType: Sendable {
    case none
    case delete
    case nullify
}

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
