//
//  LuaMacrosPlugin.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Bridging mode for filtering members
enum BridgeMode {
    case automatic  // Bridge all public members (default), opt-out with @LuaIgnore
    case explicit   // Only bridge members marked with @LuaOnly
}

/// Implementation of the main LuaBridgeable macro.
/// This macro generates the required LuaBridgeable protocol methods.
public struct LuaBridgeableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroError.onlyApplicableToClasses
        }
        
        let className = classDecl.name.text
        
        // Parse the mode parameter from the macro arguments
        let bridgeMode = parseBridgeMode(from: node)
        
        // Extract initializers to generate luaNew method
        let initializers = classDecl.memberBlock.members
            .compactMap { $0.decl.as(InitializerDeclSyntax.self) }
            .filter { $0.modifiers.contains { $0.name.tokenKind == .keyword(.public) } }
        
        // Extract methods to bridge based on mode and attributes
        let allMethods = classDecl.memberBlock.members
            .compactMap { member -> (FunctionDeclSyntax, MemberBlockItemSyntax)? in
                guard let method = member.decl.as(FunctionDeclSyntax.self) else { return nil }
                return (method, member)
            }
        
        let bridgedMethods = allMethods
            .filter { (method, member) in
                let isPublic = method.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
                guard isPublic else { return false }
                
                // Exclude property change notification methods
                let methodName = method.name.text
                if methodName == "luaPropertyWillChange" || methodName == "luaPropertyDidChange" {
                    return false
                }
                
                return shouldBridgeMember(member: member, bridgeMode: bridgeMode)
            }
            .map { $0.0 } // Extract just the method declarations
        
        // Extract properties to bridge based on mode and attributes
        let allProperties = classDecl.memberBlock.members
            .compactMap { member -> (VariableDeclSyntax, MemberBlockItemSyntax)? in
                guard let property = member.decl.as(VariableDeclSyntax.self) else { return nil }
                return (property, member)
            }
        
        let bridgedProperties = allProperties
            .filter { (property, member) in
                let isPublic = property.modifiers.contains { $0.name.tokenKind == .keyword(.public) }
                guard isPublic else { return false }
                
                return shouldBridgeMember(member: member, bridgeMode: bridgeMode)
            }
            .map { $0.0 } // Extract just the property declarations
        
        var generatedMembers: [DeclSyntax] = []
        
        // Generate luaNew method
        generatedMembers.append(generateLuaNewMethod(className: className, initializers: initializers))
        
        // Generate registerConstructor method
        generatedMembers.append(generateRegisterConstructorMethod(className: className))
        
        // Generate registerMethods method
        generatedMembers.append(generateRegisterMethodsMethod(className: className, methods: bridgedMethods, properties: bridgedProperties))
        
        return generatedMembers
    }
    
    /// Parse the bridge mode from the macro arguments
    static func parseBridgeMode(from node: AttributeSyntax) -> BridgeMode {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return .automatic // Default mode
        }
        
        for argument in arguments {
            if let label = argument.label?.text, label == "mode" {
                if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                    switch memberAccess.declName.baseName.text {
                        case "explicit":
                            return .explicit
                        case "automatic":
                            return .automatic
                        default:
                            break
                    }
                }
            }
        }
        
        return .automatic
    }
    
    /// Check if a member should be bridged based on mode and attributes
    static func shouldBridgeMember(member: MemberBlockItemSyntax, bridgeMode: BridgeMode) -> Bool {
        let hasLuaIgnore = hasAttribute(member: member, named: "LuaIgnore")
        let hasLuaOnly = hasAttribute(member: member, named: "LuaOnly")
        
        switch bridgeMode {
            case .automatic:
                // Bridge by default, unless @LuaIgnore is present
                return !hasLuaIgnore
            case .explicit:
                // Only bridge if @LuaOnly is present
                return hasLuaOnly
        }
    }
    
    /// Check if a member has a specific attribute
    static func hasAttribute(member: MemberBlockItemSyntax, named attributeName: String) -> Bool {
        // Check function attributes
        if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
            return functionDecl.attributes.contains { attribute in
                if let customAttribute = attribute.as(AttributeSyntax.self) {
                    return customAttribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == attributeName
                }
                return false
            }
        }
        
        // Check variable attributes
        if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
            return variableDecl.attributes.contains { attribute in
                if let customAttribute = attribute.as(AttributeSyntax.self) {
                    return customAttribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text == attributeName
                }
                return false
            }
        }
        
        return false
    }
    static func generateLuaNewMethod(className: String, initializers: [InitializerDeclSyntax]) -> DeclSyntax {
        // For now, generate a basic luaNew that uses the first initializer
        let parameters = initializers.first?.signature.parameterClause.parameters ?? []
        
        var codeLines: [String] = []
        var initArgs: [String] = []
        
        // Extract parameters and generate Lua parameter extraction code
        for (index, parameter) in parameters.enumerated() {
            let paramName = parameter.firstName.text
            let luaIndex = index + 1
            
            // Type detection for constructor parameters
            if parameter.type.description.contains("Int") {
                codeLines.append("let \(paramName) = Int(luaL_checkinteger(L, \(luaIndex)))")
                initArgs.append("\(paramName): \(paramName)")
            } else if parameter.type.description.contains("Double") {
                codeLines.append("let \(paramName) = lua_tonumberx(L, \(luaIndex), nil)")
                initArgs.append("\(paramName): \(paramName)")
            } else if parameter.type.description.contains("Float") {
                codeLines.append("let \(paramName) = Float(lua_tonumberx(L, \(luaIndex), nil))")
                initArgs.append("\(paramName): \(paramName)")
            } else if parameter.type.description.contains("String") {
                codeLines.append("guard let \(paramName) = String.pull(from: L, at: \(luaIndex)) else { return luaError(L, \"Expected string for \(paramName)\") }")
                initArgs.append("\(paramName): \(paramName)")
            } else if parameter.type.description.contains("Bool") {
                codeLines.append("let \(paramName) = lua_toboolean(L, \(luaIndex)) != 0")
                initArgs.append("\(paramName): \(paramName)")
            }
        }
        
        // Add instance creation and push statements
        let initArgsString = initArgs.joined(separator: ", ")
        codeLines.append("")
        codeLines.append("let instance = \(className)(\(initArgsString))")
        codeLines.append("push(instance, to: L)")
        codeLines.append("")
        codeLines.append("return 1")
        
        let bodyCode = codeLines.joined(separator: "\n    ")
        
        return DeclSyntax(stringLiteral: """
public static func luaNew(_ L: OpaquePointer) -> Int32 {
    \(bodyCode)
}
""")
    }
    
    static func generateRegisterConstructorMethod(className: String) -> DeclSyntax {
        return DeclSyntax(stringLiteral: """
public static func registerConstructor(_ L: OpaquePointer, name: String) {
    lua_createtable(L, 0, 1)
    
    lua_pushstring(L, "new")
    lua_pushcclosure(L, { L in
        guard let L = L else { return 0 }
        return \(className).luaNew(L)
    }, 0)
    lua_settable(L, -3)
    
    lua_setglobal(L, name)
}
""")
    }
    
    static func generateRegisterMethodsMethod(className: String, methods: [FunctionDeclSyntax], properties: [VariableDeclSyntax]) -> DeclSyntax {
        var codeLines: [String] = []
        
        // Generate method registrations
        for method in methods {
            let methodName = method.name.text
            let parameters = method.signature.parameterClause.parameters
            
            codeLines.append("// Register \(methodName) method")
            codeLines.append("lua_pushstring(L, \"\(methodName)\")")
            codeLines.append("lua_pushcclosure(L, { L in")
            codeLines.append("    guard let L = L else { return 0 }")
            codeLines.append("    guard let obj = \(className).checkUserdata(L, at: 1) else {")
            codeLines.append("        return luaError(L, \"Invalid \(className) object\")")
            codeLines.append("    }")
            codeLines.append("")
            
            // Generate parameter extraction for method arguments
            var methodArgs: [String] = []
            for (index, parameter) in parameters.enumerated() {
                let paramName = parameter.secondName?.text ?? parameter.firstName.text
                let argumentLabel = parameter.firstName.text == "_" ? "" : "\(parameter.firstName.text): "
                let luaIndex = index + 2 // Start at 2 since 1 is the object itself
                
                if parameter.type.description.contains("Int") {
                    codeLines.append("    let \(paramName) = Int(luaL_checkinteger(L, \(luaIndex)))")
                    methodArgs.append("\(argumentLabel)\(paramName)")
                } else if parameter.type.description.contains("Double") {
                    codeLines.append("    let \(paramName) = lua_tonumberx(L, \(luaIndex), nil)")
                    methodArgs.append("\(argumentLabel)\(paramName)")
                } else if parameter.type.description.contains("Float") {
                    codeLines.append("    let \(paramName) = Float(lua_tonumberx(L, \(luaIndex), nil))")
                    methodArgs.append("\(argumentLabel)\(paramName)")
                } else if parameter.type.description.contains("String") {
                    codeLines.append("    guard let \(paramName) = String.pull(from: L, at: \(luaIndex)) else {")
                    codeLines.append("        return luaError(L, \"Expected string for \(paramName)\")")
                    codeLines.append("    }")
                    methodArgs.append("\(argumentLabel)\(paramName)")
                } else if parameter.type.description.contains("Bool") {
                    codeLines.append("    let \(paramName) = lua_toboolean(L, \(luaIndex)) != 0")
                    methodArgs.append("\(argumentLabel)\(paramName)")
                }
            }
            
            codeLines.append("")
            let methodArgsString = methodArgs.joined(separator: ", ")
            
            // Check if method has a return type
            if let returnType = method.signature.returnClause?.type.description,
               !returnType.trimmingCharacters(in: .whitespaces).isEmpty && returnType != "Void" {
                codeLines.append("    let result = obj.\(methodName)(\(methodArgsString))")
                
                // Handle different return types
                if returnType.contains("Int") {
                    codeLines.append("    lua_pushinteger(L, lua_Integer(result))")
                    codeLines.append("    return 1")
                } else if returnType.contains("Double") || returnType.contains("Float") {
                    codeLines.append("    lua_pushnumber(L, lua_Number(result))")
                    codeLines.append("    return 1")
                } else if returnType.contains("String") {
                    codeLines.append("    lua_pushstring(L, result)")
                    codeLines.append("    return 1")
                } else if returnType.contains("Bool") {
                    codeLines.append("    lua_pushboolean(L, result ? 1 : 0)")
                    codeLines.append("    return 1")
                } else {
                    // For complex return types, try to push as userdata
                    codeLines.append("    push(result, to: L)")
                    codeLines.append("    return 1")
                }
            } else {
                // Void return type
                codeLines.append("    obj.\(methodName)(\(methodArgsString))")
                codeLines.append("    return 0")
            }
            
            codeLines.append("}, 0)")
            codeLines.append("lua_settable(L, -3)")
            codeLines.append("")
        }
        
        // Generate property access methods
        if !properties.isEmpty {
            // Generate __index method for property reading
            codeLines.append("// Register __index method for property access")
            codeLines.append("lua_pushstring(L, \"__index\")")
            codeLines.append("lua_pushcclosure(L, { L in")
            codeLines.append("    guard let L = L else { return 0 }")
            codeLines.append("    guard let obj = \(className).checkUserdata(L, at: 1) else {")
            codeLines.append("        return luaError(L, \"Invalid \(className) object\")")
            codeLines.append("    }")
            codeLines.append("")
            codeLines.append("    guard let key = String.pull(from: L, at: 2) else {")
            codeLines.append("        return 0")
            codeLines.append("    }")
            codeLines.append("")
            codeLines.append("    switch key {")
            
            for property in properties {
                // Extract property names from binding patterns
                for binding in property.bindings {
                    if let identPattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                        let propName = identPattern.identifier.text
                        let propType = binding.typeAnnotation?.type.description ?? "Unknown"
                        
                        codeLines.append("    case \"\(propName)\":")
                        // Handle array types first - return proxies instead of arrays
                        if propType.contains("[String]") {
                            codeLines.append("        let proxy = LuaStringArrayProxy(")
                            codeLines.append("            owner: obj,")
                            codeLines.append("            propertyName: \"\(propName)\",")
                            codeLines.append("            getter: { obj.\(propName) },")
                            codeLines.append("            setter: { newValue in")
                            codeLines.append("                let oldValue = obj.\(propName)")
                            codeLines.append("                let result = obj.luaPropertyWillChange(\"\(propName)\", from: oldValue as Any, to: newValue as Any)")
                            codeLines.append("                switch result {")
                            codeLines.append("                case .success:")
                            codeLines.append("                    obj.\(propName) = newValue")
                            codeLines.append("                case .failure:")
                            codeLines.append("                    break // Validation handled in proxy")
                            codeLines.append("                }")
                            codeLines.append("            },")
                            codeLines.append("            validator: { newValue in")
                            codeLines.append("                obj.luaPropertyWillChange(\"\(propName)\", from: obj.\(propName) as Any, to: newValue as Any)")
                            codeLines.append("            }")
                            codeLines.append("        )")
                            codeLines.append("        LuaStringArrayProxy.push(proxy, to: L)")
                        } else if propType.contains("[Int]") {
                            codeLines.append("        let proxy = LuaIntArrayProxy(")
                            codeLines.append("            owner: obj,")
                            codeLines.append("            propertyName: \"\(propName)\",")
                            codeLines.append("            getter: { obj.\(propName) },")
                            codeLines.append("            setter: { newValue in")
                            codeLines.append("                let oldValue = obj.\(propName)")
                            codeLines.append("                let result = obj.luaPropertyWillChange(\"\(propName)\", from: oldValue as Any, to: newValue as Any)")
                            codeLines.append("                switch result {")
                            codeLines.append("                case .success:")
                            codeLines.append("                    obj.\(propName) = newValue")
                            codeLines.append("                case .failure:")
                            codeLines.append("                    break // Validation handled in proxy")
                            codeLines.append("                }")
                            codeLines.append("            },")
                            codeLines.append("            validator: { newValue in")
                            codeLines.append("                obj.luaPropertyWillChange(\"\(propName)\", from: obj.\(propName) as Any, to: newValue as Any)")
                            codeLines.append("            }")
                            codeLines.append("        )")
                            codeLines.append("        LuaIntArrayProxy.push(proxy, to: L)")
                        } else if propType.contains("[Double]") {
                            codeLines.append("        let proxy = LuaDoubleArrayProxy(")
                            codeLines.append("            owner: obj,")
                            codeLines.append("            propertyName: \"\(propName)\",")
                            codeLines.append("            getter: { obj.\(propName) },")
                            codeLines.append("            setter: { newValue in")
                            codeLines.append("                let oldValue = obj.\(propName)")
                            codeLines.append("                let result = obj.luaPropertyWillChange(\"\(propName)\", from: oldValue as Any, to: newValue as Any)")
                            codeLines.append("                switch result {")
                            codeLines.append("                case .success:")
                            codeLines.append("                    obj.\(propName) = newValue")
                            codeLines.append("                case .failure:")
                            codeLines.append("                    break // Validation handled in proxy")
                            codeLines.append("                }")
                            codeLines.append("            },")
                            codeLines.append("            validator: { newValue in")
                            codeLines.append("                obj.luaPropertyWillChange(\"\(propName)\", from: obj.\(propName) as Any, to: newValue as Any)")
                            codeLines.append("            }")
                            codeLines.append("        )")
                            codeLines.append("        LuaDoubleArrayProxy.push(proxy, to: L)")
                        } else if propType.contains("[Bool]") {
                            codeLines.append("        let proxy = LuaBoolArrayProxy(")
                            codeLines.append("            owner: obj,")
                            codeLines.append("            propertyName: \"\(propName)\",")
                            codeLines.append("            getter: { obj.\(propName) },")
                            codeLines.append("            setter: { newValue in")
                            codeLines.append("                let oldValue = obj.\(propName)")
                            codeLines.append("                let result = obj.luaPropertyWillChange(\"\(propName)\", from: oldValue as Any, to: newValue as Any)")
                            codeLines.append("                switch result {")
                            codeLines.append("                case .success:")
                            codeLines.append("                    obj.\(propName) = newValue")
                            codeLines.append("                case .failure:")
                            codeLines.append("                    break // Validation handled in proxy")
                            codeLines.append("                }")
                            codeLines.append("            },")
                            codeLines.append("            validator: { newValue in")
                            codeLines.append("                obj.luaPropertyWillChange(\"\(propName)\", from: obj.\(propName) as Any, to: newValue as Any)")
                            codeLines.append("            }")
                            codeLines.append("        )")
                            codeLines.append("        LuaBoolArrayProxy.push(proxy, to: L)")
                        } else if propType.contains("Int") {
                            codeLines.append("        lua_pushinteger(L, lua_Integer(obj.\(propName)))")
                        } else if propType.contains("Double") || propType.contains("Float") {
                            codeLines.append("        lua_pushnumber(L, lua_Number(obj.\(propName)))")
                        } else if propType.contains("String") {
                            codeLines.append("        lua_pushstring(L, obj.\(propName))")
                        } else if propType.contains("Bool") {
                            codeLines.append("        lua_pushboolean(L, obj.\(propName) ? 1 : 0)")
                        } else {
                            codeLines.append("        push(obj.\(propName), to: L)")
                        }
                        codeLines.append("        return 1")
                    }
                }
            }
            
            codeLines.append("    default:")
            codeLines.append("        // Check metatable for methods")
            codeLines.append("        lua_getmetatable(L, 1)")
            codeLines.append("        lua_pushstring(L, key)")
            codeLines.append("        lua_rawget(L, -2)")
            codeLines.append("        return 1")
            codeLines.append("    }")
            codeLines.append("}, 0)")
            codeLines.append("lua_settable(L, -3)")
            codeLines.append("")
            
            // Generate __newindex method for property writing (only for var properties with explicit storage)
            let writableProperties = properties.filter { property in
                property.bindingSpecifier.tokenKind == .keyword(.var) &&
                property.bindings.contains { binding in
                    binding.accessorBlock == nil // Only stored properties, not computed
                }
            }
            
            if !writableProperties.isEmpty {
                codeLines.append("// Register __newindex method for property setting")
                codeLines.append("lua_pushstring(L, \"__newindex\")")
                codeLines.append("lua_pushcclosure(L, { L in")
                codeLines.append("    guard let L = L else { return 0 }")
                codeLines.append("    guard let obj = \(className).checkUserdata(L, at: 1) else {")
                codeLines.append("        return luaError(L, \"Invalid \(className) object\")")
                codeLines.append("    }")
                codeLines.append("")
                codeLines.append("    guard let key = String.pull(from: L, at: 2) else {")
                codeLines.append("        return 0")
                codeLines.append("    }")
                codeLines.append("")
                codeLines.append("    switch key {")
                
                for property in writableProperties {
                    for binding in property.bindings {
                        if let identPattern = binding.pattern.as(IdentifierPatternSyntax.self) {
                            let propName = identPattern.identifier.text
                            let propType = binding.typeAnnotation?.type.description ?? "Unknown"
                            
                            codeLines.append("    case \"\(propName)\":")
                            
                            // Get the old value first
                            codeLines.append("        let oldValue = obj.\(propName) as Any?")
                            
                            // Extract the new value based on type
                            // Handle array types first
                            if propType.contains("[String]") {
                                codeLines.append("        guard let newValue = [String].pull(from: L, at: 3) else {")
                                codeLines.append("            return luaError(L, \"Expected array of strings for \(propName)\")")
                                codeLines.append("        }")
                                codeLines.append("        switch obj.luaPropertyWillChange(\"\(propName)\", from: oldValue, to: newValue) {")
                                codeLines.append("        case .success:")
                                codeLines.append("            obj.\(propName) = newValue")
                                codeLines.append("            obj.luaPropertyDidChange(\"\(propName)\", from: oldValue, to: newValue)")
                                codeLines.append("        case .failure(let error):")
                                codeLines.append("            return luaError(L, error.message)")
                                codeLines.append("        }")
                            } else if propType.contains("[Int]") {
                                codeLines.append("        guard let newValue = [Int].pull(from: L, at: 3) else {")
                                codeLines.append("            return luaError(L, \"Expected array of integers for \(propName)\")")
                                codeLines.append("        }")
                                codeLines.append("        switch obj.luaPropertyWillChange(\"\(propName)\", from: oldValue, to: newValue) {")
                                codeLines.append("        case .success:")
                                codeLines.append("            obj.\(propName) = newValue")
                                codeLines.append("            obj.luaPropertyDidChange(\"\(propName)\", from: oldValue, to: newValue)")
                                codeLines.append("        case .failure(let error):")
                                codeLines.append("            return luaError(L, error.message)")
                                codeLines.append("        }")
                            } else if propType.contains("[Double]") {
                                codeLines.append("        guard let newValue = [Double].pull(from: L, at: 3) else {")
                                codeLines.append("            return luaError(L, \"Expected array of numbers for \(propName)\")")
                                codeLines.append("        }")
                                codeLines.append("        switch obj.luaPropertyWillChange(\"\(propName)\", from: oldValue, to: newValue) {")
                                codeLines.append("        case .success:")
                                codeLines.append("            obj.\(propName) = newValue")
                                codeLines.append("            obj.luaPropertyDidChange(\"\(propName)\", from: oldValue, to: newValue)")
                                codeLines.append("        case .failure(let error):")
                                codeLines.append("            return luaError(L, error.message)")
                                codeLines.append("        }")
                            } else if propType.contains("[Bool]") {
                                codeLines.append("        guard let newValue = [Bool].pull(from: L, at: 3) else {")
                                codeLines.append("            return luaError(L, \"Expected array of booleans for \(propName)\")")
                                codeLines.append("        }")
                                codeLines.append("        switch obj.luaPropertyWillChange(\"\(propName)\", from: oldValue, to: newValue) {")
                                codeLines.append("        case .success:")
                                codeLines.append("            obj.\(propName) = newValue")
                                codeLines.append("            obj.luaPropertyDidChange(\"\(propName)\", from: oldValue, to: newValue)")
                                codeLines.append("        case .failure(let error):")
                                codeLines.append("            return luaError(L, error.message)")
                                codeLines.append("        }")
                            } else if propType.contains("Int") {
                                codeLines.append("        let newValue = Int(luaL_checkinteger(L, 3))")
                                codeLines.append("        switch obj.luaPropertyWillChange(\"\(propName)\", from: oldValue, to: newValue) {")
                                codeLines.append("        case .success:")
                                codeLines.append("            obj.\(propName) = newValue")
                                codeLines.append("            obj.luaPropertyDidChange(\"\(propName)\", from: oldValue, to: newValue)")
                                codeLines.append("        case .failure(let error):")
                                codeLines.append("            return luaError(L, error.message)")
                                codeLines.append("        }")
                            } else if propType.contains("Double") {
                                codeLines.append("        let newValue = lua_tonumberx(L, 3, nil)")
                                codeLines.append("        switch obj.luaPropertyWillChange(\"\(propName)\", from: oldValue, to: newValue) {")
                                codeLines.append("        case .success:")
                                codeLines.append("            obj.\(propName) = newValue")
                                codeLines.append("            obj.luaPropertyDidChange(\"\(propName)\", from: oldValue, to: newValue)")
                                codeLines.append("        case .failure(let error):")
                                codeLines.append("            return luaError(L, error.message)")
                                codeLines.append("        }")
                            } else if propType.contains("Float") {
                                codeLines.append("        let newValue = Float(lua_tonumberx(L, 3, nil))")
                                codeLines.append("        switch obj.luaPropertyWillChange(\"\(propName)\", from: oldValue, to: newValue) {")
                                codeLines.append("        case .success:")
                                codeLines.append("            obj.\(propName) = newValue")
                                codeLines.append("            obj.luaPropertyDidChange(\"\(propName)\", from: oldValue, to: newValue)")
                                codeLines.append("        case .failure(let error):")
                                codeLines.append("            return luaError(L, error.message)")
                                codeLines.append("        }")
                            } else if propType.contains("String") {
                                codeLines.append("        guard let newValue = String.pull(from: L, at: 3) else {")
                                codeLines.append("            return luaError(L, \"Expected string for \(propName)\")")
                                codeLines.append("        }")
                                codeLines.append("        switch obj.luaPropertyWillChange(\"\(propName)\", from: oldValue, to: newValue) {")
                                codeLines.append("        case .success:")
                                codeLines.append("            obj.\(propName) = newValue")
                                codeLines.append("            obj.luaPropertyDidChange(\"\(propName)\", from: oldValue, to: newValue)")
                                codeLines.append("        case .failure(let error):")
                                codeLines.append("            return luaError(L, error.message)")
                                codeLines.append("        }")
                            } else if propType.contains("Bool") {
                                codeLines.append("        let newValue = lua_toboolean(L, 3) != 0")
                                codeLines.append("        switch obj.luaPropertyWillChange(\"\(propName)\", from: oldValue, to: newValue) {")
                                codeLines.append("        case .success:")
                                codeLines.append("            obj.\(propName) = newValue")
                                codeLines.append("            obj.luaPropertyDidChange(\"\(propName)\", from: oldValue, to: newValue)")
                                codeLines.append("        case .failure(let error):")
                                codeLines.append("            return luaError(L, error.message)")
                                codeLines.append("        }")
                            }
                        }
                    }
                }
                
                codeLines.append("    default:")
                codeLines.append("        return luaError(L, \"Cannot set property \\(key)\")")
                codeLines.append("    }")
                codeLines.append("    return 0")
                codeLines.append("}, 0)")
                codeLines.append("lua_settable(L, -3)")
                codeLines.append("")
            }
        }
        
        // Generate __tostring method
        codeLines.append("// Register __tostring method")
        codeLines.append("lua_pushstring(L, \"__tostring\")")
        codeLines.append("lua_pushcclosure(L, { L in")
        codeLines.append("    guard let L = L else { return 0 }")
        codeLines.append("    guard let obj = \(className).checkUserdata(L, at: 1) else {")
        codeLines.append("        return luaError(L, \"Invalid \(className) object\")")
        codeLines.append("    }")
        codeLines.append("    lua_pushstring(L, obj.description)")
        codeLines.append("    return 1")
        codeLines.append("}, 0)")
        codeLines.append("lua_settable(L, -3)")
        
        let bodyCode = codeLines.joined(separator: "\n    ")
        
        return DeclSyntax(stringLiteral: """
public static func registerMethods(_ L: OpaquePointer) {
    \(bodyCode)
}
""")
    }
}

