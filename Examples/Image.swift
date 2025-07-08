//
//  Image.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//  Example of using LuaBridgeable macro
//

import Foundation
import CLua  // Required for @LuaBridgeable macro
import LuaKit

// Example using the @LuaBridgeable macro
// Note: Must explicitly conform to LuaBridgeable due to current macro limitations
@LuaBridgeable
public class Image: LuaBridgeable, CustomStringConvertible {
    public var width: Int
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    public var area: Int {
        return width * height
    }
    
    public func resize(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    public var description: String {
        return "Image(\(width)x\(height))"
    }
}

// MARK: - Usage Example

public func demonstrateImageUsage() throws {
    // Create a Lua state
    let lua = try LuaState()
    
    // Register the Image class
    lua.register(Image.self, as: "Image")
    
    // Set up print handler to see Lua output
    lua.setPrintHandler { print("Lua: \($0)", terminator: "") }
    
    print("=== Image Class Example ===")
    
    // Use the Image class from Lua
    _ = try lua.execute("""
        -- Create an image
        local img = Image.new(1920, 1080)
        print("Created:", img)
        print("Width:", img.width)
        print("Height:", img.height)
        print("Area:", img.area)
        
        -- Resize the image
        img:resize(800, 600)
        print("\\nAfter resize:", img)
        print("New area:", img.area)
        
        -- Modify properties directly
        img.width = 1024
        img.height = 768
        print("\\nAfter property modification:", img)
    """)
}