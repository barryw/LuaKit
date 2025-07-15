//
//  LuaConstantsTests.swift
//  LuaKit
//
//  Tests for LuaConstants helper functions
//

import Lua
@testable import LuaKit
import XCTest

final class LuaConstantsTests: XCTestCase {
    var L: OpaquePointer!

    override func setUp() {
        super.setUp()
        L = luaL_newstate()
        luaL_openlibs(L)
    }

    override func tearDown() {
        lua_close(L)
        L = nil
        super.tearDown()
    }

    func testLuaRegistryIndex() {
        // Test that luaRegistryIndex is correctly defined
        XCTAssertEqual(luaRegistryIndex, -1_001_000)

        // Test that we can use it with registry operations
        lua_pushstring(L, "test_value")
        lua_setfield(L, luaRegistryIndex, "test_key")

        lua_getfield(L, luaRegistryIndex, "test_key")
        let result = String(cString: lua_tostring(L, -1)!)
        XCTAssertEqual(result, "test_value")

        lua_pop(L, 1)
    }

    func testLuaPop() {
        // Push some values onto the stack
        lua_pushinteger(L, 10)
        lua_pushinteger(L, 20)
        lua_pushinteger(L, 30)

        XCTAssertEqual(lua_gettop(L), 3)

        // Pop one value
        lua_pop(L, 1)
        XCTAssertEqual(lua_gettop(L), 2)

        // Pop two values
        lua_pop(L, 2)
        XCTAssertEqual(lua_gettop(L), 0)
    }

    func testLuaNewtable() {
        let initialTop = lua_gettop(L)

        // Create a new table
        lua_newtable(L)

        // Verify stack increased by 1
        XCTAssertEqual(lua_gettop(L), initialTop + 1)

        // Verify it's a table
        XCTAssertEqual(lua_type(L, -1), LUA_TTABLE)

        lua_pop(L, 1)
    }

    func testLuaTostring() {
        // Test with string
        lua_pushstring(L, "Hello, Lua!")
        let str1 = lua_tostring(L, -1)
        XCTAssertNotNil(str1)
        XCTAssertEqual(String(cString: str1!), "Hello, Lua!")
        lua_pop(L, 1)

        // Test with number (should convert to string)
        lua_pushnumber(L, 42.5)
        let str2 = lua_tostring(L, -1)
        XCTAssertNotNil(str2)
        XCTAssertEqual(String(cString: str2!), "42.5")
        lua_pop(L, 1)

        // Test with boolean
        lua_pushboolean(L, 1)
        let str3 = lua_tostring(L, -1)
        XCTAssertNil(str3) // booleans don't convert to strings
        lua_pop(L, 1)
    }

    func testLuaTonumber() {
        // Test with number
        lua_pushnumber(L, 123.456)
        let num1 = lua_tonumber(L, -1)
        XCTAssertEqual(num1, 123.456)
        lua_pop(L, 1)

        // Test with string that can be converted to number
        lua_pushstring(L, "789.123")
        let num2 = lua_tonumber(L, -1)
        XCTAssertEqual(num2, 789.123)
        lua_pop(L, 1)

        // Test with non-numeric string
        lua_pushstring(L, "not a number")
        let num3 = lua_tonumber(L, -1)
        XCTAssertEqual(num3, 0) // Non-numeric strings convert to 0
        lua_pop(L, 1)
    }

