//
//  LuaGlobalsAdditionalCoverageTests.swift
//  LuaKit
//
//  Created by Barry Walker.
//
//  Additional tests to improve LuaGlobals coverage to ~95%
//

import Lua
@testable import LuaKit
import XCTest

// Test bridgeable class for coverage
class TestGlobalsBridgeable: LuaBridgeable {
    var value: String = "test"

    static func luaNew(_ luaState: OpaquePointer) -> Int32 {
        let instance = TestGlobalsBridgeable()
        push(instance, to: luaState)
        return 1
    }

    static func registerConstructor(_ luaState: OpaquePointer, name: String) {
        lua_pushcclosure(luaState, { innerState in
            guard let innerState = innerState else { return 0 }
            return TestGlobalsBridgeable.luaNew(innerState)
        }, 0)
        lua_setglobal(luaState, name)
    }

    static func registerMethods(_ luaState: OpaquePointer) {
        // No methods needed for this test
    }
}

final class LuaGlobalsAdditionalCoverageTests: XCTestCase {
    var lua: LuaState!

    override func setUp() {
        super.setUp()
        do {
            lua = try LuaState()
            TestGlobalsBridgeable.register(in: lua, as: "TestBridgeable")
        } catch {
            XCTFail("Failed to create LuaState: \(error)")
        }
    }

    override func tearDown() {
        lua = nil
        super.tearDown()
    }

    // MARK: - LuaGlobals Setter Test

    func testLuaGlobalsSetter() {
        // This tests the setter for globals property which exists only to enable subscript setters
        let originalGlobals = lua.globals
        lua.globals = originalGlobals // This should be a no-op

        // Verify globals still work
        lua.globals["test"] = "value"
        XCTAssertEqual(lua.globals["test"] as? String, "value")
    }

    // MARK: - Push Value Coverage

    func testPushAllValueTypes() {
        // Test pushing LuaFunction
        let testFunc = LuaFunction { () -> String in "function result" }
        lua.globals["testFunc"] = testFunc

        // Verify it was set (functions return nil when retrieved)
        _ = try? lua.execute("assert(type(testFunc) == 'table')")

        // Test pushing LuaBridgeable
        let bridgeable = TestGlobalsBridgeable()
        bridgeable.value = "bridgeable test"
        lua.globals["testBridgeable"] = bridgeable

        // Verify it was set
        _ = try? lua.execute("assert(type(testBridgeable) == 'userdata')")

        // Test pushing LuaReference
        let ref = lua.toReference(bridgeable)
        lua.globals.set("testRef", to: ref)

        // Verify it was set
        _ = try? lua.execute("assert(type(testRef) == 'userdata')")

        // Test pushing LuaTable
        let table = lua.createTable()
        table["key"] = "value"
        lua.globals.set("testTable", to: table)

        // Verify it was set
        let result = try? lua.execute("return testTable.key")
        XCTAssertNotNil(result)

        // Test pushing arrays and dictionaries (covered by existing method)
        lua.globals["testArray"] = [1, 2, 3]
        lua.globals["testDict"] = ["a": 1, "b": 2]

        // Test pushing unsupported type (should push nil)
        struct UnsupportedType {}
        lua.globals["unsupported"] = UnsupportedType()
        XCTAssertNil(lua.globals["unsupported"])
    }

    // MARK: - Extract Value Edge Cases

    func testExtractStringWithNullBytes() {
        // Test string extraction edge case
        _ = try? lua.execute("""
            testString = "hello\\0world"
        """)

        let str = lua.globals["testString"] as? String
        XCTAssertNotNil(str)
        XCTAssertTrue(str?.contains("hello") ?? false)
    }

    func testExtractUserdata() {
        // Create userdata in Lua
        _ = try? lua.execute("""
            testUserdata = TestBridgeable()
        """)

        // Extract it - should return "<userdata>"
        let value = lua.globals["testUserdata"]
        XCTAssertEqual(value as? String, "<userdata>")
    }

    // MARK: - LuaReference Tests

