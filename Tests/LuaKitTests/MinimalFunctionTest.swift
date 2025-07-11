//
//  MinimalFunctionTest.swift
//  LuaKitTests
//

import XCTest
@testable import LuaKit

final class MinimalFunctionTest: XCTestCase {
    
    func testMinimal() throws {
        print("Creating LuaState...")
        let lua = try LuaState()
        print("LuaState created")
        
        print("Creating LuaFunction...")
        let fn = LuaFunction {
            print("Inside closure")
            return 42
        }
        print("LuaFunction created")
        
        print("Setting global...")
        lua.globals["test"] = fn
        print("Global set")
        
        print("Executing Lua code...")
        let result = try lua.executeReturning("return test()", as: Int.self)
        print("Result: \(result)")
        
        XCTAssertEqual(result, 42)
    }
}