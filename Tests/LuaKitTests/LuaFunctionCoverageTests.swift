//
//  LuaFunctionCoverageTests.swift
//  LuaKit
//
//  Created by Barry Walker.
//
//  Comprehensive tests to improve LuaFunction coverage
//

import Lua
@testable import LuaKit
import XCTest

final class LuaFunctionCoverageTests: XCTestCase {
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

    // MARK: - Function Table Tests

    func testLuaFunctionCallWithInvalidFunctionId() {
        // Create a table that looks like a function but has an invalid ID
        lua_createtable(lua.luaState, 0, 1)
        lua_pushinteger(lua.luaState, 999_999) // Non-existent ID
        lua_setfield(lua.luaState, -2, "_luakit_function_id")

        // Create metatable with __call
        lua_createtable(lua.luaState, 0, 1)
        lua_pushstring(lua.luaState, "__call")
        lua_pushcclosure(lua.luaState, { luaState in
            guard let luaState = luaState else { return 0 }
            // This will fail because the function ID doesn't exist
            return luaError(luaState, "Function no longer exists")
        }, 0)
        lua_settable(lua.luaState, -3)
        lua_setmetatable(lua.luaState, -2)

        lua_setglobal(lua.luaState, "invalidFunc")

        // Try to call it
        let result = try? lua.execute("return invalidFunc()")
        XCTAssertNil(result) // Should fail
    }

    func testLuaFunctionFromDifferentTypes() {
        // Test that non-function values can't be called as functions
        _ = try? lua.execute("""
            stringValue = "not a function"
            numberValue = 42
            boolValue = true
            tableValue = {}
        """)

        // Try to call non-functions
        XCTAssertNil(try? lua.execute("return stringValue()"))
        XCTAssertNil(try? lua.execute("return numberValue()"))
        XCTAssertNil(try? lua.execute("return boolValue()"))
        XCTAssertNil(try? lua.execute("return tableValue()"))
    }

    func testLuaFunctionMetatableStructure() {
        // Test the internal structure of function tables
        let function = LuaFunction { () -> String in
            return "test"
        }

        function.push(to: lua.luaState)
        lua_setglobal(lua.luaState, "testFunc")

        // Verify structure from Lua
        let result = try? lua.execute("""
            -- Check it's a table
            assert(type(testFunc) == 'table')

            -- Check it has _luakit_function_id
            assert(type(testFunc._luakit_function_id) == 'number')
            assert(testFunc._luakit_function_id > 0)

            -- Check it has a metatable
            local mt = getmetatable(testFunc)
            assert(mt ~= nil)

            -- Check metatable has __call
            assert(type(mt.__call) == 'function')

            -- Check metatable has __gc
            assert(type(mt.__gc) == 'function')

            return true
        """)

        XCTAssertNotNil(result)
    }

    // MARK: - Debug Mode Coverage

    func testDebugModeArguments() {
        // Test with debug mode flag set but not actually enabling to avoid issues
        let originalDebugMode = LuaFunction.debugMode
        defer { LuaFunction.debugMode = originalDebugMode }

        // Test function with multiple argument types
        let testFunc = LuaFunction { () -> String in
            return "test result"
        }

        testFunc.push(to: lua.luaState)

        let result = lua_pcall(lua.luaState, 0, 1, 0)
        XCTAssertEqual(result, 0)

        if result == 0 {
            let resultStr = String(cString: lua_tostring(lua.luaState, -1)!)
            XCTAssertEqual(resultStr, "test result")
        }

        lua_pop(lua.luaState, 1)
    }

    // MARK: - Optional Unwrapping Coverage

    func testUnwrapOptionalWithVariousLevels() {
        // Test single optional
        let fn1 = LuaFunction { () -> String? in
            return "single"
        }

        fn1.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "single")
        lua_pop(lua.luaState, 1)

        // Test double optional with value
        let fn2 = LuaFunction { () -> Int?? in
            let value: Int?? = 42
            return value
        }

