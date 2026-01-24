//
//  NestedCollectionTests.swift
//  LuaKitTests
//
//  Tests for nested array and dictionary support
//

import Lua
@testable import LuaKit
import XCTest

final class NestedCollectionTests: XCTestCase {
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

    // MARK: - Simple Array Tests

    func testSimpleIntArray() throws {
        lua.globals["numbers"] = [1, 2, 3, 4, 5]

        let output = try lua.execute("""
            local sum = 0
            for _, n in ipairs(numbers) do
                sum = sum + n
            end
            print("Sum:", sum)
        """)

        XCTAssertTrue(output.contains("Sum:\t15"))
    }

    func testSimpleStringArray() throws {
        lua.globals["words"] = ["hello", "world"]

        let output = try lua.execute("""
            print(words[1], words[2])
        """)

        XCTAssertTrue(output.contains("hello\tworld"))
    }

    // MARK: - Nested Array Tests

    func testNestedIntArray() throws {
        let matrix: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        lua.globals["matrix"] = matrix

        let output = try lua.execute("""
            print("Row 1:", matrix[1][1], matrix[1][2], matrix[1][3])
            print("Row 2:", matrix[2][1], matrix[2][2], matrix[2][3])
            print("Row 3:", matrix[3][1], matrix[3][2], matrix[3][3])
        """)

        XCTAssertTrue(output.contains("Row 1:\t1\t2\t3"))
        XCTAssertTrue(output.contains("Row 2:\t4\t5\t6"))
        XCTAssertTrue(output.contains("Row 3:\t7\t8\t9"))
    }

    func testNestedStringArray() throws {
        let grid: [[String]] = [["a", "b"], ["c", "d"]]
        lua.globals["grid"] = grid

        let output = try lua.execute("""
            print(grid[1][1], grid[1][2])
            print(grid[2][1], grid[2][2])
        """)

        XCTAssertTrue(output.contains("a\tb"))
        XCTAssertTrue(output.contains("c\td"))
    }

    func testDeeplyNestedArray() throws {
        let deep: [[[Int]]] = [[[1, 2], [3, 4]], [[5, 6], [7, 8]]]
        lua.globals["deep"] = deep

        let output = try lua.execute("""
            print(deep[1][1][1], deep[1][1][2])
            print(deep[2][2][1], deep[2][2][2])
        """)

        XCTAssertTrue(output.contains("1\t2"))
        XCTAssertTrue(output.contains("7\t8"))
    }

    // MARK: - Dictionary Tests

    func testSimpleDictionary() throws {
        let person: [String: Any] = [
            "name": "Alice",
            "age": 30,
            "active": true
        ]
        lua.globals["person"] = person

        let output = try lua.execute("""
            print("Name:", person.name)
            print("Age:", person.age)
            print("Active:", person.active)
        """)

        XCTAssertTrue(output.contains("Name:\tAlice"))
        XCTAssertTrue(output.contains("Age:\t30"))
        XCTAssertTrue(output.contains("Active:\ttrue"))
    }

    func testDictionaryWithArrayValues() throws {
        let data: [String: Any] = [
            "scores": [95, 87, 92],
            "names": ["Alice", "Bob", "Carol"]
        ]
        lua.globals["data"] = data

        let output = try lua.execute("""
            print("Score 1:", data.scores[1])
            print("Name 2:", data.names[2])
        """)

        XCTAssertTrue(output.contains("Score 1:\t95"))
        XCTAssertTrue(output.contains("Name 2:\tBob"))
    }

    func testNestedDictionary() throws {
        let config: [String: Any] = [
            "database": [
                "host": "localhost",
                "port": 5432
            ] as [String: Any],
            "cache": [
                "enabled": true,
                "ttl": 3600
            ] as [String: Any]
        ]
        lua.globals["config"] = config

        let output = try lua.execute("""
            print("DB Host:", config.database.host)
            print("DB Port:", config.database.port)
            print("Cache TTL:", config.cache.ttl)
        """)

        XCTAssertTrue(output.contains("DB Host:\tlocalhost"))
        XCTAssertTrue(output.contains("DB Port:\t5432"))
        XCTAssertTrue(output.contains("Cache TTL:\t3600"))
    }

    // MARK: - Read Back Tests

    func testReadBackArray() throws {
        try lua.execute("""
            numbers = {10, 20, 30}
        """)

        let result = lua.globals["numbers"]
        XCTAssertNotNil(result)

        if let array = result as? [Any] {
            XCTAssertEqual(array.count, 3)
            XCTAssertEqual(array[0] as? Int, 10)
            XCTAssertEqual(array[1] as? Int, 20)
            XCTAssertEqual(array[2] as? Int, 30)
        } else {
            XCTFail("Expected array")
        }
    }

    func testReadBackNestedArray() throws {
        try lua.execute("""
            matrix = {{1, 2}, {3, 4}}
        """)

        let result = lua.globals["matrix"]
        XCTAssertNotNil(result)

        if let array = result as? [Any] {
            XCTAssertEqual(array.count, 2)
            if let row1 = array[0] as? [Any] {
                XCTAssertEqual(row1[0] as? Int, 1)
                XCTAssertEqual(row1[1] as? Int, 2)
            } else {
                XCTFail("Expected nested array for row 1")
            }
        } else {
            XCTFail("Expected array")
        }
    }

    func testReadBackDictionary() throws {
        try lua.execute("""
            person = {name = "Bob", age = 25}
        """)

        let result = lua.globals["person"]
        XCTAssertNotNil(result)

        if let dict = result as? [String: Any] {
            XCTAssertEqual(dict["name"] as? String, "Bob")
            XCTAssertEqual(dict["age"] as? Int, 25)
        } else {
            XCTFail("Expected dictionary")
        }
    }

    // MARK: - LuaCallable with Nested Collections

    func testCallableWithNestedArrayReturn() throws {
        try lua.execute("""
            function getMatrix()
                return {{1, 2, 3}, {4, 5, 6}}
            end
        """)

        let getMatrix = try lua.getFunction("getMatrix")
        let result: [[Int]] = try getMatrix.call()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], [1, 2, 3])
        XCTAssertEqual(result[1], [4, 5, 6])
    }

    func testCallableWithNestedArrayArg() throws {
        try lua.execute("""
            function sumMatrix(matrix)
                local total = 0
                for _, row in ipairs(matrix) do
                    for _, val in ipairs(row) do
                        total = total + val
                    end
                end
                return total
            end
        """)

        let sumMatrix = try lua.getFunction("sumMatrix")
        let matrix: [[Int]] = [[1, 2], [3, 4]]
        let result: Int = try sumMatrix.call(matrix)

        XCTAssertEqual(result, 10)
    }

    // MARK: - Mixed Type Arrays

    func testMixedTypeArray() throws {
        let mixed: [Any] = [1, "two", 3.0, true]
        lua.globals["mixed"] = mixed

        let output = try lua.execute("""
            print(mixed[1], mixed[2], mixed[3], mixed[4])
        """)

        XCTAssertTrue(output.contains("1\ttwo\t3.0\ttrue") || output.contains("1\ttwo\t3\ttrue"))
    }
}
