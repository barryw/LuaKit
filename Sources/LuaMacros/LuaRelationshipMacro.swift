//
//  LuaRelationshipMacro.swift
//  LuaMacros
//
//  Implementation of @LuaRelationship for relationship management
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct LuaRelationshipMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract relationship configuration
        guard case .argumentList(let arguments) = node.arguments else {
            return []
        }
        
        var relationshipType: String?
        var inverseName: String?
        var cascadeType: String = "none"
        
        for argument in arguments {
            if let label = argument.label?.text {
                switch label {
                case "type":
                    if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                        relationshipType = memberAccess.declName.baseName.text
                    }
                case "inverse":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let inverse = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                        inverseName = inverse
                    }
                case "cascade":
                    if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                        cascadeType = memberAccess.declName.baseName.text
                    }
                default:
                    break
                }
            }
        }
        
        // Get property declaration
        guard let property = declaration.as(VariableDeclSyntax.self),
              let binding = property.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let relationshipType = relationshipType else {
            return []
        }
        
        let propertyName = identifier.identifier.text
        
        // Generate relationship management methods
        var methods: [DeclSyntax] = []
        
        // Cascade delete support
        if cascadeType == "delete" {
            let cascadeMethod = """
            private func cascadeDelete\(propertyName.capitalized)() {
                // Implement cascade delete logic
                \(propertyName).removeAll()
            }
            """
            methods.append(DeclSyntax(stringLiteral: cascadeMethod))
        }
        
        // Store relationship metadata
        let metadataProperty = """
        @available(*, deprecated, message: "Relationship metadata")
        static let __luaRelationship_\(propertyName) = (type: "\(relationshipType)", inverse: "\(inverseName ?? "")", cascade: "\(cascadeType)")
        """
        methods.append(DeclSyntax(stringLiteral: metadataProperty))
        
        return methods
    }
}