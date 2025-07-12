//
//  LuaChainableMacro.swift
//  LuaMacros
//
//  Implementation of @LuaChainable for method chaining
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LuaChainableMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get method declaration
        guard let method = declaration.as(FunctionDeclSyntax.self) else {
            return []
        }

        // Check if method already returns Self
        if let returnType = method.signature.returnClause?.type,
           returnType.description.trimmingCharacters(in: .whitespaces) == "Self" {
            // Method is already chainable
            return []
        }

        // For methods that don't return Self, we'll mark them with metadata
        let methodName = method.name.text
        let chainableMarker = """
        @available(*, deprecated, message: "Chainable method marker")
        static let __luaChainable_\(methodName) = true
        """

        return [DeclSyntax(stringLiteral: chainableMarker)]
    }
}
