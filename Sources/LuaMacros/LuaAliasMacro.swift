//
//  LuaAliasMacro.swift
//  LuaMacros
//
//  Implementation of @LuaAlias for method aliasing
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct LuaAliasMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract alias names from arguments
        guard case .argumentList(let arguments) = node.arguments else {
            return []
        }
        
        var aliases: [String] = []
        for argument in arguments {
            if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
               let alias = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                aliases.append(alias)
            }
        }
        
        // Get method declaration
        guard let method = declaration.as(FunctionDeclSyntax.self) else {
            return []
        }
        
        let methodName = method.name.text
        let parameters = method.signature.parameterClause.parameters
        let returnClause = method.signature.returnClause
        
        // Build parameter list for forwarding
        var forwardParams: [String] = []
        for param in parameters {
            let label = param.firstName.text
            if label == "_" {
                forwardParams.append(param.secondName?.text ?? "")
            } else {
                forwardParams.append("\(label): \(param.secondName?.text ?? label)")
            }
        }
        let forwardParamsString = forwardParams.joined(separator: ", ")
        
        // Generate alias methods
        var aliasMethods: [DeclSyntax] = []
        
        for alias in aliases {
            let aliasMethod = """
            @available(*, deprecated, renamed: "\(methodName)")
            public func \(alias)\(method.signature.parameterClause)\(returnClause?.description ?? "") {
                \(returnClause != nil ? "return " : "")\(methodName)(\(forwardParamsString))
            }
            """
            aliasMethods.append(DeclSyntax(stringLiteral: aliasMethod))
        }
        
        return aliasMethods
    }
}