    func testLuaTointeger() {
        // Test with integer
        lua_pushinteger(L, 42)
        let int1 = lua_tointeger(L, -1)
        XCTAssertEqual(int1, 42)
        lua_pop(L, 1)

        // Test with float (should return 0 - not an exact integer)
        lua_pushnumber(L, 3.14)
        let int2 = lua_tointeger(L, -1)
        XCTAssertEqual(int2, 0) // Lua 5.4 doesn't convert non-integer floats
        lua_pop(L, 1)

        // Test with integer-valued float (should convert)
        lua_pushnumber(L, 5.0)
        let int2b = lua_tointeger(L, -1)
        XCTAssertEqual(int2b, 5) // Exact integer float converts
        lua_pop(L, 1)

        // Test with numeric string (should convert in Lua 5.4)
        lua_pushstring(L, "100")
        let int3 = lua_tointeger(L, -1)
        XCTAssertEqual(int3, 100) // Lua 5.4 converts numeric strings
        lua_pop(L, 1)

        // Test with non-numeric string (should return 0)
        lua_pushstring(L, "hello")
        let int4 = lua_tointeger(L, -1)
        XCTAssertEqual(int4, 0) // Non-numeric strings return 0
        lua_pop(L, 1)
    }

    func testLuaPcall() {
        // Define a simple Lua function
        let code = """
            function add(a, b)
                return a + b
            end
        """
        let loadResult = luaL_loadstring(L, code)
        if loadResult != 0 {
            XCTFail("Failed to load Lua code")
        } else {
            XCTAssertEqual(lua_pcall(L, 0, 0, 0), 0)
        }

        // Call the function using lua_pcall
        lua_getglobal(L, "add")
        lua_pushnumber(L, 5)
        lua_pushnumber(L, 3)

        let result = lua_pcall(L, 2, 1, 0)
        XCTAssertEqual(result, 0) // LUA_OK

        // Check the result
        let sum = lua_tonumber(L, -1)
        XCTAssertEqual(sum, 8)
        lua_pop(L, 1)

        // Test with error
        lua_getglobal(L, "add")
        lua_pushnil(L) // This will cause an error (can't add nil)
        lua_pushnumber(L, 3)

        let errorResult = lua_pcall(L, 2, 1, 0)
        XCTAssertNotEqual(errorResult, 0) // Should have an error

        // Error message should be on the stack
        let errorMsg = lua_tostring(L, -1)
        XCTAssertNotNil(errorMsg)
        lua_pop(L, 1)
    }

    func testLuaGetMetatable() {
        // Create a metatable and register it
        lua_newtable(L)
        lua_pushstring(L, "MyMetatable")
        lua_setfield(L, -2, "__name")
        lua_setfield(L, luaRegistryIndex, "TestMetatable")

        // Get the metatable using luaGetMetatable
        luaGetMetatable(L, "TestMetatable")
        XCTAssertEqual(lua_type(L, -1), LUA_TTABLE)

        // Verify it's the correct metatable
        lua_getfield(L, -1, "__name")
        let name = String(cString: lua_tostring(L, -1)!)
        XCTAssertEqual(name, "MyMetatable")

        lua_pop(L, 2)
    }

    func testLuaError() {
        // This test is tricky because lua_error doesn't return
        // We'll test it indirectly through a protected call

        // Register a C function that calls luaError
        let errorFunc: lua_CFunction = { L in
            _ = luaError(L!, "Test error message")
            return 0 // This won't be reached
        }

        lua_pushcclosure(L, errorFunc, 0)
        lua_setglobal(L, "errorFunc")

        // Call it in protected mode
        lua_getglobal(L, "errorFunc")
        let result = lua_pcall(L, 0, 0, 0)

        XCTAssertNotEqual(result, 0) // Should have an error

        // Check the error message
        let errorMsg = String(cString: lua_tostring(L, -1)!)
        XCTAssertTrue(errorMsg.contains("Test error message"))

        lua_pop(L, 1)
    }

    func testHelperFunctionsWithInvalidIndices() {
        // Test behavior with invalid stack indices

        // lua_tostring with empty stack
        let str = lua_tostring(L, 1)
        XCTAssertNil(str)

        // lua_tonumber with empty stack
        let num = lua_tonumber(L, 1)
        XCTAssertEqual(num, 0)

        // lua_tointeger with empty stack
        let int = lua_tointeger(L, 1)
        XCTAssertEqual(int, 0)
    }
}