/// Additional macro implementations
public struct LuaIgnoreMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This is a marker macro - it doesn't generate code, just marks the member to be ignored
        return []
    }
}

public struct LuaOnlyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This is a marker macro - it doesn't generate code, just marks the member to be included
        return []
    }
}

public struct LuaMethodMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This will be used for fine-grained method control
        return []
    }
}

public struct LuaPropertyMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Extract property configuration
        guard case .argumentList(let arguments) = node.arguments else {
            return []
        }
        
        var isReadOnly = false
        var validatorName: String?
        var minValue: Double?
        var maxValue: Double?
        var regexPattern: String?
        var enumValues: [String] = []
        
        for argument in arguments {
            if let label = argument.label?.text {
                switch label {
                case "readOnly":
                    if let boolExpr = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        isReadOnly = boolExpr.literal.text == "true"
                    }
                case "validator":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let validator = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                        validatorName = validator
                    }
                case "min":
                    if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        minValue = Double(intLiteral.literal.text) ?? 0
                    } else if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        minValue = Double(floatLiteral.literal.text) ?? 0
                    }
                case "max":
                    if let intLiteral = argument.expression.as(IntegerLiteralExprSyntax.self) {
                        maxValue = Double(intLiteral.literal.text) ?? 0
                    } else if let floatLiteral = argument.expression.as(FloatLiteralExprSyntax.self) {
                        maxValue = Double(floatLiteral.literal.text) ?? 0
                    }
                case "regex":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let pattern = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                        regexPattern = pattern
                    }
                case "enumValues":
                    if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
                        for element in arrayExpr.elements {
                            if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
                               let value = stringLiteral.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                                enumValues.append(value)
                            }
                        }
                    }
                default:
                    break
                }
            }
        }
        
        // Get property declaration
        guard let property = declaration.as(VariableDeclSyntax.self),
              let binding = property.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else {
            return []
        }
        
        let propertyName = identifier.identifier.text
        var generatedCode: [DeclSyntax] = []
        
        // Generate validator method if custom validator is specified
        if let validatorName = validatorName {
            let validatorMethod = """
            public func \(validatorName)(_ value: Any) -> Bool {
                // Custom validation logic would be implemented here
                return true
            }
            """
            generatedCode.append(DeclSyntax(stringLiteral: validatorMethod))
        }
        
        // Generate property metadata storage
        let metadataProperty = """
        @available(*, deprecated, message: "Property validation metadata")
        static let __luaProperty_\(propertyName) = (
            readOnly: \(isReadOnly),
            validator: "\(validatorName ?? "")",
            min: \(minValue?.description ?? "nil"),
            max: \(maxValue?.description ?? "nil"),
            regex: "\(regexPattern ?? "")",
            enumValues: [\(enumValues.map { "\"\($0)\"" }.joined(separator: ", "))]
        )
        """
        generatedCode.append(DeclSyntax(stringLiteral: metadataProperty))
        
        return generatedCode
    }
}

public struct LuaConstructorMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // This will be used for constructor parameter specification
        return []
    }
}

/// Macro expansion errors
enum MacroError: Error, CustomStringConvertible {
    case onlyApplicableToClasses
    
    var description: String {
        switch self {
            case .onlyApplicableToClasses:
                return "@LuaBridgeable can only be applied to classes"
        }
    }
}

@main
struct LuaMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LuaBridgeableMacro.self,
        EnhancedLuaBridgeableMacro.self,
        LuaIgnoreMacro.self,
        LuaOnlyMacro.self,
        LuaMethodMacro.self,
        LuaPropertyMacro.self,
        LuaConstructorMacro.self,
        LuaCollectionMacro.self,
        LuaAliasMacro.self,
        LuaFactoryMacro.self,
        LuaAsyncMacro.self,
        LuaDocMacro.self,
        LuaParamMacro.self,
        LuaChainableMacro.self,
        LuaConvertMacro.self,
        LuaNamespaceMacro.self,
        LuaRelationshipMacro.self,
    ]
}
