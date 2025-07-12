//
//  LuaConvertMacro.swift
//  LuaMacros
//
//  Implementation of @LuaConvert for type conversion
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct LuaConvertMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract converter info from arguments
        guard case .argumentList(let arguments) = node.arguments,
              arguments.count >= 2 else {
            return []
        }
        
        var fromType: String?
        var converterName: String?
        
        for argument in arguments {
            if let label = argument.label?.text {
                switch label {
                case "from":
                    if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                        fromType = memberAccess.base?.description ?? memberAccess.declName.baseName.text
                    }
                case "using":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let converter = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                        converterName = converter
                    }
                default:
                    break
                }
            }
        }
        
        // Get parameter declaration
        guard let function = declaration.as(FunctionDeclSyntax.self),
              let fromType = fromType,
              let converterName = converterName else {
            return []
        }
        
        // Store conversion metadata
        let functionName = function.name.text
        let conversionMarker = """
        @available(*, deprecated, message: "Type conversion metadata")
        static let __luaConvert_\(functionName) = (from: "\(fromType)", using: "\(converterName)")
        """
        
        return [DeclSyntax(stringLiteral: conversionMarker)]
    }
}