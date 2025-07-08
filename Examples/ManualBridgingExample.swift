//
//  ManualBridgingExample.swift
//  LuaKit
//
//  Example showing manual implementation of LuaBridgeable protocol
//  This demonstrates what the @LuaBridgeable macro generates for you
//

import Foundation
import CLua
import LuaKit

// Example of manually implementing LuaBridgeable without using the macro
// This shows what the macro generates automatically
public class Rectangle: LuaBridgeable, CustomStringConvertible {
    public var width: Double
    public var height: Double
    
    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
    
    public var area: Double {
        return width * height
    }
    
    public var perimeter: Double {
        return 2 * (width + height)
    }
    
    public func scale(by factor: Double) {
        width *= factor
        height *= factor
    }
    
    public var description: String {
        return "Rectangle(\(width)x\(height))"
    }
    
    // MARK: - LuaBridgeable Protocol Implementation (Manual)
    
    public static func luaNew(_ L: OpaquePointer) -> Int32 {
        // Extract parameters
        let width = lua_tonumberx(L, 1, nil)
        let height = lua_tonumberx(L, 2, nil)
        
        // Create instance
        let instance = Rectangle(width: width, height: height)
        
        // Push to Lua
        push(instance, to: L)
        
        return 1
    }
    
    public static func registerConstructor(_ L: OpaquePointer, name: String) {
        lua_createtable(L, 0, 1)
        
        lua_pushstring(L, "new")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            return Rectangle.luaNew(L)
        }, 0)
        lua_settable(L, -3)
        
        lua_setglobal(L, name)
    }
    
    public static func registerMethods(_ L: OpaquePointer) {
        // Register methods
        registerLuaMethods(L, methods: [
            LuaMethod(name: "scale", function: { L in
                guard let L = L else { return 0 }
                guard let obj = Rectangle.checkUserdata(L, at: 1) else {
                    return luaError(L, "Invalid Rectangle object")
                }
                
                let factor = lua_tonumberx(L, 2, nil)
                obj.scale(by: factor)
                return 0
            })
        ])
        
        // Register __index for property access
        lua_pushstring(L, "__index")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = Rectangle.checkUserdata(L, at: 1) else { return 0 }
            guard let key = String.pull(from: L, at: 2) else { return 0 }
            
            switch key {
            case "width":
                Double.push(obj.width, to: L)
                return 1
            case "height":
                Double.push(obj.height, to: L)
                return 1
            case "area":
                Double.push(obj.area, to: L)
                return 1
            case "perimeter":
                Double.push(obj.perimeter, to: L)
                return 1
            default:
                // Check metatable for methods
                lua_getmetatable(L, 1)
                lua_pushstring(L, key)
                lua_rawget(L, -2)
                return 1
            }
        }, 0)
        lua_settable(L, -3)
        
        // Register __newindex for property setting
        lua_pushstring(L, "__newindex")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = Rectangle.checkUserdata(L, at: 1) else { return 0 }
            guard let key = String.pull(from: L, at: 2) else { return 0 }
            
            switch key {
            case "width":
                obj.width = lua_tonumberx(L, 3, nil)
            case "height":
                obj.height = lua_tonumberx(L, 3, nil)
            default:
                return luaError(L, "Cannot set property \(key)")
            }
            return 0
        }, 0)
        lua_settable(L, -3)
        
        // Register __tostring
        lua_pushstring(L, "__tostring")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = Rectangle.checkUserdata(L, at: 1) else { return 0 }
            String.push(obj.description, to: L)
            return 1
        }, 0)
        lua_settable(L, -3)
    }
}

// MARK: - Usage Example

public func demonstrateManualBridging() throws {
    let lua = try LuaState()
    
    // Register the manually implemented class
    lua.register(Rectangle.self, as: "Rectangle")
    
    // Set up print handler
    lua.setPrintHandler { print("Lua: \($0)", terminator: "") }
    
    print("=== Manual Implementation Example ===")
    _ = try lua.execute("""
        -- Create a rectangle
        local rect = Rectangle.new(10, 20)
        print("Rectangle:", rect)
        print("Width:", rect.width)
        print("Height:", rect.height)
        print("Area:", rect.area)
        print("Perimeter:", rect.perimeter)
        
        -- Modify properties
        rect.width = 15
        rect.height = 25
        print("\\nAfter modification:")
        print("New dimensions:", rect.width, "x", rect.height)
        print("New area:", rect.area)
        
        -- Call method
        rect:scale(2)
        print("\\nAfter scaling by 2:")
        print("Final dimensions:", rect)
        print("Final area:", rect.area)
    """)
}

// MARK: - Comparison

/*
 Manual Implementation vs @LuaBridgeable Macro:
 
 Manual Implementation (above):
 - Full control over implementation
 - More verbose (~100 lines of boilerplate)
 - Useful for complex bridging scenarios
 - No additional imports required beyond CLua
 
 @LuaBridgeable Macro:
 - Generates all the above code automatically
 - Much more concise
 - Requires: import CLua and explicit : LuaBridgeable
 - Supports @LuaIgnore and @LuaOnly attributes
 - Handles most common cases
 
 The macro saves significant boilerplate while providing the same functionality!
 */