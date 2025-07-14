//
//  QuickStartExample.swift
//  LuaKit Examples
//
//  A simple example to get started with LuaKit
//

import Foundation
import LuaKit

public func runQuickStartExample() throws {
    // Create a Lua state
    let lua = try LuaState()
    
    // Execute Lua code
    let result = try lua.execute("""
        print("Hello from Lua!")
        return 1 + 2
    """)
    
    print("Lua output: \(result)")
    
    // Set and get global variables
    lua.globals["myNumber"] = 42
    lua.globals["myString"] = "Hello, Swift!"
    
    let number: Int? = lua.globals["myNumber"]
    let string: String? = lua.globals["myString"]
    
    print("Number from Lua: \(number ?? 0)")
    print("String from Lua: \(string ?? "")")
}

// Run the example:
// try runQuickStartExample()