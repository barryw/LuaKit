//
//  LuaTableSerializationTests.swift
//  LuaKitTests
//
//  Tests for LuaTable JSON/Codable serialization
//

import Foundation
import Lua
@testable import LuaKit
import XCTest

final class LuaTableSerializationTests: XCTestCase {
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

    // MARK: - toDictionary Tests

    func testToDictionarySimple() throws {
        try lua.execute("""
            config = {
                host = "localhost",
                port = 8080,
                enabled = true
            }
        """)

        let table = lua.getTable("config")!
        let dict = table.toDictionary()

        XCTAssertEqual(dict["host"] as? String, "localhost")
        XCTAssertEqual(dict["port"] as? Int, 8080)
        XCTAssertEqual(dict["enabled"] as? Bool, true)
    }

    func testToDictionaryNested() throws {
        try lua.execute("""
            data = {
                user = {
                    name = "Alice",
                    age = 30
                },
                settings = {
                    theme = "dark"
                }
            }
        """)

        let table = lua.getTable("data")!
        let dict = table.toDictionary()

        let user = dict["user"] as? [String: Any]
        XCTAssertNotNil(user)
        XCTAssertEqual(user?["name"] as? String, "Alice")
        XCTAssertEqual(user?["age"] as? Int, 30)

        let settings = dict["settings"] as? [String: Any]
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?["theme"] as? String, "dark")
    }

    func testToDictionaryWithArrays() throws {
        try lua.execute("""
            data = {
                numbers = {1, 2, 3},
                names = {"Alice", "Bob", "Charlie"}
            }
        """)

        let table = lua.getTable("data")!
        let dict = table.toDictionary()

        let numbers = dict["numbers"] as? [Any]
        XCTAssertNotNil(numbers)
        XCTAssertEqual(numbers?.count, 3)

        let names = dict["names"] as? [Any]
        XCTAssertNotNil(names)
        XCTAssertEqual(names?.count, 3)
    }

    // MARK: - toArray Tests

    func testToArraySimple() throws {
        try lua.execute("numbers = {10, 20, 30, 40, 50}")

        let table = lua.getTable("numbers")!
        let array = table.toArray()

        XCTAssertNotNil(array)
        XCTAssertEqual(array?.count, 5)
        XCTAssertEqual(array?[0] as? Int, 10)
        XCTAssertEqual(array?[4] as? Int, 50)
    }

    func testToArrayNested() throws {
        try lua.execute("matrix = {{1, 2}, {3, 4}}")

        let table = lua.getTable("matrix")!
        let array = table.toArray()

        XCTAssertNotNil(array)
        XCTAssertEqual(array?.count, 2)

        let row1 = array?[0] as? [Any]
        XCTAssertEqual(row1?[0] as? Int, 1)
        XCTAssertEqual(row1?[1] as? Int, 2)
    }

    func testToArrayReturnsNilForDictionary() throws {
        try lua.execute("dict = {a = 1, b = 2}")

        let table = lua.getTable("dict")!
        let array = table.toArray()

        XCTAssertNil(array)
    }

    // MARK: - toJSON Tests

    func testToJSONSimple() throws {
        try lua.execute("""
            config = {
                name = "test",
                value = 42
            }
        """)

        let table = lua.getTable("config")!
        let json = try table.toJSON()

        XCTAssertTrue(json.contains("\"name\""))
        XCTAssertTrue(json.contains("\"test\""))
        XCTAssertTrue(json.contains("\"value\""))
        XCTAssertTrue(json.contains("42"))
    }

    func testToJSONPrettyPrint() throws {
        try lua.execute("data = {a = 1, b = 2}")

        let table = lua.getTable("data")!
        let json = try table.toJSON(prettyPrint: true)

        XCTAssertTrue(json.contains("\n"))  // Pretty print includes newlines
    }

    func testToJSONNested() throws {
        try lua.execute("""
            data = {
                user = {
                    name = "Bob"
                },
                active = true
            }
        """)

        let table = lua.getTable("data")!
        let json = try table.toJSON()

        // Parse it back to verify structure
        let data = json.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(parsed)
        let user = parsed?["user"] as? [String: Any]
        XCTAssertEqual(user?["name"] as? String, "Bob")
        XCTAssertEqual(parsed?["active"] as? Bool, true)
    }

    // MARK: - loadJSON Tests

    func testLoadJSONString() throws {
        let json = """
        {
            "name": "Alice",
            "age": 25,
            "active": true
        }
        """

        try lua.loadJSON(json, as: "person")

        let table = lua.getTable("person")!
        XCTAssertEqual(table["name"] as? String, "Alice")
        XCTAssertEqual(table["age"] as? Int, 25)
        XCTAssertEqual(table["active"] as? Bool, true)
    }

    func testLoadJSONData() throws {
        let json = """
        {
            "items": [1, 2, 3],
            "count": 3
        }
        """
        let data = json.data(using: .utf8)!

        try lua.loadJSON(data, as: "result")

        let table = lua.getTable("result")!
        XCTAssertEqual(table["count"] as? Int, 3)

        // Access items array
        let items = table["items"] as? [Any]
        XCTAssertNotNil(items)
        XCTAssertEqual(items?.count, 3)
    }

    func testLoadJSONNested() throws {
        let json = """
        {
            "config": {
                "host": "localhost",
                "ports": [80, 443, 8080]
            }
        }
        """

        try lua.loadJSON(json, as: "settings")

        // Access nested table from Lua
        try lua.execute("host = settings.config.host")
        XCTAssertEqual(lua.globals["host"] as? String, "localhost")
    }

    func testLoadJSONInvalidThrows() throws {
        let invalidJSON = "{ not valid json }"

        XCTAssertThrowsError(try lua.loadJSON(invalidJSON, as: "bad"))
    }

    // MARK: - Codable Tests

    struct Person: Codable, Equatable {
        let name: String
        let age: Int
        let active: Bool
    }

    func testDecodePerson() throws {
        try lua.execute("""
            person = {
                name = "Charlie",
                age = 35,
                active = true
            }
        """)

        let person = try lua.decode("person", as: Person.self)

        XCTAssertEqual(person.name, "Charlie")
        XCTAssertEqual(person.age, 35)
        XCTAssertEqual(person.active, true)
    }

    func testEncodePerson() throws {
        let person = Person(name: "Diana", age: 28, active: false)

        try lua.encode(person, as: "encoded")

        let table = lua.getTable("encoded")!
        XCTAssertEqual(table["name"] as? String, "Diana")
        XCTAssertEqual(table["age"] as? Int, 28)
        XCTAssertEqual(table["active"] as? Bool, false)
    }

    struct Config: Codable, Equatable {
        let host: String
        let port: Int
        let tags: [String]
    }

    func testDecodeWithArray() throws {
        try lua.execute("""
            config = {
                host = "example.com",
                port = 3000,
                tags = {"prod", "api", "v2"}
            }
        """)

        let config = try lua.decode("config", as: Config.self)

        XCTAssertEqual(config.host, "example.com")
        XCTAssertEqual(config.port, 3000)
        XCTAssertEqual(config.tags, ["prod", "api", "v2"])
    }

    func testEncodeWithArray() throws {
        let config = Config(host: "test.local", port: 8080, tags: ["dev", "test"])

        try lua.encode(config, as: "serverConfig")

        let table = lua.getTable("serverConfig")!
        XCTAssertEqual(table["host"] as? String, "test.local")
        XCTAssertEqual(table["port"] as? Int, 8080)

        let tags = table["tags"] as? [Any]
        XCTAssertEqual(tags?.count, 2)
    }

    struct NestedData: Codable, Equatable {
        struct Inner: Codable, Equatable {
            let value: Int
        }
        let inner: Inner
        let name: String
    }

    func testDecodeNested() throws {
        try lua.execute("""
            nested = {
                inner = {
                    value = 42
                },
                name = "test"
            }
        """)

        let data = try lua.decode("nested", as: NestedData.self)

        XCTAssertEqual(data.name, "test")
        XCTAssertEqual(data.inner.value, 42)
    }

    func testDecodeNonExistentThrows() throws {
        XCTAssertThrowsError(try lua.decode("doesNotExist", as: Person.self))
    }

    // MARK: - Round-trip Tests

    func testRoundTripJSON() throws {
        // Create table in Lua
        try lua.execute("""
            original = {
                id = 123,
                name = "test",
                nested = {
                    flag = true
                }
            }
        """)

        // Convert to JSON
        let table = lua.getTable("original")!
        let json = try table.toJSON()

        // Load back as new table
        try lua.loadJSON(json, as: "restored")

        // Verify
        let restored = lua.getTable("restored")!
        XCTAssertEqual(restored["id"] as? Int, 123)
        XCTAssertEqual(restored["name"] as? String, "test")

        let nested = restored["nested"] as? [String: Any]
        XCTAssertEqual(nested?["flag"] as? Bool, true)
    }

    func testRoundTripCodable() throws {
        let original = Person(name: "Eve", age: 40, active: true)

        // Encode to Lua
        try lua.encode(original, as: "personData")

        // Decode back
        let decoded = try lua.decode("personData", as: Person.self)

        XCTAssertEqual(original, decoded)
    }
}
