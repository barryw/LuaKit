//
//  LuaFactoryMacro.swift
//  LuaMacros
//
//  Implementation of @LuaFactory for factory method support
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LuaFactoryMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get method declaration
        guard let method = declaration.as(FunctionDeclSyntax.self) else {
            return []
        }

        // Generate a static wrapper if the method isn't already static
        let isStatic = method.modifiers.contains { $0.name.tokenKind == .keyword(.static) }

        if !isStatic {
            // Generate documentation comment
            let docComment = """
            /// Factory method wrapper for Lua
            /// This method is automatically exposed as a static factory method in Lua
            """

            return [DeclSyntax(stringLiteral: docComment)]
        }

        return []
    }
}
