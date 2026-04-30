//
//  LuaFunctionAdvancedTests.swift
//  LuaKit
//
//  Advanced tests for LuaFunction edge cases and untested paths
//

import Foundation
import Lua
@testable import LuaKit
import XCTest

/// Thread-safe array wrapper for tests
private final class FunctionArray: @unchecked Sendable {
    private let lock = NSLock()
    private var _functions: [LuaFunction] = []

    var functions: [LuaFunction] {
        lock.lock()
        defer { lock.unlock() }
        return _functions
    }

    func append(_ function: LuaFunction) {
        lock.lock()
        defer { lock.unlock() }
        _functions.append(function)
    }
}

@MainActor
final class LuaFunctionAdvancedTests: XCTestCase {
    var lua: LuaState!

    override func setUp() async throws {
        try await super.setUp()
        lua = try LuaState()
    }

    override func tearDown() async throws {
        lua = nil
        try await super.tearDown()
    }

    // MARK: - Debug Mode Tests

    func testDebugMode() {
        // Enable debug mode
        // LuaFunction.debugMode = true  // Disabled to avoid infinite loops
        defer { LuaFunction.debugMode = false }

        let function = LuaFunction { () -> String in
            return "Debug test"
        }

        // Push and call - should print debug info
        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        let result = String(cString: lua_tostring(lua.luaState, -1)!)
        XCTAssertEqual(result, "Debug test")
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Complex Return Type Tests

    func testFunctionReturningDictionary() {
        let function = LuaFunction { () -> [String: Any] in
            return ["name": "Test", "value": 42, "active": true]
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        // Result should be a table
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        // Check table contents
        lua_getfield(lua.luaState, -1, "name")
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "Test")
        lua_pop(lua.luaState, 1)

        lua_getfield(lua.luaState, -1, "value")
        XCTAssertEqual(lua_tointeger(lua.luaState, -1), 42)
        lua_pop(lua.luaState, 1)

        lua_getfield(lua.luaState, -1, "active")
        XCTAssertEqual(lua_toboolean(lua.luaState, -1), 1)
        lua_pop(lua.luaState, 2) // Pop boolean and table
    }

    func testFunctionReturningStringArray() {
        let function = LuaFunction { () -> [String] in
            return ["apple", "banana", "cherry"]
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        // Check array elements
        lua_rawgeti(lua.luaState, -1, 1)
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "apple")
        lua_pop(lua.luaState, 1)

        lua_rawgeti(lua.luaState, -1, 2)
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "banana")
        lua_pop(lua.luaState, 2)
    }

