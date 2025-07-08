//
//  UsageExample.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//  Example of using LuaKit framework
//

import Foundation

func demonstrateLuaKit() throws {
    // Create a Lua state
    let lua = try LuaState()
    
    // Set up print handler to capture Lua output
    lua.setPrintHandler { output in
        print("Lua: \(output)", terminator: "")
    }
    
    // Register an Image class with Lua
    lua.register(Image.self, as: "Image")
    
    // Execute some Lua code
    let luaCode = """
    -- Create a new image
    local img = Image.new(1920, 1080)
    print("Created image:", img)
    print("Image size:", img.width, "x", img.height)
    print("Image area:", img.area)
    
    -- Resize the image
    img:resize(800, 600)
    print("After resize:", img)
    print("New area:", img.area)
    
    -- Modify properties directly
    img.width = 1024
    img.height = 768
    print("After property modification:", img)
    """
    
    _ = try lua.execute(luaCode)
    
    // Example of getting a value back from Lua
    let result = try lua.executeReturning("return 2 + 2", as: Int.self)
    print("Swift: 2 + 2 =", result)
    
    // Example with globals
    lua.globals["myNumber"] = 42
    lua.globals["myString"] = "Hello from Swift!"
    
    _ = try lua.execute("""
    print("myNumber =", myNumber)
    print("myString =", myString)
    """)
    
    // Example with tables
    let table = lua.createTable()
    table["name"] = "John"
    table["age"] = 30
    table[1] = "first"
    table[2] = "second"
    
    lua.globals.set("person", to: table)
    
    _ = try lua.execute("""
    print("Person name:", person.name)
    print("Person age:", person.age)
    print("Array element 1:", person[1])
    print("Array element 2:", person[2])
    """)
}