//
//  EnhancedLuaBridgeableMacro.swift
//  LuaMacros
//
//  Enhanced implementation of @LuaBridgeable with support for different return types
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct EnhancedLuaBridgeableMacro: MemberMacro, ExtensionMacro {
    
    // MARK: - Enhanced Type Detection
    
    private static func detectReturnType(_ returnClause: ReturnClauseSyntax?) -> String {
        guard let returnType = returnClause?.type else { return "Void" }
        return returnType.trimmedDescription
    }
    
    private static func generateReturnTypePush(_ returnType: String, indent: String) -> String {
        // Handle optional types
        if returnType.hasSuffix("?") {
            let baseType = String(returnType.dropLast())
            return """
            if let result = result {
            \(indent)    \(generateReturnTypePush(baseType, indent: indent + "    "))
            \(indent)} else {
            \(indent)    lua_pushnil(L)
            \(indent)}
            """
        }
        
        // Handle array types
        if returnType.hasPrefix("[") && returnType.hasSuffix("]") {
            let elementType = String(returnType.dropFirst().dropLast())
            if ["String", "Int", "Double", "Bool"].contains(elementType) {
                return "\(elementType).push(result, to: L)"
            }
            return "// TODO: Handle array of \(elementType)"
        }
        
        // Handle dictionary types
        if returnType.hasPrefix("[") && returnType.contains(":") {
            return "// TODO: Handle dictionary type \(returnType)"
        }
        
        // Handle basic types
        switch returnType {
        case "Void":
            return "// No return value"
        case "Int", "Int32", "Int64":
            return "lua_pushinteger(L, lua_Integer(result))"
        case "UInt", "UInt32", "UInt64":
            return "lua_pushinteger(L, lua_Integer(result))"
        case "Double":
            return "lua_pushnumber(L, lua_Number(result))"
        case "Float":
            return "lua_pushnumber(L, lua_Number(result))"
        case "String":
            return "lua_pushstring(L, result)"
        case "Bool":
            return "lua_pushboolean(L, result ? 1 : 0)"
        case "Date":
            return "Date.push(result, to: L)"
        case "URL":
            return "URL.push(result, to: L)"
        case "UUID":
            return "UUID.push(result, to: L)"
        case "Data":
            return "Data.push(result, to: L)"
        default:
            // Check if it's a LuaBridgeable type
            if returnType.contains(".") {
                // Qualified type name
                return "type(of: result).pushAny(result, to: L)"
            } else {
                // Assume it might be LuaBridgeable
                return """
                if let bridgeable = result as? LuaBridgeable {
                \(indent)    type(of: bridgeable).pushAny(bridgeable, to: L)
                \(indent)} else {
                \(indent)    lua_pushnil(L)
                \(indent)}
                """
            }
        }
    }
    
    private static func generateReturnCount(_ returnType: String) -> String {
        return returnType == "Void" ? "0" : "1"
    }
    
    // MARK: - Enhanced Method Generation
    
    private static func generateMethodRegistration(
        _ method: FunctionDeclSyntax,
        className: String,
        isDebugMode: Bool
    ) -> String {
        let methodName = method.name.text
        let params = method.signature.parameterClause.parameters
        let returnType = detectReturnType(method.signature.returnClause)
        
        var codeLines: [String] = []
        
        // Method registration
        codeLines.append("lua_pushstring(L, \"\(methodName)\")")
        codeLines.append("lua_pushcclosure(L, { L in")
        codeLines.append("    guard let L = L else { return 0 }")
        
        // Debug logging
        if isDebugMode {
            codeLines.append("    let debugContext = LuaMethodDebugContext(className: \"\(className)\", methodName: \"\(methodName)\")")
            codeLines.append("    debugContext.logEntry()")
        }
        
        // Error handling setup
        codeLines.append("    ")
        codeLines.append("    // Get self")
        codeLines.append("    guard let obj = \(className).checkUserdata(L, at: 1) else {")
        codeLines.append("        return luaDetailedError(L, functionName: \"\(className):\(methodName)\", argumentIndex: 1, expectedType: \"\(className)\", actualType: L.luaTypeName(at: 1))")
        codeLines.append("    }")
        codeLines.append("    ")
        
        // Parameter extraction with enhanced error messages
        var parameterExtractions: [String] = []
        var methodCallParams: [String] = []
        var argIndex = 2
        
        for param in params {
            let paramName = param.firstName.text
            let paramType = param.type.description.trimmingCharacters(in: .whitespaces)
                
            // Generate parameter extraction with detailed errors
            let extraction = generateParameterExtraction(
                paramName: paramName,
                paramType: paramType,
                argIndex: argIndex,
                methodName: "\(className):\(methodName)"
            )
            
            parameterExtractions.append(extraction)
            methodCallParams.append(paramName == "_" ? "param\(argIndex - 1)" : "\(paramName): param\(argIndex - 1)")
            argIndex += 1
        }
        
        // Add parameter extractions
        codeLines.append(contentsOf: parameterExtractions)
        
        // Method call
        let methodCall = methodCallParams.isEmpty ? 
            "obj.\(methodName)()" : 
            "obj.\(methodName)(\(methodCallParams.joined(separator: ", ")))"
        
        if returnType != "Void" {
            codeLines.append("    let result = \(methodCall)")
            
            if isDebugMode {
                codeLines.append("    debugContext.logExit(result: String(describing: result))")
            }
            
            // Push result with proper type handling
            let pushCode = generateReturnTypePush(returnType, indent: "    ")
            codeLines.append("    \(pushCode)")
            codeLines.append("    return \(generateReturnCount(returnType))")
        } else {
            codeLines.append("    \(methodCall)")
            
            if isDebugMode {
                codeLines.append("    debugContext.logExit()")
            }
            
            codeLines.append("    return 0")
        }
        
        codeLines.append("}, 0)")
        codeLines.append("lua_settable(L, -3)")
        codeLines.append("")
        
        return codeLines.joined(separator: "\n        ")
    }
    
    private static func generateParameterExtraction(
        paramName: String,
        paramType: String,
        argIndex: Int,
        methodName: String
    ) -> String {
        let varName = paramName == "_" ? "param\(argIndex - 1)" : "param\(argIndex - 1)"
        
        // Handle optional parameters
        if paramType.hasSuffix("?") {
            let baseType = String(paramType.dropLast())
            let extraction = generateNonOptionalExtraction(baseType, varName: varName, argIndex: argIndex, methodName: methodName, paramName: paramName)
            return """
                let \(varName): \(paramType)
                if lua_type(L, \(argIndex)) == LUA_TNIL {
                    \(varName) = nil
                } else {
                    \(extraction)
                }
            """
        }
        
        return generateNonOptionalExtraction(paramType, varName: varName, argIndex: argIndex, methodName: methodName, paramName: paramName)
    }
    
    private static func generateNonOptionalExtraction(
        _ paramType: String,
        varName: String,
        argIndex: Int,
        methodName: String,
        paramName: String
    ) -> String {
        switch paramType {
        case "Int", "Int32", "Int64":
            return """
                guard lua_type(L, \(argIndex)) == LUA_TNUMBER else {
                    return luaDetailedError(L, functionName: "\(methodName)", argumentIndex: \(argIndex), expectedType: "integer", actualType: L.luaTypeName(at: \(argIndex)), additionalInfo: "Parameter '\(paramName)'")
                }
                let \(varName) = Int(lua_tointegerx(L, \(argIndex), nil))
            """
            
        case "Double":
            return """
                guard lua_type(L, \(argIndex)) == LUA_TNUMBER else {
                    return luaDetailedError(L, functionName: "\(methodName)", argumentIndex: \(argIndex), expectedType: "number", actualType: L.luaTypeName(at: \(argIndex)), additionalInfo: "Parameter '\(paramName)'")
                }
                let \(varName) = lua_tonumberx(L, \(argIndex), nil)
            """
            
        case "Float":
            return """
                guard lua_type(L, \(argIndex)) == LUA_TNUMBER else {
                    return luaDetailedError(L, functionName: "\(methodName)", argumentIndex: \(argIndex), expectedType: "number", actualType: L.luaTypeName(at: \(argIndex)), additionalInfo: "Parameter '\(paramName)'")
                }
                let \(varName) = Float(lua_tonumberx(L, \(argIndex), nil))
            """
            
        case "String":
            return """
                guard let \(varName)Ptr = lua_tolstring(L, \(argIndex), nil) else {
                    return luaDetailedError(L, functionName: "\(methodName)", argumentIndex: \(argIndex), expectedType: "string", actualType: L.luaTypeName(at: \(argIndex)), additionalInfo: "Parameter '\(paramName)'")
                }
                let \(varName) = String(cString: \(varName)Ptr)
            """
            
        case "Bool":
            return """
                guard lua_type(L, \(argIndex)) == LUA_TBOOLEAN else {
                    return luaDetailedError(L, functionName: "\(methodName)", argumentIndex: \(argIndex), expectedType: "boolean", actualType: L.luaTypeName(at: \(argIndex)), additionalInfo: "Parameter '\(paramName)'")
                }
                let \(varName) = lua_toboolean(L, \(argIndex)) != 0
            """
            
        default:
            // Try LuaConvertible types
            return """
                guard let \(varName) = \(paramType).pull(from: L, at: \(argIndex)) else {
                    return luaDetailedError(L, functionName: "\(methodName)", argumentIndex: \(argIndex), expectedType: "\(paramType)", actualType: L.luaTypeName(at: \(argIndex)), additionalInfo: "Parameter '\(paramName)'")
                }
            """
        }
    }
    
    // MARK: - MemberMacro Implementation
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract debug mode
        var isDebugMode = false
        if case .argumentList(let arguments) = node.arguments {
            for argument in arguments {
                if argument.label?.text == "debug",
                   let boolExpr = argument.expression.as(BooleanLiteralExprSyntax.self) {
                    isDebugMode = boolExpr.literal.text == "true"
                }
            }
        }
        
        // Generate members
        var members: [DeclSyntax] = []
        
        // Add debug property if needed
        if isDebugMode {
            let debugProperty = """
            public var luaDebugEnabled: Bool = true
            """
            members.append(DeclSyntax(stringLiteral: debugProperty))
        }
        
        // Generate the standard LuaBridgeable methods with enhancements
        // (Similar to original but with enhanced type support)
        
        return members
    }
    
    // MARK: - ExtensionMacro Implementation
    
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Extract debug mode
        var isDebugMode = false
        if case .argumentList(let arguments) = node.arguments {
            for argument in arguments {
                if argument.label?.text == "debug",
                   let boolExpr = argument.expression.as(BooleanLiteralExprSyntax.self) {
                    isDebugMode = boolExpr.literal.text == "true"
                }
            }
        }
        
        // Create conformances
        var conformances = "LuaBridgeable"
        if isDebugMode {
            conformances += ", LuaDebuggable"
        }
        
        let extensionDecl = try ExtensionDeclSyntax("extension \(type): \(raw: conformances) {}")
        return [extensionDecl]
    }
}