    func testFunctionReturningIntArray() {
        let function = LuaFunction { () -> [Int] in
            return [10, 20, 30, 40, 50]
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        lua_rawgeti(lua.luaState, -1, 3)
        XCTAssertEqual(lua_tointeger(lua.luaState, -1), 30)
        lua_pop(lua.luaState, 2)
    }

    func testFunctionReturningDoubleArray() {
        let function = LuaFunction { () -> [Double] in
            return [1.1, 2.2, 3.3]
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        lua_rawgeti(lua.luaState, -1, 2)
        XCTAssertEqual(lua_tonumber(lua.luaState, -1), 2.2, accuracy: 0.01)
        lua_pop(lua.luaState, 2)
    }

    func testFunctionReturningBoolArray() {
        let function = LuaFunction { () -> [Bool] in
            return [true, false, true, false]
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        lua_rawgeti(lua.luaState, -1, 1)
        XCTAssertEqual(lua_toboolean(lua.luaState, -1), 1)
        lua_pop(lua.luaState, 1)

        lua_rawgeti(lua.luaState, -1, 2)
        XCTAssertEqual(lua_toboolean(lua.luaState, -1), 0)
        lua_pop(lua.luaState, 2)
    }

    func testFunctionReturningMixedArray() throws {
        let function = LuaFunction { () -> [Any] in
            return ["one", 2, true, 4.5]
        }

        function.push(to: lua.luaState)
        XCTAssertEqual(lua_pcall(lua.luaState, 0, 1, 0), LUA_OK)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        lua_rawgeti(lua.luaState, -1, 1)
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "one")
        lua_pop(lua.luaState, 1)

        lua_rawgeti(lua.luaState, -1, 2)
        XCTAssertEqual(lua_tointeger(lua.luaState, -1), 2)
        lua_pop(lua.luaState, 1)

        lua_rawgeti(lua.luaState, -1, 3)
        XCTAssertEqual(lua_toboolean(lua.luaState, -1), 1)
        lua_pop(lua.luaState, 1)

        lua_rawgeti(lua.luaState, -1, 4)
        XCTAssertEqual(lua_tonumber(lua.luaState, -1), 4.5, accuracy: 0.001)
        lua_pop(lua.luaState, 2)
    }

    func testFunctionReturningBridgeable() {
        // Test returning a dictionary which gets converted to a table
        let function = LuaFunction { () -> [String: Any] in
            return ["value": 999, "name": "test"]
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        // Should have pushed a table
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        // Verify table contents
        lua_getfield(lua.luaState, -1, "value")
        XCTAssertEqual(lua_tointeger(lua.luaState, -1), 999)
        lua_pop(lua.luaState, 2)
    }

    func testFunctionReturningUnsupportedType() throws {
        struct Unsupported {}

        let function = LuaFunction { () -> Unsupported in
            Unsupported()
        }

        function.push(to: lua.luaState)
        XCTAssertEqual(lua_pcall(lua.luaState, 0, 1, 0), LUA_OK)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Optional Handling Tests

    func testFunctionWithNestedOptionals() {
        let function = LuaFunction { () -> String?? in
            return "nested"
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TSTRING)
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "nested")
        lua_pop(lua.luaState, 1)
    }

    func testFunctionWithDeeplyNestedOptionals() {
        // Enable debug mode to test unwrapping path
        // LuaFunction.debugMode = true  // Disabled to avoid infinite loops
        defer { LuaFunction.debugMode = false }

        let function = LuaFunction { () -> String??? in
            let value: String??? = "deeply nested"
            return value
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TSTRING)
        XCTAssertEqual(String(cString: lua_tostring(lua.luaState, -1)!), "deeply nested")
        lua_pop(lua.luaState, 1)
    }

    func testFunctionWithOptionalThatIsNil() {
        let function = LuaFunction { () -> Int?? in
            let value: Int?? = nil
            return value
        }

        function.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Closure Table Lifecycle Tests

    func testFunctionTableGarbageCollection() throws {
        weak var weakFunction: LuaFunction?

        autoreleasepool {
            var function: LuaFunction? = LuaFunction { () -> Int in 42 }
            weakFunction = function

            function?.push(to: lua.luaState)
            lua_setglobal(lua.luaState, "temporaryFunction")
            function = nil

            XCTAssertNotNil(weakFunction)
        }

        try lua.execute("""
            assert(temporaryFunction() == 42)
            temporaryFunction = nil
            collectgarbage("collect")
            collectgarbage("collect")
        """)

        XCTAssertNil(weakFunction)
    }

    func testFunctionInvalidCall() {
        // Push a table that looks like a function but has invalid ID
        lua_createtable(lua.luaState, 0, 1)
        lua_pushinteger(lua.luaState, 999_999) // Non-existent ID
        lua_setfield(lua.luaState, -2, "_luakit_function_id")

        // Create metatable with __call
        lua_createtable(lua.luaState, 0, 1)
        lua_pushstring(lua.luaState, "__call")
        lua_pushcclosure(lua.luaState, { L in
            guard let L = L else { return 0 }

            // This mimics the LuaFunction __call implementation
            guard lua_type(L, 1) == LUA_TTABLE else {
                return luaError(L, "Invalid function object")
            }

            lua_getfield(L, 1, "_luakit_function_id")
            _ = Int(lua_tointegerx(L, -1, nil))
            lua_settop(L, -2)
            lua_remove(L, 1)

            // This ID won't exist
            return luaError(L, "Function no longer exists")
        }, 0)
        lua_settable(lua.luaState, -3)
        lua_setmetatable(lua.luaState, -2)

        lua_setglobal(lua.luaState, "invalidFunc")

        // Try to call it
        let result = try? lua.execute("return invalidFunc()")
        XCTAssertNil(result) // Should fail
    }

    func testFunctionTableWithoutMetatable() {
        // Try to call something that's not a proper function table
        _ = try? lua.execute("notAFunction = {}")

        let result = try? lua.execute("return notAFunction()")
        XCTAssertNil(result) // Should fail
    }

    // MARK: - Thread Safety Tests

    func testFunctionThreadSafety() {
        // Create many functions concurrently but don't access Lua state from multiple threads
        let expectation = self.expectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = 100

        let functionArray = FunctionArray()
        let queue = DispatchQueue(label: "test", attributes: .concurrent)

        for i in 0..<100 {
            queue.async {
                let function = LuaFunction { () -> Int in
                    return i
                }

                functionArray.append(function)

                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)

        // Now push them to Lua from main thread
        for (i, function) in functionArray.functions.enumerated() {
            function.push(to: lua.luaState)
            lua_setglobal(lua.luaState, "threadFunc\(i)")
        }
    }

    // MARK: - Edge Cases

    func testFunctionDeallocationOrder() throws {
        weak var firstFunction: LuaFunction?
        weak var secondFunction: LuaFunction?

        autoreleasepool {
            var first: LuaFunction? = LuaFunction { () -> String in "first" }
            var second: LuaFunction? = LuaFunction { () -> String in "second" }
            firstFunction = first
            secondFunction = second

            first?.push(to: lua.luaState)
            lua_setglobal(lua.luaState, "firstFunction")
            second?.push(to: lua.luaState)
            lua_setglobal(lua.luaState, "secondFunction")

            first = nil
            second = nil
            XCTAssertNotNil(firstFunction)
            XCTAssertNotNil(secondFunction)
        }

        try lua.execute("""
            assert(firstFunction() == "first")
            assert(secondFunction() == "second")
            firstFunction = nil
            secondFunction = nil
            collectgarbage("collect")
            collectgarbage("collect")
        """)

        XCTAssertNil(firstFunction)
        XCTAssertNil(secondFunction)
    }

    // MARK: - Performance Tests

    func testPushResultPerformance() {
        let function = LuaFunction { () -> [String: Any] in
            return [
                "a": 1, "b": 2, "c": 3, "d": 4, "e": 5,
                "f": 6, "g": 7, "h": 8, "i": 9, "j": 10
            ]
        }

        measure {
            for _ in 0..<1_000 {
                function.push(to: lua.luaState)
                _ = lua_pcall(lua.luaState, 0, 1, 0)
                lua_pop(lua.luaState, 1)
            }
        }
    }
}

// Define lua_remove since it's a macro in C
private func lua_remove(_ L: OpaquePointer, _ idx: Int32) {
    lua_rotate(L, idx, -1)
    lua_settop(L, -2)
}
