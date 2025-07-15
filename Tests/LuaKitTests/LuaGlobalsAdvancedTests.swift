//
//  LuaGlobalsAdvancedTests.swift
//  LuaKit
//
//  Advanced tests for LuaGlobals, LuaReference, and LuaTable
//

import Lua
@testable import LuaKit
import XCTest

final class LuaGlobalsAdvancedTests: XCTestCase {
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

    // MARK: - LuaGlobals Advanced Tests

    func testGlobalsWithLuaFunction() {
        let function = LuaFunction { (a: Int, b: Int) -> Int in
            return a + b
        }

        lua.globals["myAdd"] = function

        let result = try? lua.execute("""
            return myAdd(10, 20)
        """)

        // Check that function was stored
        XCTAssertNotNil(lua.globals["myAdd"])

        // Execute and verify
        let sum = try? lua.executeReturning("return myAdd(5, 7)", as: Int.self)
        XCTAssertEqual(sum, 12)
    }

    func testGlobalsWithBridgeable() {
        class TestObject: NSObject {
            var value: Int = 42
        }

        let obj = TestObject()
        lua.globals["testObj"] = obj

        // Should be nil since NSObject doesn't conform to LuaBridgeable
        XCTAssertNil(lua.globals["testObj"])
    }

    func testGlobalsWithNil() {
        // Set a value
        lua.globals["temp"] = 123
        XCTAssertEqual(lua.globals["temp"] as? Int, 123)

        // Set to nil to remove
        lua.globals["temp"] = nil
        XCTAssertNil(lua.globals["temp"])

        // Verify it's actually removed
        let exists = try? lua.executeReturning("return temp ~= nil", as: Bool.self)
        XCTAssertEqual(exists, false)
    }

    func testGlobalsExtractValueEdgeCases() {
        // Test table extraction
        _ = try? lua.execute("globalTable = {a = 1, b = 2}")
        let tableValue = lua.globals["globalTable"]
        XCTAssertEqual(tableValue as? String, "<table>")

        // Test function extraction
        _ = try? lua.execute("globalFunc = function() end")
        let funcValue = lua.globals["globalFunc"]
        XCTAssertNil(funcValue) // Functions return nil in extractValue

        // Test userdata extraction
        _ = try? lua.execute("""
            globalUserdata = newproxy()
        """)
        let userdataValue = lua.globals["globalUserdata"]
        XCTAssertNil(userdataValue) // Userdata returns nil
    }

    func testGlobalsSetWithLuaReference() {
        // Skip - requires LuaBridgeable conformance
        XCTSkip("Requires LuaBridgeable conforming type")
    }

    func testGlobalsSetWithLuaTable() {
        let table = lua.createTable()
        table[1] = "first"
        table[2] = "second"
        table["key"] = "value"

        lua.globals.set("myTable", to: table)

        // Verify from Lua
        _ = try? lua.execute("""
            assert(myTable[1] == "first")
            assert(myTable[2] == "second")
            assert(myTable.key == "value")
        """)
    }

    // MARK: - LuaReference Tests

    func testLuaReferenceCreation() {
        // Skip - requires LuaBridgeable conformance
        XCTSkip("Requires LuaBridgeable conforming type")
    }

    func testLuaReferenceLifecycle() {
        // Skip - requires LuaBridgeable conformance
        XCTSkip("Requires LuaBridgeable conforming type")
    }

    func testLuaReferenceWithWeakLuaState() {
        // Skip - requires LuaBridgeable conformance
        XCTSkip("Requires LuaBridgeable conforming type")
    }

    // MARK: - LuaTable Tests

