//
//  LuaNamespaceMacro.swift
//  LuaMacros
//
//  Implementation of @LuaNamespace for namespace support
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LuaNamespaceMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract namespace name
        guard case .argumentList(let arguments) = node.arguments,
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let namespaceName = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text else {
            return []
        }

        // Get type name
        let _: String
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            _ = classDecl.name.text
        } else if let structDecl = declaration.as(StructDeclSyntax.self) {
            _ = structDecl.name.text
        } else {
            return []
        }

        // Generate namespace registration method
        let registrationMethod = """
        public static func registerInNamespace(_ L: OpaquePointer, namespace: String = "\(namespaceName)") {
            // Get or create namespace table
            lua_getglobal(L, namespace)
            if lua_type(L, -1) != LUA_TTABLE {
                lua_pop(L, 1)
                lua_createtable(L, 0, 0)
                lua_pushvalue(L, -1)
                lua_setglobal(L, namespace)
            }

            // Register all static methods in the namespace
            registerStaticMethods(L)

            lua_pop(L, 1) // Pop namespace table
        }

        private static func registerStaticMethods(_ L: OpaquePointer) {
            // This will be filled in by the macro expansion with actual static methods
        }
        """

        return [DeclSyntax(stringLiteral: registrationMethod)]
    }
}
