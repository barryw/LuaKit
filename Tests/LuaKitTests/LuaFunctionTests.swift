//
//  LuaFunctionTests.swift
//  LuaKit
//
//  Tests for LuaFunction functionality
//

import Lua
@testable import LuaKit
import XCTest

final class LuaFunctionTests: XCTestCase {
    var lua: LuaState!

    override func setUp() {
        super.setUp()
        do {
            lua = try LuaState()
        } catch {
            XCTFail("Failed to create LuaState: \(error)")
        }
    }

    override func tearDown() {
        lua = nil
        super.tearDown()
    }

    // MARK: - Basic Function Tests

    func testNoParameterNoReturnFunction() {
        var wasCalled = false
        let function = LuaFunction { () in
            wasCalled = true
        }

        // Push and call
        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 0, 0)

        XCTAssertTrue(wasCalled)
    }

    func testSingleParameterFunction() {
        var receivedValue: String?
        let function = LuaFunction { (value: String) in
            receivedValue = value
        }

        function.push(to: lua.luaState)
        lua_pushstring(lua.luaState, "Hello")
        _ = lua_pcall(lua.luaState, 1, 0, 0)

        XCTAssertEqual(receivedValue, "Hello")
    }

    func testSingleReturnFunction() {
        let function = LuaFunction { () -> String in
            return "Result"
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        let result = String(cString: lua_tostring(lua.luaState, -1)!)
        XCTAssertEqual(result, "Result")
        lua_pop(lua.luaState, 1)
    }

    func testParameterAndReturnFunction() {
        let function = LuaFunction { (num: Int) -> Int in
            return num * 2
        }

        function.push(to: lua.luaState)
        lua_pushinteger(lua.luaState, 21)
        _ = lua_pcall(lua.luaState, 1, 1, 0)

        let result = lua_tointeger(lua.luaState, -1)
        XCTAssertEqual(result, 42)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Multiple Parameter Tests

    func testTwoParameterFunction() {
        let function = LuaFunction { (a: Int, b: Int) -> Int in
            return a + b
        }

        function.push(to: lua.luaState)
        lua_pushinteger(lua.luaState, 10)
        lua_pushinteger(lua.luaState, 32)
        _ = lua_pcall(lua.luaState, 2, 1, 0)

        let result = lua_tointeger(lua.luaState, -1)
        XCTAssertEqual(result, 42)
        lua_pop(lua.luaState, 1)
    }

    func testThreeParameterFunction() {
        let function = LuaFunction { (a: String, b: Int, c: Bool) -> String in
            return "\(a)-\(b)-\(c)"
        }

        function.push(to: lua.luaState)
        lua_pushstring(lua.luaState, "test")
        lua_pushinteger(lua.luaState, 123)
        lua_pushboolean(lua.luaState, 1)
        _ = lua_pcall(lua.luaState, 3, 1, 0)

        let result = String(cString: lua_tostring(lua.luaState, -1)!)
        XCTAssertEqual(result, "test-123-true")
        lua_pop(lua.luaState, 1)
    }

    func testFourParameterFunction() {
        // LuaFunction only supports up to 3 parameters
        XCTSkip("LuaFunction only supports up to 3 parameters")
    }

    func testFiveParameterFunction() {
        // LuaFunction only supports up to 3 parameters
        XCTSkip("LuaFunction only supports up to 3 parameters")
    }

    // MARK: - Different Type Tests

    func testDoubleParameters() {
        let function = LuaFunction { (a: Double, b: Double) -> Double in
            return a * b
        }

        function.push(to: lua.luaState)
        lua_pushnumber(lua.luaState, 3.5)
        lua_pushnumber(lua.luaState, 2.0)
        _ = lua_pcall(lua.luaState, 2, 1, 0)

        let result = lua_tonumber(lua.luaState, -1)
        XCTAssertEqual(result, 7.0, accuracy: 0.001)
        lua_pop(lua.luaState, 1)
    }

    func testBoolParameters() {
        let function = LuaFunction { (a: Bool, b: Bool) -> Bool in
            return a && b
        }

        function.push(to: lua.luaState)
        lua_pushboolean(lua.luaState, 1)
        lua_pushboolean(lua.luaState, 0)
        _ = lua_pcall(lua.luaState, 2, 1, 0)

        let result = lua_toboolean(lua.luaState, -1)
        XCTAssertEqual(result, 0)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Optional Parameter Tests

    func testOptionalParameters() {
        let function = LuaFunction { (name: String?) -> String in
            return name ?? "Anonymous"
        }

        // Test with value
        function.push(to: lua.luaState)
        lua_pushstring(lua.luaState, "John")
        _ = lua_pcall(lua.luaState, 1, 1, 0)

        var result = String(cString: lua_tostring(lua.luaState, -1)!)
        XCTAssertEqual(result, "John")
        lua_pop(lua.luaState, 1)

        // Test with nil
        function.push(to: lua.luaState)
        lua_pushnil(lua.luaState)
        _ = lua_pcall(lua.luaState, 1, 1, 0)

        result = String(cString: lua_tostring(lua.luaState, -1)!)
        XCTAssertEqual(result, "Anonymous")
        lua_pop(lua.luaState, 1)
    }

    func testOptionalReturn() {
        let function = LuaFunction { (shouldReturn: Bool) -> String? in
            return shouldReturn ? "Value" : nil
        }

        // Test returning value
        function.push(to: lua.luaState)
        lua_pushboolean(lua.luaState, 1)
        _ = lua_pcall(lua.luaState, 1, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TSTRING)
        lua_pop(lua.luaState, 1)

        // Test returning nil
        function.push(to: lua.luaState)
        lua_pushboolean(lua.luaState, 0)
        _ = lua_pcall(lua.luaState, 1, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Error Handling Tests

    func testInsufficientParameters() {
        let function = LuaFunction { (a: String, b: String) -> String in
            return a + b
        }

        function.push(to: lua.luaState)
        lua_pushstring(lua.luaState, "only one")
        // Calling with only 1 parameter when 2 are required
        let result = lua_pcall(lua.luaState, 1, 1, 0)

        XCTAssertNotEqual(result, 0) // Should have error
        lua_pop(lua.luaState, 1) // Pop error message
    }

    func testWrongParameterType() {
        let function = LuaFunction { (num: Int) -> Int in
            return num * 2
        }

        function.push(to: lua.luaState)
        lua_pushstring(lua.luaState, "not a number")
        let result = lua_pcall(lua.luaState, 1, 1, 0)

        XCTAssertNotEqual(result, 0) // Should have error
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Lua Integration Tests

    func testRegisterFunction() {
        lua.registerFunction("multiply") { (a: Double, b: Double) -> Double in
            return a * b
        }

        _ = try? lua.execute("result = multiply(3, 7)")
        XCTAssertEqual(lua.globals["result"] as? Double, 21.0)
    }

    func testRegisterMultipleFunctions() {
        lua.registerFunction("add") { (a: Int, b: Int) -> Int in
            return a + b
        }

        lua.registerFunction("concat") { (a: String, b: String) -> String in
            return a + b
        }

        lua.registerFunction("isPositive") { (num: Double) -> Bool in
            return num > 0
        }

        _ = try? lua.execute("""
            sum = add(10, 20)
            text = concat("Hello", " World")
            positive = isPositive(-5)
        """)

        XCTAssertEqual(lua.globals["sum"] as? Int, 30)
        XCTAssertEqual(lua.globals["text"] as? String, "Hello World")
        XCTAssertEqual(lua.globals["positive"] as? Bool, false)
    }

    func testFunctionReturningMultipleValues() {
        // Note: LuaFunction currently only supports single return values
        // This test verifies that behavior
        let function = LuaFunction { () -> String in
            return "single value"
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, LUA_MULTRET, 0)

        let returnCount = lua_gettop(lua.luaState)
        XCTAssertEqual(returnCount, 1) // Only one return value
        lua_pop(lua.luaState, returnCount)
    }

    // MARK: - Closure Capture Tests

    func testClosureCapture() {
        var counter = 0
        // Remove unused variable warning

        lua.registerFunction("incrementCounter") { () -> Int in
            counter += 1
            return counter
        }

        _ = try? lua.execute("a = incrementCounter()")
        _ = try? lua.execute("b = incrementCounter()")
        _ = try? lua.execute("c = incrementCounter()")

        XCTAssertEqual(lua.globals["a"] as? Int, 1)
        XCTAssertEqual(lua.globals["b"] as? Int, 2)
        XCTAssertEqual(lua.globals["c"] as? Int, 3)
        XCTAssertEqual(counter, 3)
    }

    // MARK: - LuaConvertible Tests

    func testLuaConvertiblePush() {
        let function = LuaFunction { () -> String in
            return "test"
        }

        // Test that LuaFunction can be pushed
        function.push(to: lua.luaState)
        let pushedType = lua_type(lua.luaState, -1)
        // LuaFunction is pushed as a table with __call metamethod
        XCTAssertEqual(pushedType, LUA_TTABLE)
        
        // Verify it has the __call metamethod
        lua_getmetatable(lua.luaState, -1)
        XCTAssertNotEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        
        lua_getfield(lua.luaState, -1, "__call")
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TFUNCTION)
        
        lua_pop(lua.luaState, 3) // Pop __call, metatable, and function table
    }

    // MARK: - Performance Tests

    func testFunctionCallPerformance() {
        lua.registerFunction("square") { (n: Int) -> Int in
            return n * n
        }

        measure {
            _ = try? lua.execute("""
                local sum = 0
                for i = 1, 1000 do
                    sum = sum + square(i)
                end
            """)
        }
    }

    // MARK: - Complex Type Tests

    func testArrayParameter() {
        // Note: Arrays need special handling, skip for now
        XCTSkip("Array parameters need special handling")
    }

    func testDictionaryParameter() {
        // Note: Dictionary parameters need special handling, skip for now
        XCTSkip("Dictionary parameters need special handling")
    }

    // MARK: - Void Return Tests

    func testMultipleParametersVoidReturn() {
        var capturedValues: (String, Int, Bool)?
        let function = LuaFunction { (s: String, i: Int, b: Bool) in
            capturedValues = (s, i, b)
        }

        function.push(to: lua.luaState)
        lua_pushstring(lua.luaState, "test")
        lua_pushinteger(lua.luaState, 42)
        lua_pushboolean(lua.luaState, 1)
        _ = lua_pcall(lua.luaState, 3, 0, 0)

        XCTAssertNotNil(capturedValues)
        XCTAssertEqual(capturedValues?.0, "test")
        XCTAssertEqual(capturedValues?.1, 42)
        XCTAssertEqual(capturedValues?.2, true)
    }
}

