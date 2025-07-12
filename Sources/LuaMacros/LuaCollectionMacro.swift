//
//  LuaCollectionMacro.swift
//  LuaMacros
//
//  Implementation of @LuaCollection for automatic collection methods
//

import Foundation
import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct LuaCollectionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract collection name from arguments
        guard case .argumentList(let arguments) = node.arguments,
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self),
              let collectionName = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text else {
            return []
        }

        // Get property declaration
        guard let property = declaration.as(VariableDeclSyntax.self),
              let binding = property.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
              let typeAnnotation = binding.typeAnnotation?.type else {
            return []
        }

        let propertyName = identifier.identifier.text
        let typeString = typeAnnotation.description.trimmingCharacters(in: .whitespaces)

        // Extract element type from array type
        guard typeString.hasPrefix("[") && typeString.hasSuffix("]") else {
            return []
        }

        let elementType = String(typeString.dropFirst().dropLast())

        // Generate collection methods
        var methods: [DeclSyntax] = []

        // Add method
        let addMethod = """
        public func add\(collectionName.capitalized)(_ item: \(elementType)) {
            \(propertyName).append(item)
        }
        """
        methods.append(DeclSyntax(stringLiteral: addMethod))

        // Remove method
        let removeMethod = """
        public func remove\(collectionName.capitalized)(_ item: \(elementType)) {
            if let index = \(propertyName).firstIndex(where: { $0 === item }) {
                \(propertyName).remove(at: index)
            }
        }
        """
        methods.append(DeclSyntax(stringLiteral: removeMethod))

        // Get at index method
        let getMethod = """
        public func get\(collectionName.capitalized)At(_ index: Int) -> \(elementType)? {
            guard index >= 0 && index < \(propertyName).count else { return nil }
            return \(propertyName)[index]
        }
        """
        methods.append(DeclSyntax(stringLiteral: getMethod))

        // Count method
        let countMethod = """
        public func get\(collectionName.capitalized)Count() -> Int {
            return \(propertyName).count
        }
        """
        methods.append(DeclSyntax(stringLiteral: countMethod))

        // Clear method
        let clearMethod = """
        public func clear\(collectionName.capitalized)() {
            \(propertyName).removeAll()
        }
        """
        methods.append(DeclSyntax(stringLiteral: clearMethod))

        return methods
    }
}
