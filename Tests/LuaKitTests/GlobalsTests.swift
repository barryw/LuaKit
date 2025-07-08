//
//  GlobalsTests.swift
//  LuaKitTests
//
//  Created by Barry Walker on 7/8/25.
//

import XCTest
@testable import LuaKit

final class GlobalsTests: XCTestCase {
    
    func testSetAndGetGlobals() throws {
        let lua = try LuaState()
        
        // Set various types
        var globals = lua.globals
        globals["myString"] = "Hello"
        globals["myNumber"] = 42
        globals["myDouble"] = 3.14
        globals["myBool"] = true
        
        // Verify from Lua
        let stringResult = try lua.executeReturning("return myString", as: String.self)
        XCTAssertEqual(stringResult, "Hello")
        
        let intResult = try lua.executeReturning("return myNumber", as: Int.self)
        XCTAssertEqual(intResult, 42)
        
        let doubleResult = try lua.executeReturning("return myDouble", as: Double.self)
        XCTAssertEqual(doubleResult, 3.14, accuracy: 0.001)
        
        let boolResult = try lua.executeReturning("return myBool", as: Bool.self)
        XCTAssertEqual(boolResult, true)
    }
    
    func testGetGlobalsFromSwift() throws {
        let lua = try LuaState()
        
        // Set from Lua
        _ = try lua.execute("""
            myString = "World"
            myNumber = 99
            myBool = false
        """)
        
        // Get from Swift
        if let str = lua.globals["myString"] as? String {
            XCTAssertEqual(str, "World")
        } else {
            XCTFail("Failed to get string global")
        }
        
        if let num = lua.globals["myNumber"] as? Int {
            XCTAssertEqual(num, 99)
        } else {
            XCTFail("Failed to get number global")
        }
        
        if let bool = lua.globals["myBool"] as? Bool {
            XCTAssertEqual(bool, false)
        } else {
            XCTFail("Failed to get boolean global")
        }
    }
    
    func testNilGlobal() throws {
        let lua = try LuaState()
        
        // Set nil
        var globals = lua.globals
        globals["toBeNil"] = nil
        
        // Verify it's nil in Lua
        let isNil = try lua.executeReturning("return toBeNil == nil", as: Bool.self)
        XCTAssertTrue(isNil)
        
        // Get nil from Swift
        let value = lua.globals["toBeNil"]
        XCTAssertNil(value)
    }
}