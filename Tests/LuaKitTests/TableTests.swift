//
//  TableTests.swift
//  LuaKitTests
//
//  Created by Barry Walker on 7/8/25.
//

@testable import LuaKit
import XCTest

final class TableTests: XCTestCase {
    func testCreateTable() throws {
        let lua = try LuaState()

        let table = lua.createTable()
        XCTAssertNotNil(table)

        // Set values
        table["name"] = "John"
        table["age"] = 30
        table[1] = "first"
        table[2] = "second"

        // Set as global
        lua.globals.set("person", to: table)

        // Verify from Lua
        let name = try lua.execute("return person.name", returning: String.self)
        XCTAssertEqual(name, "John")

        let age = try lua.execute("return person.age", returning: Int.self)
        XCTAssertEqual(age, 30)

        let first = try lua.execute("return person[1]", returning: String.self)
        XCTAssertEqual(first, "first")

        let second = try lua.execute("return person[2]", returning: String.self)
        XCTAssertEqual(second, "second")
    }

    func testModifyTableFromLua() throws {
        let lua = try LuaState()

        let table = lua.createTable()
        table["value"] = 10
        lua.globals.set("myTable", to: table)

        // Modify from Lua
        _ = try lua.execute("""
            myTable.value = 20
            myTable.newKey = "newValue"
        """)

        // Verify changes
        if let value = table["value"] as? Int {
            XCTAssertEqual(value, 20)
        } else {
            XCTFail("Failed to get modified value")
        }

        if let newValue = table["newKey"] as? String {
            XCTAssertEqual(newValue, "newValue")
        } else {
            XCTFail("Failed to get new key")
        }
    }

    func testArrayLikeTable() throws {
        let lua = try LuaState()

        let array = lua.createTable()
        array[1] = "apple"
        array[2] = "banana"
        array[3] = "cherry"

        lua.globals.set("fruits", to: array)

        // Iterate in Lua
        var output = ""
        lua.onPrint { text in
            output += text
        }

        _ = try lua.execute("""
            for i = 1, 3 do
                print(fruits[i])
            end
        """)

        XCTAssertTrue(output.contains("apple"))
        XCTAssertTrue(output.contains("banana"))
        XCTAssertTrue(output.contains("cherry"))
    }
}
