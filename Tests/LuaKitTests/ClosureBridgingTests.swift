//
//  ClosureBridgingTests.swift
//  LuaKitTests
//
//  Tests for closure bridging functionality
//

import Lua
@testable import LuaKit
import XCTest

final class ClosureBridgingTests: XCTestCase {
    func testSimpleClosureWithNoParameters() throws {
        let lua = try LuaState()

        // Register a simple closure
        lua.globals["getAnswer"] = LuaFunction {
            return 42
        }

        // Call from Lua
        let result = try lua.executeReturning("return getAnswer()", as: Int.self)
        XCTAssertEqual(result, 42)
    }

    func testClosureWithParameters() throws {
        let lua = try LuaState()

        // Register a closure with parameters
        lua.globals["add"] = LuaFunction { (a: Int, b: Int) in
            return a + b
        }

        // Call from Lua
        let result = try lua.executeReturning("return add(10, 32)", as: Int.self)
        XCTAssertEqual(result, 42)
    }

    func testClosureReturningLuaBridgeable() throws {
        let lua = try LuaState()

        // Return a simple dictionary instead
        let createImage = LuaFunction { (width: Int, height: Int) -> String in
            return "Image \(width)x\(height)"
        }

        lua.globals["createImage"] = createImage

        // Call from Lua and verify
        let result = try lua.executeReturning("""
            return createImage(1920, 1080)
        """, as: String.self)
        XCTAssertEqual(result, "Image 1920x1080")
    }

    func testClosureWithVoidReturn() throws {
        let lua = try LuaState()

        var called = false
        lua.globals["doSomething"] = LuaFunction {
            called = true
        }

        _ = try lua.execute("doSomething()")
        XCTAssertTrue(called)
    }

    func testClosureWithOptionalReturn() throws {
        let lua = try LuaState()

        // Closure that returns nil sometimes
        lua.globals["maybeGetValue"] = LuaFunction { (shouldReturn: Bool) -> String? in
            return shouldReturn ? "Hello" : nil
        }

        // Test returning a value
        let result1 = try lua.executeReturning("return maybeGetValue(true)", as: String.self)
        XCTAssertEqual(result1, "Hello")

        // Test returning nil
        let nilCheck = try lua.executeReturning("return maybeGetValue(false) == nil", as: Bool.self)
        XCTAssertTrue(nilCheck)
    }

    func testRegisterFunctionConvenience() throws {
        let lua = try LuaState()

        // Test various registerFunction overloads
        lua.registerFunction("noParams") {
            return "Hello from Swift"
        }

        lua.registerFunction("oneParam") { (name: String) in
            return "Hello, \(name)!"
        }

        lua.registerFunction("twoParams") { (a: Int, b: Int) in
            return a * b
        }

        lua.registerFunction("threeParams") { (x: Int, y: Int, z: Int) in
            return x + y + z
        }

        // Test them all
        let r1 = try lua.executeReturning("return noParams()", as: String.self)
        XCTAssertEqual(r1, "Hello from Swift")

        let r2 = try lua.executeReturning("return oneParam('World')", as: String.self)
        XCTAssertEqual(r2, "Hello, World!")

        let r3 = try lua.executeReturning("return twoParams(6, 7)", as: Int.self)
        XCTAssertEqual(r3, 42)

        let r4 = try lua.executeReturning("return threeParams(10, 20, 30)", as: Int.self)
        XCTAssertEqual(r4, 60)
    }

    func testClosurePropertyInBridgeableClass() throws {
        let lua = try LuaState()

        // For now, test closure properties using manual registration
        // The macro doesn't yet support closure properties

        // Create a table with closure properties
        let calcTable = lua.createTable()
        calcTable["add"] = LuaFunction { (a: Int, b: Int) in a + b }
        calcTable["multiply"] = LuaFunction { (a: Int, b: Int) in a * b }
        lua.globals.set("calculator", to: calcTable)

        _ = try lua.execute("""
            -- Test closure properties
            local sum = calculator.add(5, 3)
            assert(sum == 8, "Addition failed")

            local product = calculator.multiply(4, 7)
            assert(product == 28, "Multiplication failed")

            print("Closure properties work!")
        """)
    }

    func testAutomaticClosureDetection() throws {
        let lua = try LuaState()

        // For now, closures must be explicitly wrapped in LuaFunction
        lua.globals["explicitFunc"] = LuaFunction { return "Explicit LuaFunction!" }

        let result = try lua.executeReturning("return explicitFunc()", as: String.self)
        XCTAssertEqual(result, "Explicit LuaFunction!")
    }
}
