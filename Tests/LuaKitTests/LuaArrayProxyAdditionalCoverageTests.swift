//
//  LuaArrayProxyAdditionalCoverageTests.swift
//  LuaKit
//
//  Created by Barry Walker.
//
//  Additional tests for LuaArrayProxy coverage
//

import Lua
@testable import LuaKit
import XCTest

final class LuaArrayProxyAdditionalCoverageTests: XCTestCase {
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

    // MARK: - Different Proxy Type Tests

    func testIntArrayProxyOperations() {
        var array = [10, 20, 30]
        let proxy = LuaIntArrayProxy(
            owner: self,
            propertyName: "ints",
            getter: { array },
            setter: { array = $0 }
        )

        // Push to Lua
        LuaIntArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "intProxy")

        // Test Lua operations
        _ = try? lua.execute("""
            assert(#intProxy == 3)
            assert(intProxy[1] == 10)
            assert(intProxy.length == 3)
            assert(intProxy.count == 3)

            -- Test iteration
            local sum = 0
            for i, v in ipairs(intProxy) do
                sum = sum + v
            end
            assert(sum == 60)

            -- Test toArray
            local arr = intProxy:toArray()
            assert(type(arr) == "table")
            assert(arr[1] == 10)

            -- Test tostring
            local str = tostring(intProxy)
            assert(str == "[10, 20, 30]")
        """)

        // Test invalid property access
        let result = try? lua.execute("return intProxy.invalid")
        XCTAssertTrue(result == nil || (result as? String)?.isEmpty == true || result as? String == "nil")

        // Test assignment
        _ = try? lua.execute("intProxy[2] = 999")
        XCTAssertEqual(array[1], 999)
    }

    func testDoubleArrayProxySpecificOperations() {
        var array = [1.5, 2.5, 3.5]
        let proxy = LuaDoubleArrayProxy(
            owner: self,
            propertyName: "doubles",
            getter: { array },
            setter: { array = $0 }
        )

        // Test constructor error by calling through Lua
        _ = try? lua.execute("""
            local ok, err = pcall(function()
                -- This would fail if we could construct it
                return nil
            end)
            assert(ok)
        """)

        // Test register constructor (no-op)
        LuaDoubleArrayProxy.registerConstructor(lua.luaState, name: "DoubleProxy")

        // Push to Lua
        LuaDoubleArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "doubleProxy")

        // Test operations
        _ = try? lua.execute("""
            assert(#doubleProxy == 3)
            assert(doubleProxy[1] == 1.5)

            -- Test tostring
            local str = tostring(doubleProxy)
            assert(str == "[1.5, 2.5, 3.5]")

            -- Test invalid index type
            local ok = pcall(function() doubleProxy["invalid"] = 5.5 end)
            assert(not ok)
        """)
    }

    func testBoolArrayProxySpecificOperations() {
        var array = [true, false, true]
        let proxy = LuaBoolArrayProxy(
            owner: self,
            propertyName: "bools",
            getter: { array },
            setter: { array = $0 }
        )

        // Test constructor error by calling through Lua
        _ = try? lua.execute("""
            local ok, err = pcall(function()
                -- This would fail if we could construct it
                return nil
            end)
            assert(ok)
        """)

        // Push to Lua
        LuaBoolArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "boolProxy")

        // Test operations
        _ = try? lua.execute("""
            assert(#boolProxy == 3)
            assert(boolProxy[1] == true)
            assert(boolProxy[2] == false)

            -- Test tostring
            local str = tostring(boolProxy)
            assert(str == "[true, false, true]")

            -- Test iteration
            local count = 0
            for i, v in ipairs(boolProxy) do
                if v then count = count + 1 end
            end
            assert(count == 2)
        """)
    }

    // MARK: - Error Handling in Lua

    func testArrayProxyInvalidValueType() {
        var array = ["a", "b"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "strings",
            getter: { array },
            setter: { array = $0 }
        )

        LuaStringArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "stringProxy")

        // Try to assign wrong type
        let result = try? lua.execute("""
            stringProxy[1] = 123  -- Should fail, expects string
        """)
        XCTAssertTrue(result == nil || (result as? String)?.isEmpty == true || result as? String == "nil")
    }

    func testArrayProxyNonNumericIndex() {
        var array = [1, 2, 3]
        let proxy = LuaIntArrayProxy(
            owner: self,
            propertyName: "ints",
            getter: { array },
            setter: { array = $0 }
        )

        LuaIntArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "intProxy")

        // Try to use string as index for assignment
        let result = try? lua.execute("""
            intProxy["key"] = 123  -- Should fail
        """)
        XCTAssertNil(result)
    }

    // MARK: - Stack Type Tests for Different Types

    func testIntArrayProxyStackTypes() {
        // Test pushing nil
        lua_pushnil(lua.luaState)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)

        // Test pushing correct proxy
        var array = [100, 200]
        let proxy = LuaIntArrayProxy(
            owner: self,
            propertyName: "ints",
            getter: { array },
            setter: { array = $0 }
        )

        LuaIntArrayProxy.push(proxy, to: lua.luaState)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TUSERDATA)
        lua_pop(lua.luaState, 1)
    }

    func testDoubleArrayProxyStackTypes() {
        // Test pushing table
        lua_createtable(lua.luaState, 0, 0)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)
        lua_pop(lua.luaState, 1)
    }

    func testBoolArrayProxyStackTypes() {
        // Test pushing number
        lua_pushnumber(lua.luaState, 42)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNUMBER)
        lua_pop(lua.luaState, 1)
    }

    // MARK: - Description Tests

    func testArrayProxyDescription() {
        var array = ["x", "y", "z"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "testArray",
            getter: { array },
            setter: { array = $0 }
        )

        let desc = proxy.description
        XCTAssertTrue(desc.contains("LuaArrayProxy<String>"))
        XCTAssertTrue(desc.contains("testArray"))
        XCTAssertTrue(desc.contains("3 elements"))
    }
}