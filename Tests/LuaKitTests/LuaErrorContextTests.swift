//
//  LuaErrorContextTests.swift
//  LuaKit
//
//  Tests for LuaErrorContext functionality
//

import Lua
@testable import LuaKit
import XCTest

final class LuaErrorContextTests: XCTestCase {
    var L: OpaquePointer!

    override func setUp() {
        super.setUp()
        L = luaL_newstate()
        luaL_openselectedlibs(L, ~0, 0)
    }

    override func tearDown() {
        lua_close(L)
        L = nil
        super.tearDown()
    }

    // MARK: - OpaquePointer Extension Tests

    func testLuaTypeNameForBasicTypes() {
        // Test nil
        lua_pushnil(L)
        XCTAssertEqual(L.luaTypeName(at: -1), "nil")
        lua_pop(L, 1)

        // Test boolean
        lua_pushboolean(L, 1)
        XCTAssertEqual(L.luaTypeName(at: -1), "boolean")
        lua_pop(L, 1)

        // Test integer
        lua_pushinteger(L, 42)
        XCTAssertEqual(L.luaTypeName(at: -1), "integer")
        lua_pop(L, 1)

        // Test number
        lua_pushnumber(L, 3.14)
        XCTAssertEqual(L.luaTypeName(at: -1), "number")
        lua_pop(L, 1)

        // Test string
        lua_pushstring(L, "test")
        XCTAssertEqual(L.luaTypeName(at: -1), "string")
        lua_pop(L, 1)

        // Test table
        lua_newtable(L)
        XCTAssertEqual(L.luaTypeName(at: -1), "table")
        lua_pop(L, 1)

        // Test function
        lua_pushcclosure(L, { _ in 0 }, 0)
        XCTAssertEqual(L.luaTypeName(at: -1), "function")
        lua_pop(L, 1)
    }

    func testLuaTypeNameWithMetatable() {
        // Create a table with metatable
        lua_newtable(L)

        // Create metatable with __name
        lua_newtable(L)
        lua_pushstring(L, "MyCustomType")
        lua_setfield(L, -2, "__name")

        // Set metatable
        lua_setmetatable(L, -2)

        XCTAssertEqual(L.luaTypeName(at: -1), "MyCustomType")
        lua_pop(L, 1)
    }

    func testLuaValueDescription() {
        // Test nil
        lua_pushnil(L)
        XCTAssertEqual(L.luaValueDescription(at: -1), "nil")
        lua_pop(L, 1)

        // Test boolean true
        lua_pushboolean(L, 1)
        XCTAssertEqual(L.luaValueDescription(at: -1), "true")
        lua_pop(L, 1)

        // Test boolean false
        lua_pushboolean(L, 0)
        XCTAssertEqual(L.luaValueDescription(at: -1), "false")
        lua_pop(L, 1)

        // Test integer
        lua_pushinteger(L, 123)
        XCTAssertEqual(L.luaValueDescription(at: -1), "123")
        lua_pop(L, 1)

        // Test number
        lua_pushnumber(L, 45.67)
        XCTAssertEqual(L.luaValueDescription(at: -1), "45.67")
        lua_pop(L, 1)

        // Test string
        lua_pushstring(L, "hello")
        XCTAssertEqual(L.luaValueDescription(at: -1), "\"hello\"")
        lua_pop(L, 1)

        // Test table
        lua_newtable(L)
        XCTAssertEqual(L.luaValueDescription(at: -1), "table")
        lua_pop(L, 1)

        // Test function
        lua_pushcclosure(L, { _ in 0 }, 0)
        XCTAssertEqual(L.luaValueDescription(at: -1), "function")
        lua_pop(L, 1)
    }

    // MARK: - Type Validation Tests

    func testValidateLuaTypeSuccess() {
        lua_pushnumber(L, 42)

        let result = validateLuaType(
            L,
            at: -1,
            expectedTypes: [LUA_TNUMBER],
            functionName: "testFunc"
        )

        XCTAssertTrue(result)
        lua_pop(L, 1)
    }

    func testValidateLuaTypeMultipleTypes() {
        lua_pushstring(L, "test")

        let result = validateLuaType(
            L,
            at: -1,
            expectedTypes: [LUA_TNUMBER, LUA_TSTRING],
            functionName: "testFunc"
        )

        XCTAssertTrue(result)
        lua_pop(L, 1)
    }

    func testValidateLuaTypeFailure() {
        lua_pushstring(L, "not a number")

        // Wrap in pcall to catch the error
        lua_pushcclosure(L, { L in
            lua_pushstring(L!, "not a number")
            _ = validateLuaType(
                L!,
                at: -1,
                expectedTypes: [LUA_TNUMBER],
                functionName: "calculate",
                parameterName: "amount"
            )
            return 0
        }, 0)

        let result = lua_pcall(L, 0, 0, 0)
        XCTAssertNotEqual(result, 0) // Should have error

        if result != 0 {
            let error = String(cString: lua_tostring(L, -1)!)
            XCTAssertTrue(error.contains("calculate"))
            XCTAssertTrue(error.contains("amount"))
            lua_pop(L, 1)
        }
    }

    // MARK: - luaDetailedError Tests

    func testLuaDetailedError() {
        // Test in protected mode
        lua_pushcclosure(L, { L in
            _ = luaDetailedError(
                L!,
                functionName: "process",
                argumentIndex: 2,
                expectedType: "table",
                actualType: "string",
                additionalInfo: "Configuration table required",
                hint: "Pass a table with configuration options"
            )
            return 0
        }, 0)

        let result = lua_pcall(L, 0, 0, 0)
        XCTAssertNotEqual(result, 0)

        if result != 0 {
            let error = String(cString: lua_tostring(L, -1)!)
            XCTAssertTrue(error.contains("Invalid argument #2 to 'process'"))
            XCTAssertTrue(error.contains("Expected: table"))
            XCTAssertTrue(error.contains("Got: string"))
            XCTAssertTrue(error.contains("Configuration table required"))
            XCTAssertTrue(error.contains("Hint: Pass a table with configuration options"))
            lua_pop(L, 1)
        }
    }

    func testLuaDetailedErrorWithAutomaticType() {
        // Push a boolean value
        lua_pushboolean(L, 1)

        // Test in protected mode
        lua_pushcclosure(L, { L in
            lua_pushboolean(L!, 1)
            _ = luaDetailedError(
                L!,
                functionName: "calculate",
                argumentIndex: 1,
                expectedType: "number"
                // actualType will be determined automatically
            )
            return 0
        }, 0)

        let result = lua_pcall(L, 0, 0, 0)
        XCTAssertNotEqual(result, 0)

        if result != 0 {
            let error = String(cString: lua_tostring(L, -1)!)
            XCTAssertTrue(error.contains("Got: boolean"))
            lua_pop(L, 1)
        }
    }
}
