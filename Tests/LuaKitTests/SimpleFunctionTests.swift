//
//  SimpleFunctionTests.swift
//  LuaKitTests
//
//  Simple tests for LuaFunction basic functionality
//

@testable import LuaKit
import XCTest

final class SimpleFunctionTests: XCTestCase {
    func testBasicLuaFunctionCreation() throws {
        let lua = try LuaState()

        // Create a simple function
        let fn = LuaFunction {
            return 42
        }

        // Push it to Lua
        lua.globals["testFunc"] = fn

        // Call it from Lua
        let result = try lua.executeReturning("return testFunc()", as: Int.self)
        XCTAssertEqual(result, 42)
    }

    func testLuaFunctionWithStringReturn() throws {
        let lua = try LuaState()

        let fn = LuaFunction {
            return "Hello from Swift"
        }

        lua.globals["getMessage"] = fn

        let result = try lua.executeReturning("return getMessage()", as: String.self)
        XCTAssertEqual(result, "Hello from Swift")
    }

    func testLuaFunctionWithParameters() throws {
        let lua = try LuaState()

        let fn = LuaFunction { (a: Int, b: Int) in
            return a + b
        }

        lua.globals["add"] = fn

        let result = try lua.executeReturning("return add(10, 5)", as: Int.self)
        XCTAssertEqual(result, 15)
    }
}
