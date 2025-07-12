//
//  LuaAsyncMacro.swift
//  LuaMacros
//
//  Implementation of @LuaAsync for async method support
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LuaAsyncMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Get method declaration
        guard let method = declaration.as(FunctionDeclSyntax.self) else {
            return []
        }

        let methodName = method.name.text
        let parameters = method.signature.parameterClause.parameters
        let returnType = method.signature.returnClause?.type.description ?? "Void"

        // Build parameter list
        var paramList: [String] = []
        var argList: [String] = []

        for param in parameters {
            let firstName = param.firstName.text
            let secondName = param.secondName?.text
            let paramName = secondName ?? firstName
            let paramType = param.type.description

            if firstName == "_" {
                paramList.append("_ \(paramName): \(paramType)")
                argList.append(paramName)
            } else {
                paramList.append("\(firstName): \(paramType)")
                argList.append("\(firstName): \(paramName)")
            }
        }

        let paramString = paramList.joined(separator: ", ")
        let argString = argList.joined(separator: ", ")

        // Generate callback-based wrapper
        let callbackWrapper = """
        public func \(methodName)Callback(\(paramString)\(paramList.isEmpty ? "" : ", ")callback: @escaping (\(returnType == "Void" ? "" : returnType + ", ")Error?) -> Void) {
            Task {
                do {
                    \(returnType == "Void" ? "" : "let result = ")try await \(methodName)(\(argString))
                    callback(\(returnType == "Void" ? "" : "result, ")nil)
                } catch {
                    callback(\(returnType == "Void" ? "" : "nil, ")error)
                }
            }
        }
        """

        return [DeclSyntax(stringLiteral: callbackWrapper)]
    }
}