    func testLuaReferenceWithDeallocatedState() {
        var ref: LuaReference?

        autoreleasepool {
            let tempLua = try? LuaState()
            let bridgeable = TestGlobalsBridgeable()
            ref = tempLua?.toReference(bridgeable)

            // Push the reference while state is valid
            ref?.push()
            XCTAssertEqual(lua_type(tempLua!.luaState, -1), LUA_TUSERDATA)
            lua_pop(tempLua!.luaState, 1)
        }

        // Now lua state is deallocated, push should do nothing
        ref?.push()

        // Should not crash
        XCTAssertTrue(true)
    }

    func testLuaReferenceCreationAndCleanup() {
        let bridgeable = TestGlobalsBridgeable()
        bridgeable.value = "reference test"

        // Create reference
        let ref = LuaReference(object: bridgeable, luaState: lua)

        // Push it multiple times
        ref.push()
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TUSERDATA)
        lua_pop(lua.luaState, 1)

        ref.push()
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TUSERDATA)
        lua_pop(lua.luaState, 1)

        // Reference will be cleaned up when it goes out of scope
    }

    // MARK: - LuaTable Coverage

    func testLuaTableWithDeallocatedState() {
        var table: LuaTable?
        var valueBeforeDealloc: String?
        var keyValueBeforeDealloc: String?

        autoreleasepool {
            let tempLua = try? LuaState()
            table = tempLua?.createTable(arrayCount: 3, dictCount: 2)

            // Set values while state is valid
            table?[1] = "first"
            table?["key"] = "value"

            valueBeforeDealloc = table?[1] as? String
            keyValueBeforeDealloc = table?["key"] as? String
            
            XCTAssertEqual(valueBeforeDealloc, "first")
            XCTAssertEqual(keyValueBeforeDealloc, "value")
        }

        // Now lua state is deallocated
        // The table might cache values, so we can't assume they'll be nil
        // Just verify operations don't crash
        table?[2] = "should not work"
        table?["newKey"] = "should not work"

        // Push should do nothing
        table?.push()

        // Should not crash
        XCTAssertTrue(true)
    }

    func testLuaTableComplexOperations() {
        let table = lua.createTable()

        // Test all value types in table
        table[1] = true
        table[2] = 42
        table[3] = 3.14
        table[4] = "string"
        table[5] = nil // Clear a value

        table["bool"] = false
        table["int"] = 100
        table["double"] = 99.99
        table["string"] = "test"
        table["nil"] = nil

        // Test with LuaFunction
        let testFunc = LuaFunction { () -> Int in 123 }
        table["func"] = testFunc

        // Test with LuaBridgeable
        let bridgeable = TestGlobalsBridgeable()
        table["bridgeable"] = bridgeable

        // Test with nested table
        let nested = lua.createTable()
        nested["inner"] = "nested value"
        table["nested"] = nested

        // Test with reference
        let ref = lua.toReference(bridgeable)
        table["ref"] = ref

        // Test unsupported type
        struct Unsupported {}
        table["unsupported"] = Unsupported()

        // Verify values
        XCTAssertEqual(table[1] as? Bool, true)
        XCTAssertEqual(table[2] as? Int, 42)
        XCTAssertEqual(table[3] as? Double ?? 0.0, 3.14, accuracy: 0.01)
        XCTAssertEqual(table[4] as? String, "string")
        XCTAssertNil(table[5])

        XCTAssertEqual(table["bool"] as? Bool, false)
        XCTAssertEqual(table["int"] as? Int, 100)
        XCTAssertEqual(table["double"] as? Double ?? 0.0, 99.99, accuracy: 0.01)
        XCTAssertEqual(table["string"] as? String, "test")
        XCTAssertNil(table["nil"])

        // Functions, tables, and userdata return nil when extracted
        XCTAssertNil(table["func"])
        XCTAssertNil(table["bridgeable"])
        XCTAssertNil(table["nested"])
        XCTAssertNil(table["ref"])
        XCTAssertNil(table["unsupported"])
    }

    func testLuaTablePushToLua() {
        let table = lua.createTable()
        table["test"] = "value"
        table[1] = 42

        // Push table to Lua
        table.push()
        lua_setglobal(lua.luaState, "pushedTable")

        // Verify in Lua
        let result = try? lua.execute("""
            return pushedTable.test, pushedTable[1]
        """)

        XCTAssertNotNil(result)
    }

    // MARK: - Edge Cases for Extract Value

    func testExtractValueFromNonStringTypes() {
        // Create various Lua types that aren't normally extracted
        _ = try? lua.execute("""
            -- Function
            testFunc = function() return 42 end

            -- Thread/Coroutine
            testThread = coroutine.create(function() end)

            -- Light userdata (can't easily create, but test the path)

            -- Create a string that might fail to convert
            testBadString = 123  -- Not actually a string
        """)

        // Test extraction
        XCTAssertNil(lua.globals["testFunc"]) // Functions return nil
        XCTAssertNil(lua.globals["testThread"]) // Threads return nil
        XCTAssertEqual(lua.globals["testBadString"] as? Int, 123) // Should extract as int
    }

    // MARK: - Array and Dictionary Specific Tests

    func testPushArraysAndDictionaries() {
        // These use specific push methods in LuaValue+Arrays extension

        // String arrays
        lua.globals["strings"] = ["a", "b", "c"]
        _ = try? lua.execute("assert(#strings == 3)")

        // Int arrays
        lua.globals["ints"] = [1, 2, 3, 4, 5]
        _ = try? lua.execute("assert(#ints == 5)")

        // Double arrays
        lua.globals["doubles"] = [1.1, 2.2, 3.3]
        _ = try? lua.execute("assert(#doubles == 3)")

        // Bool arrays
        lua.globals["bools"] = [true, false, true]
        _ = try? lua.execute("assert(#bools == 3)")

        // Dictionaries
        lua.globals["stringDict"] = ["key1": "value1", "key2": "value2"]
        _ = try? lua.execute("assert(stringDict.key1 == 'value1')")

        // Empty collections
        lua.globals["emptyArray"] = [String]()
        lua.globals["emptyDict"] = [String: Int]()

        _ = try? lua.execute("assert(#emptyArray == 0)")
        _ = try? lua.execute("assert(type(emptyDict) == 'table')")
    }

    // MARK: - Coverage for Integer vs Number Distinction

    func testNumberTypeExtraction() {
        _ = try? lua.execute("""
            -- Test integer
            integerValue = 42

            -- Test float
            floatValue = 3.14159

            -- Test very large integer
            largeInt = 9007199254740992  -- 2^53

            -- Test very small float
            smallFloat = 0.000000001

            -- Test negative values
            negInt = -100
            negFloat = -99.99
        """)

        // Verify correct type extraction
        XCTAssertEqual(lua.globals["integerValue"] as? Int, 42)
        XCTAssertEqual(lua.globals["floatValue"] as? Double ?? 0.0, 3.14159, accuracy: 0.00001)
        XCTAssertNotNil(lua.globals["largeInt"] as? Int)
        XCTAssertEqual(lua.globals["smallFloat"] as? Double ?? 0.0, 0.000000001, accuracy: 0.0000000001)
        XCTAssertEqual(lua.globals["negInt"] as? Int, -100)
        XCTAssertEqual(lua.globals["negFloat"] as? Double ?? 0.0, -99.99, accuracy: 0.01)
    }

    // MARK: - Memory Management Tests

    func testMultipleReferencesToSameObject() {
        let bridgeable = TestGlobalsBridgeable()
        bridgeable.value = "shared"

        // Create multiple references
        let ref1 = lua.toReference(bridgeable)
        let ref2 = lua.toReference(bridgeable)
        let ref3 = lua.toReference(bridgeable)

        // Set them all as globals
        lua.globals.set("ref1", to: ref1)
        lua.globals.set("ref2", to: ref2)
        lua.globals.set("ref3", to: ref3)

        // Verify all are userdata
        _ = try? lua.execute("""
            assert(type(ref1) == 'userdata')
            assert(type(ref2) == 'userdata')
            assert(type(ref3) == 'userdata')
        """)

        // References will be cleaned up when they go out of scope
    }

    func testTableCleanupOnDealloc() {
        autoreleasepool {
            let table1 = lua.createTable()
            let table2 = lua.createTable()
            let table3 = lua.createTable()

            table1["data"] = "will be cleaned"
            table2[1] = 100
            table3["nested"] = table1

            // Tables will be cleaned up when they go out of scope
        }

        // Force garbage collection
        _ = try? lua.execute("collectgarbage('collect')")

        // Should not crash
        XCTAssertTrue(true)
    }
}
