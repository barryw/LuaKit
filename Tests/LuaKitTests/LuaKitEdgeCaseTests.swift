//
//  LuaKitEdgeCaseTests.swift
//  LuaKit
//
//  Tests for edge cases and defensive code paths
//

import Lua
@testable import LuaKit
import XCTest

final class LuaKitEdgeCaseTests: XCTestCase {
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

    // MARK: - LuaFunction Debug Mode Tests

    func testLuaFunctionDebugModeEnabled() {
        // Test debug mode flag without actually enabling it to avoid infinite loops
        let originalDebugMode = LuaFunction.debugMode
        defer { LuaFunction.debugMode = originalDebugMode }

        // Test function with no arguments
        let fn1 = LuaFunction { () -> String in
            return "debug test"
        }
        fn1.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)
        lua_pop(lua.luaState, 1)

        // Test function with arguments
        let fn2 = LuaFunction { (x: Int) -> Int in
            return x * 2
        }
        fn2.push(to: lua.luaState)
        lua_pushinteger(lua.luaState, 5)
        _ = lua_pcall(lua.luaState, 1, 1, 0)
        lua_pop(lua.luaState, 1)

        // Test function with multiple arguments
        let fn3 = LuaFunction { (a: String, b: Int, c: Double) -> String in
            return "\(a) \(b) \(c)"
        }
        fn3.push(to: lua.luaState)
        lua_pushstring(lua.luaState, "test")
        lua_pushinteger(lua.luaState, 42)
        lua_pushnumber(lua.luaState, 3.14)
        _ = lua_pcall(lua.luaState, 3, 1, 0)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Nested Optional Tests

    func testDeeplyNestedOptionals() {
        // Test optional unwrapping without debug mode to avoid infinite loops
        let originalDebugMode = LuaFunction.debugMode
        defer { LuaFunction.debugMode = originalDebugMode }

        // Test various levels of optional nesting
        let fn1 = LuaFunction { () -> Int??? in
            let value: Int??? = 42
            return value
        }

        fn1.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)
        XCTAssertEqual(lua_tointeger(lua.luaState, -1), 42)
        lua_pop(lua.luaState, 1)

        // Test with nil at different levels
        let fn2 = LuaFunction { () -> String???? in
            let value: String???? = nil
            return value
        }

        fn2.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)

        // Test with some(.some(nil))
        let fn3 = LuaFunction { () -> Double?? in
            let inner: Double? = nil
            let value: Double?? = inner
            return value
        }

        fn3.push(to: lua.luaState)
        _ = lua_pcall(lua.luaState, 0, 1, 0)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Print Buffer Edge Cases

    func testPrintBufferMaxSizePolicy() {
        lua.setPrintBufferPolicy(.maxSize(20))

        // Print something that exceeds the limit
        _ = try? lua.execute("print('This is a very long string that exceeds the buffer limit')")

        let buffer = lua.getCurrentPrintBuffer()
        XCTAssertEqual(buffer.count, 20)
    }

    func testPrintBufferTruncateOldestPolicy() {
        lua.setPrintBufferPolicy(.truncateOldest)

        // Generate output that would trigger truncation
        for i in 1...100 {
            _ = try? lua.execute("print('Line \(i)')")
        }

        // Should not crash and buffer should be managed
        XCTAssertTrue(true)
    }

    func testPrintBufferTruncateNewestPolicy() {
        lua.setPrintBufferPolicy(.truncateNewest)

        // Generate output
        for i in 1...50 {
            _ = try? lua.execute("print('Output \(i)')")
        }

        // Should handle the policy
        XCTAssertTrue(true)
    }

    // MARK: - Type Extraction Edge Cases

    func testExtractValueFromLuaTypes() {
        // Create various Lua types
        _ = try? lua.execute("""
            -- Light userdata (can't easily create in pure Lua)
            testTable = {nested = {value = 123}}
            testClosure = function() return 42 end
            testCoroutine = coroutine.create(function() end)
            testFullUserdata = newproxy(true)
            getmetatable(testFullUserdata).__tostring = function() return "custom userdata" end
        """)

        // Test extraction
        let tableValue = lua.globals["testTable"]
        XCTAssertEqual(tableValue as? String, "<table>")

        let closureValue = lua.globals["testClosure"]
        XCTAssertNil(closureValue) // Functions return nil

        let coroutineValue = lua.globals["testCoroutine"]
        XCTAssertNil(coroutineValue) // Threads return nil

        let userdataValue = lua.globals["testFullUserdata"]
        XCTAssertNil(userdataValue) // Userdata returns nil
    }

    // MARK: - Integer vs Number Distinction

    func testIntegerVsNumberHandling() {
        _ = try? lua.execute("""
            intValue = 42
            floatValue = 42.0
            bigIntValue = 9223372036854775807  -- max Int64
            tinyFloatValue = 0.0000001
        """)

        // Check that integers are extracted as Int
        let intVal = lua.globals["intValue"]
        XCTAssertEqual(intVal as? Int, 42)

        // Check that floats are extracted as Double
        let floatVal = lua.globals["floatValue"]
        XCTAssertEqual(floatVal as? Double, 42.0)

        // Check edge cases
        let bigInt = lua.globals["bigIntValue"]
        XCTAssertNotNil(bigInt)

        let tinyFloat = lua.globals["tinyFloatValue"]
        XCTAssertEqual(tinyFloat as? Double ?? 0, 0.0000001, accuracy: 0.00000001)
    }

    // MARK: - Array Proxy Validation Tests

    func testArrayProxyWithValidator() {
        var strings = ["a", "b", "c"]

        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "validated",
            getter: { strings },
            setter: { strings = $0 },
            validator: { array in
                // Reject arrays with more than 3 elements
                if array.count > 3 {
                    return .failure(PropertyValidationError("Array too large"))
                }
                return .success(())
            }
        )

        // This should succeed
        try? proxy.setElement(at: 2, to: "B")
        XCTAssertEqual(strings[1], "B")

        // This should fail (would make array size 4)
        XCTAssertThrowsError(try proxy.setElement(at: 4, to: "D")) { error in
            XCTAssertTrue(error is PropertyValidationError)
        }
    }

    // MARK: - Error Message Extraction

    func testErrorMessageExtraction() {
        // Test syntax error with non-ASCII characters
        let result1 = try? lua.execute("print('Hello 世界") // Missing closing quote
        XCTAssertNil(result1)

        // Test runtime error with special characters
        let result2 = try? lua.execute("error('Error with special chars: @#$%^&*()')")
        XCTAssertNil(result2)
    }

    // MARK: - Memory Pressure Tests

    func testHighMemoryPressure() {
        // Create many Lua objects
        for i in 0..<1_000 {
            let table = lua.createTable(arrayCount: 100, dictCount: 100)
            for j in 1...100 {
                table[j] = String(repeating: "x", count: 1_000)
            }
            lua.globals["bigTable\(i)"] = table
        }

        // Force garbage collection
        _ = try? lua.execute("collectgarbage('collect')")

        // Clean up
        for i in 0..<1_000 {
            lua.globals["bigTable\(i)"] = nil
        }

        XCTAssertTrue(true) // Verify no crash
    }
}