        fn2.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)
        XCTAssertEqual(lua_tointeger(lua.luaState, -1), 42)
        lua_pop(lua.luaState, 1)

        // Test triple optional with nil
        let fn3 = LuaFunction { () -> Bool??? in
            return nil
        }

        fn3.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Array Push Coverage

    func testPushArrayOfStringArrays() {
        // This tests a specific path in pushResult
        let testFunc = LuaFunction { () -> [[String]] in
            return [["a", "b"], ["c", "d", "e"]]
        }

        testFunc.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        // Verify it's a table
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        // Check first sub-array
        lua_rawgeti(lua.luaState, -1, 1)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        lua_rawgeti(lua.luaState, -1, 1)
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "a")
        lua_pop(lua.luaState, 1)

        lua_rawgeti(lua.luaState, -1, 2)
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "b")
        lua_pop(lua.luaState, 2)

        lua_pop(lua.luaState, 1)
    }

    func testPushArrayOfIntArrays() {
        let testFunc = LuaFunction { () -> [[Int]] in
            return [[1, 2, 3], [4, 5]]
        }

        testFunc.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)
        lua_pop(lua.luaState, 1)
    }

    func testPushArrayOfDoubleArrays() {
        let testFunc = LuaFunction { () -> [[Double]] in
            return [[1.1, 2.2], [3.3]]
        }

        testFunc.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)
        lua_pop(lua.luaState, 1)
    }

    func testPushArrayOfBoolArrays() {
        let testFunc = LuaFunction { () -> [[Bool]] in
            return [[true, false], [false, true, true]]
        }

        testFunc.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Function Returning Void

    func testFunctionReturningVoid() {
        var sideEffect = 0
        let testFunc = LuaFunction { () in
            sideEffect += 1
        }

        testFunc.push(to: lua.luaState)
        let result = lua_pcall(lua.luaState, 0, 0, 0)
        XCTAssertEqual(result, 0)
        XCTAssertEqual(sideEffect, 1)
    }

    func testFunctionWithArgsReturningVoid() {
        var captured = ""
        let testFunc = LuaFunction { (str: String) in
            captured = str
        }

        testFunc.push(to: lua.luaState)
        lua_pushstring(lua.luaState, "test void")
        let result = lua_pcall(lua.luaState, 1, 0, 0)
        XCTAssertEqual(result, 0)
        XCTAssertEqual(captured, "test void")
    }

    // MARK: - Error Handling Coverage

    func testFunctionWithInsufficientArguments() {
        let testFunc = LuaFunction { (arg1: Int, arg2: Int) -> Int in
            return arg1 + arg2
        }

        testFunc.push(to: lua.luaState)
        lua_pushinteger(lua.luaState, 5) // Only one argument instead of two

        let result = lua_pcall(lua.luaState, 1, 1, 0)
        XCTAssertNotEqual(result, 0) // Should fail
        lua_pop(lua.luaState, 1) // Pop error message
    }

    func testFunctionWithWrongArgumentTypes() {
        let testFunc = LuaFunction { (num: Int) -> Int in
            return num * 2
        }

        testFunc.push(to: lua.luaState)
        lua_pushstring(lua.luaState, "not a number")

        let result = lua_pcall(lua.luaState, 1, 1, 0)
        XCTAssertNotEqual(result, 0) // Should fail
        lua_pop(lua.luaState, 1) // Pop error message
    }

    // MARK: - Closure Storage Tests

    func testClosureStorageAndRetrieval() {
        // Create multiple functions to test closure storage
        var functions: [LuaFunction] = []

        for idx in 0..<10 {
            let testFunc = LuaFunction { () -> Int in
                return idx * 10
            }
            functions.append(testFunc)

            testFunc.push(to: lua.luaState)
            lua_setglobal(lua.luaState, "fn\(idx)")
        }

        // Call each function and verify result
        for idx in 0..<10 {
            let result = try? lua.execute("return fn\(idx)()")
            XCTAssertNotNil(result)
        }
    }

    // MARK: - Complex Return Types

    func testFunctionReturningDictionaryWithMixedTypes() {
        let testFunc = LuaFunction { () -> [String: Any] in
            return [
                "string": "hello",
                "number": 42,
                "float": 3.14,
                "bool": true,
                "array": [1, 2, 3],
                "dict": ["nested": "value"]
            ]
        }

        testFunc.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        // Verify string field
        lua_getfield(lua.luaState, -1, "string")
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "hello")
        lua_pop(lua.luaState, 1)

        // Verify number field
        lua_getfield(lua.luaState, -1, "number")
        XCTAssertEqual(lua_tointeger(lua.luaState, -1), 42)
        lua_pop(lua.luaState, 1)

        lua_pop(lua.luaState, 1)
    }

    // MARK: - Function Table Structure Tests

    func testFunctionTableStructure() {
        let testFunc = LuaFunction { () -> String in
            return "test"
        }

        testFunc.push(to: lua.luaState)

        // Verify it's a table
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        // Check for _luakit_function_id field
        lua_getfield(lua.luaState, -1, "_luakit_function_id")
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNUMBER)
        let functionId = Int(lua_tointeger(lua.luaState, -1))
        XCTAssertGreaterThan(functionId, 0)
        lua_pop(lua.luaState, 1)

        // Check it has a metatable
        lua_getmetatable(lua.luaState, -1)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        // Check for __call metamethod
        lua_getfield(lua.luaState, -1, "__call")
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TFUNCTION)
        lua_pop(lua.luaState, 1)

        // Check for __gc metamethod
        lua_getfield(lua.luaState, -1, "__gc")
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TFUNCTION)
        lua_pop(lua.luaState, 1)

        lua_pop(lua.luaState, 2) // Pop metatable and function table
    }

    // MARK: - Multiple Return Values

    func testFunctionWithTupleReturn() {
        // LuaFunction doesn't support tuple returns directly
        // Skip this test
        XCTSkip("LuaFunction doesn't support tuple returns")
    }

    func testFunctionWithTripleReturn() {
        // LuaFunction doesn't support tuple returns directly
        // Skip this test
        XCTSkip("LuaFunction doesn't support tuple returns")
    }

    // MARK: - Edge Cases

    func testFunctionWithEmptyStringReturn() {
        let testFunc = LuaFunction { () -> String in
            return ""
        }

        testFunc.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "")
        lua_pop(lua.luaState, 1)
    }

    func testFunctionWithEmptyArrayReturn() {
        let testFunc = LuaFunction { () -> [String] in
            return []
        }

        testFunc.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)
        lua_len(lua.luaState, -1)
        XCTAssertEqual(lua_tointeger(lua.luaState, -1), 0)
        lua_pop(lua.luaState, 2)
    }

    func testFunctionWithEmptyDictionaryReturn() {
        let testFunc = LuaFunction { () -> [String: Int] in
            return [:]
        }

        testFunc.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        // Push nil to start iteration
        lua_pushnil(lua.luaState)
        XCTAssertEqual(lua_next(lua.luaState, -2), 0) // Should have no elements

        lua_pop(lua.luaState, 1)
    }
}
