//
//  LuaTableIterationTests.swift
//  LuaKitTests
//
//  Tests for LuaTable Sequence conformance
//

import Lua
@testable import LuaKit
import XCTest

final class LuaTableIterationTests: XCTestCase {
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

    // MARK: - Basic Table Access Tests

    func testGetTable() throws {
        try lua.execute("""
            myTable = {a = 1, b = 2, c = 3}
        """)

        let table = lua.getTable("myTable")
        XCTAssertNotNil(table)
    }

    func testGetTableNonExistent() throws {
        let table = lua.getTable("nonExistent")
        XCTAssertNil(table)
    }

    func testGetTableNonTable() throws {
        try lua.execute("notATable = 42")

        let table = lua.getTable("notATable")
        XCTAssertNil(table)
    }

    // MARK: - Count Tests

    func testArrayCount() throws {
        try lua.execute("""
            numbers = {1, 2, 3, 4, 5}
        """)

        let table = lua.getTable("numbers")!
        XCTAssertEqual(table.count, 5)
    }

    func testDictionaryCount() throws {
        try lua.execute("""
            config = {host = "localhost", port = 8080}
        """)

        let table = lua.getTable("config")!
        XCTAssertEqual(table.count, 2)
    }

    func testEmptyTableCount() throws {
        try lua.execute("empty = {}")

        let table = lua.getTable("empty")!
        XCTAssertEqual(table.count, 0)
    }

    // MARK: - Keys and Values Tests

    func testKeys() throws {
        try lua.execute("""
            data = {x = 10, y = 20}
        """)

        let table = lua.getTable("data")!
        let keys = table.keys

        XCTAssertEqual(keys.count, 2)
        XCTAssertTrue(keys.contains(.string("x")))
        XCTAssertTrue(keys.contains(.string("y")))
    }

    func testValues() throws {
        try lua.execute("""
            data = {x = 10, y = 20}
        """)

        let table = lua.getTable("data")!
        let values = table.values

        XCTAssertEqual(values.count, 2)
        XCTAssertTrue(values.contains(.number(10)))
        XCTAssertTrue(values.contains(.number(20)))
    }

    func testArrayKeys() throws {
        try lua.execute("""
            arr = {"a", "b", "c"}
        """)

        let table = lua.getTable("arr")!
        let keys = table.keys

        XCTAssertEqual(keys.count, 3)
        // Array keys are 1-indexed integers
        XCTAssertTrue(keys.contains(.number(1)))
        XCTAssertTrue(keys.contains(.number(2)))
        XCTAssertTrue(keys.contains(.number(3)))
    }

    // MARK: - IsEmpty Tests

    func testIsEmpty() throws {
        try lua.execute("empty = {}")

        let table = lua.getTable("empty")!
        XCTAssertTrue(table.isEmpty)
    }

    func testIsNotEmpty() throws {
        try lua.execute("notEmpty = {1}")

        let table = lua.getTable("notEmpty")!
        XCTAssertFalse(table.isEmpty)
    }

    // MARK: - Contains Tests

    func testContainsKey() throws {
        try lua.execute("""
            data = {name = "test", value = 42}
        """)

        let table = lua.getTable("data")!
        XCTAssertTrue(table.contains(key: "name"))
        XCTAssertTrue(table.contains(key: "value"))
        XCTAssertFalse(table.contains(key: "missing"))
    }

    func testContainsIndex() throws {
        try lua.execute("""
            arr = {"a", "b", "c"}
        """)

        let table = lua.getTable("arr")!
        XCTAssertTrue(table.contains(index: 1))
        XCTAssertTrue(table.contains(index: 2))
        XCTAssertTrue(table.contains(index: 3))
        XCTAssertFalse(table.contains(index: 4))
    }

    // MARK: - Iteration Tests

    func testForEachIteration() throws {
        try lua.execute("""
            data = {a = 1, b = 2, c = 3}
        """)

        let table = lua.getTable("data")!
        var found: [String: Double] = [:]

        for (key, value) in table {
            if case .string(let k) = key, case .number(let v) = value {
                found[k] = v
            }
        }

        XCTAssertEqual(found["a"], 1)
        XCTAssertEqual(found["b"], 2)
        XCTAssertEqual(found["c"], 3)
    }

    func testArrayIteration() throws {
        try lua.execute("""
            arr = {10, 20, 30}
        """)

        let table = lua.getTable("arr")!
        var sum = 0.0

        for (_, value) in table {
            if case .number(let v) = value {
                sum += v
            }
        }

        XCTAssertEqual(sum, 60)
    }

    func testMapOverTable() throws {
        try lua.execute("""
            data = {x = 1, y = 2, z = 3}
        """)

        let table = lua.getTable("data")!
        let values = table.map { (_, value) -> Double? in
            if case .number(let v) = value {
                return v
            }
            return nil
        }.compactMap { $0 }

        XCTAssertEqual(values.sorted(), [1, 2, 3])
    }

    func testFilterTable() throws {
        try lua.execute("""
            numbers = {a = 1, b = 5, c = 10, d = 15}
        """)

        let table = lua.getTable("numbers")!
        let filtered = table.filter { (_, value) in
            if case .number(let v) = value {
                return v > 5
            }
            return false
        }

        XCTAssertEqual(filtered.count, 2)
    }

    // MARK: - Subscript Access Tests

    func testSubscriptStringKey() throws {
        try lua.execute("""
            config = {host = "localhost", port = 8080}
        """)

        let table = lua.getTable("config")!
        XCTAssertEqual(table["host"] as? String, "localhost")
        XCTAssertEqual(table["port"] as? Int, 8080)
    }

    func testSubscriptIntKey() throws {
        try lua.execute("""
            arr = {"first", "second", "third"}
        """)

        let table = lua.getTable("arr")!
        XCTAssertEqual(table[1] as? String, "first")
        XCTAssertEqual(table[2] as? String, "second")
        XCTAssertEqual(table[3] as? String, "third")
    }

    func testSubscriptSet() throws {
        let table = lua.createTable()
        table["name"] = "test"
        table["count"] = 42

        XCTAssertEqual(table["name"] as? String, "test")
        XCTAssertEqual(table["count"] as? Int, 42)
    }

    // MARK: - Mixed Table Tests

    func testMixedTable() throws {
        try lua.execute("""
            mixed = {1, 2, 3, name = "test", value = 42}
        """)

        let table = lua.getTable("mixed")!

        // Array part
        XCTAssertEqual(table[1] as? Int, 1)
        XCTAssertEqual(table[2] as? Int, 2)
        XCTAssertEqual(table[3] as? Int, 3)

        // Hash part
        XCTAssertEqual(table["name"] as? String, "test")
        XCTAssertEqual(table["value"] as? Int, 42)

        // Total count includes both parts
        XCTAssertEqual(table.count, 5)
    }
}
