//
//  UsageExample.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//  General usage examples of LuaKit framework
//

import Foundation
import LuaKit

public func demonstrateLuaKit() throws {
    print("=== LuaKit Usage Examples ===\n")
    
    // Create a Lua state
    let lua = try LuaState()
    
    // Set up print handler to capture Lua output
    lua.setPrintHandler { output in
        print("Lua: \(output)", terminator: "")
    }
    
    // Example 1: Basic Lua execution
    print("1. Basic Execution:")
    _ = try lua.execute("""
        print("Hello from Lua!")
        print("Lua version:", _VERSION)
    """)
    
    // Example 2: Getting values back from Lua
    print("\n2. Return Values:")
    let sum = try lua.executeReturning("return 10 + 32", as: Int.self)
    print("Swift: 10 + 32 = \(sum)")
    
    let greeting = try lua.executeReturning("return 'Hello, ' .. 'Swift!'", as: String.self)
    print("Swift: Concatenation result: \(greeting)")
    
    // Example 3: Working with globals
    print("\n3. Global Variables:")
    lua.globals["appName"] = "LuaKit Demo"
    lua.globals["version"] = 1.0
    lua.globals["isDebug"] = true
    
    _ = try lua.execute("""
        print("App Name:", appName)
        print("Version:", version)
        print("Debug Mode:", isDebug)
        
        -- Modify globals from Lua
        appName = appName .. " (Modified)"
        version = version + 0.1
    """)
    
    // Read modified globals back in Swift
    if let modifiedName = lua.globals["appName"] as? String {
        print("Swift: Modified app name: \(modifiedName)")
    }
    if let modifiedVersion = lua.globals["version"] as? Double {
        print("Swift: Modified version: \(modifiedVersion)")
    }
    
    // Example 4: Working with tables
    print("\n4. Lua Tables:")
    let config = lua.createTable()
    config["host"] = "localhost"
    config["port"] = 8080
    config["secure"] = true
    
    // Array-like elements
    config[1] = "first"
    config[2] = "second"
    config[3] = "third"
    
    lua.globals.set("config", to: config)
    
    _ = try lua.execute("""
        print("Configuration:")
        print("  Host:", config.host)
        print("  Port:", config.port)
        print("  Secure:", config.secure)
        
        print("Array elements:")
        for i = 1, 3 do
            print("  [" .. i .. "]:", config[i])
        end
        
        -- Add new fields from Lua
        config.timeout = 30
        config.retries = 3
    """)
    
    // Example 5: Error handling
    print("\n5. Error Handling:")
    do {
        _ = try lua.execute("this is invalid lua syntax")
    } catch LuaError.syntax(let message) {
        print("Swift: Caught syntax error: \(message)")
    }
    
    do {
        _ = try lua.execute("error('This is a runtime error')")
    } catch LuaError.runtime(let message) {
        print("Swift: Caught runtime error: \(message)")
    }
    
    // Example 6: Functions and closures
    print("\n6. Lua Functions:")
    _ = try lua.execute("""
        -- Define a function
        function multiply(a, b)
            return a * b
        end
        
        -- Store it globally
        multiplyFunc = multiply
    """)
    
    // Call the function from Swift
    let product = try lua.executeReturning("""
        return multiplyFunc(7, 6)
    """, as: Int.self)
    print("Swift: 7 × 6 = \(product)")
    
    print("\n=== Examples Complete ===")
}

// Standalone function example for bridged classes
public func demonstrateBridging() throws {
    print("\n=== Class Bridging Example ===")
    print("See Image.swift, MacroExample.swift, and ManualBridgingExample.swift")
    print("for examples of bridging Swift classes to Lua.")
}