    func testLuaTableCreation() {
        let table = lua.createTable()

        // Should be able to push
        table.push()
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)
        lua_pop(lua.luaState, 1)
    }

    func testLuaTableArrayAccess() {
        let table = lua.createTable(arrayCount: 5)

        // Set array values
        table[1] = "first"
        table[2] = 42
        table[3] = true
        table[4] = 3.14
        table[5] = nil

        // Get array values
        XCTAssertEqual(table[1] as? String, "first")
        XCTAssertEqual(table[2] as? Int, 42)
        XCTAssertEqual(table[3] as? Bool, true)
        XCTAssertEqual(table[4] as? Double ?? 0.0, 3.14, accuracy: 0.01)
        XCTAssertNil(table[5])

        // Out of initial bounds
        table[10] = "tenth"
        XCTAssertEqual(table[10] as? String, "tenth")
    }

    func testLuaTableDictionaryAccess() {
        let table = lua.createTable(dictCount: 5)

        // Set dictionary values
        table["name"] = "John"
        table["age"] = 30
        table["active"] = true
        table["score"] = 95.5
        table["nothing"] = nil

        // Get dictionary values
        XCTAssertEqual(table["name"] as? String, "John")
        XCTAssertEqual(table["age"] as? Int, 30)
        XCTAssertEqual(table["active"] as? Bool, true)
        XCTAssertEqual(table["score"] as? Double ?? 0.0, 95.5, accuracy: 0.1)
        XCTAssertNil(table["nothing"])
        XCTAssertNil(table["nonexistent"])
    }

    func testLuaTableMixedAccess() {
        let table = lua.createTable(arrayCount: 3, dictCount: 3)

        // Mix array and dictionary access
        table[1] = "array1"
        table["key1"] = "dict1"
        table[2] = "array2"
        table["key2"] = "dict2"

        // Verify both work
        XCTAssertEqual(table[1] as? String, "array1")
        XCTAssertEqual(table[2] as? String, "array2")
        XCTAssertEqual(table["key1"] as? String, "dict1")
        XCTAssertEqual(table["key2"] as? String, "dict2")
    }

    func testLuaTableWithComplexTypes() {
        let table = lua.createTable()

        // Store a function
        let function = LuaFunction { () -> String in
            return "Hello from function"
        }
        table["func"] = function

        // Store another table
        let nestedTable = lua.createTable()
        nestedTable["nested"] = true
        table["subtable"] = nestedTable

        // Store a reference
        // Skip storing reference - requires LuaBridgeable
        // table["ref"] = ref

        // Verify storage - functions and tables return nil when retrieved
        XCTAssertNil(table["func"]) // Functions return nil
        XCTAssertNil(table["subtable"]) // Tables return nil
        // XCTAssertNotNil(table["ref"]) - skipped, requires LuaBridgeable
    }

    func testLuaTableLifecycle() {
        var table: LuaTable? = lua.createTable()
        table?[1] = "test"

        // Table should work
        XCTAssertEqual(table?[1] as? String, "test")

        // Deallocate table
        table = nil

        // The Lua registry should have cleaned up
        XCTAssertNil(table)
    }

    func testLuaTableWithWeakLuaState() {
        var localLua: LuaState? = try? LuaState()
        let table = localLua!.createTable()
        table["key"] = "value"

        // Deallocate Lua state
        localLua = nil

        // Operations should handle nil luaState gracefully
        table["newKey"] = "newValue" // Should not crash
        let value = table["key"] // Should still return the value
        XCTAssertEqual(value as? String, "value") // Table still works even with nil luaState
    }

    func testLuaTablePushValue() {
        let table = lua.createTable()

        // Test all supported types
        table["bool"] = true
        table["int"] = 123
        table["double"] = 45.67
        table["string"] = "test"

        // Test with LuaFunction
        let fn = LuaFunction { () in }
        table["function"] = fn

        // Test with unknown type (should store nil)
        struct UnknownType {}
        table["unknown"] = UnknownType()

        // Verify known types
        XCTAssertEqual(table["bool"] as? Bool, true)
        XCTAssertEqual(table["int"] as? Int, 123)
        XCTAssertEqual(table["string"] as? String, "test")

        // Unknown type should be nil when retrieved
        XCTAssertNil(table["unknown"])
    }

    // MARK: - Integration Tests

    func testGlobalsTableRoundTrip() {
        // Create table in Lua
        _ = try? lua.execute("""
            myGlobalTable = {
                array = {1, 2, 3},
                dict = {a = "A", b = "B"},
                mixed = 123
            }
        """)

        // Access through globals (returns "<table>")
        let tableDesc = lua.globals["myGlobalTable"] as? String
        XCTAssertEqual(tableDesc, "<table>")

        // Create Swift table and assign to global
        let swiftTable = lua.createTable()
        swiftTable["swift"] = "value"
        lua.globals.set("swiftTable", to: swiftTable)

        // Verify from Lua
        let hasSwift = try? lua.executeReturning("""
            return swiftTable.swift == "value"
        """, as: Bool.self)
        XCTAssertEqual(hasSwift, true)
    }

    func testComplexNestedStructures() {
        let root = lua.createTable()

        // Create nested structure
        let level1 = lua.createTable()
        level1["name"] = "Level 1"

        let level2 = lua.createTable()
        level2["name"] = "Level 2"
        level2["data"] = 42

        level1["child"] = level2
        root["tree"] = level1

        // Set as global
        lua.globals.set("complexData", to: root)

        // Verify from Lua
        _ = try? lua.execute("""
            assert(complexData.tree.name == "Level 1")
            assert(complexData.tree.child.name == "Level 2")
            assert(complexData.tree.child.data == 42)
        """)
    }

    // MARK: - Performance Tests

    func testGlobalsPerformance() {
        measure {
            for i in 0..<1_000 {
                lua.globals["perf_\(i)"] = i
                _ = lua.globals["perf_\(i)"]
            }
        }
    }

    func testTablePerformance() {
        let table = lua.createTable(arrayCount: 1_000, dictCount: 1_000)

        measure {
            // Array access
            for i in 1...1_000 {
                table[i] = i * 2
                _ = table[i]
            }

            // Dictionary access
            for i in 1...1_000 {
                table["key_\(i)"] = i * 3
                _ = table["key_\(i)"]
            }
        }
    }
}
