//
//  LuaDocMacro.swift
//  LuaMacros
//
//  Implementation of @LuaDoc for documentation support
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct LuaDocMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract documentation string
        guard case .argumentList(let arguments) = node.arguments,
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let docString = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text else {
            return []
        }
        
        // Store documentation in a static property
        if let method = declaration.as(FunctionDeclSyntax.self) {
            let methodName = method.name.text
            let docProperty = """
            @available(*, deprecated, message: "Documentation metadata")
            static let __luaDoc_\(methodName) = "\(docString)"
            """
            return [DeclSyntax(stringLiteral: docProperty)]
        }
        
        return []
    }
}

public struct LuaParamMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract parameter name and description
        guard case .argumentList(let arguments) = node.arguments,
              arguments.count >= 2,
              let nameArg = arguments.first,
              let descArg = arguments.dropFirst().first,
              let nameLiteral = nameArg.expression.as(StringLiteralExprSyntax.self),
              let descLiteral = descArg.expression.as(StringLiteralExprSyntax.self),
              let paramName = nameLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text,
              let paramDesc = descLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text else {
            return []
        }
        
        // Store parameter documentation
        if let method = declaration.as(FunctionDeclSyntax.self) {
            let methodName = method.name.text
            let paramProperty = """
            @available(*, deprecated, message: "Parameter documentation metadata")
            static let __luaParam_\(methodName)_\(paramName) = "\(paramDesc)"
            """
            return [DeclSyntax(stringLiteral: paramProperty)]
        }
        
        return []
    }
}