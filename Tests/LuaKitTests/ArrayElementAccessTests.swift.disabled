//
//  ArrayElementAccessTests.swift
//  LuaKitTests
//
//  Tests for individual array element access from Lua
//

import Foundation
import Lua
@testable import LuaKit
import XCTest

@LuaBridgeable
class ColorPalette: LuaBridgeable, CustomStringConvertible {
    var name: String
    var colors: [String]

    init(name: String = "Untitled") {
        self.name = name
        self.colors = []
    }

    var description: String {
        return "ColorPalette('\(name)': \(colors.joined(separator: ", ")))"
    }
}

class ArrayElementAccessTests: XCTestCase {
    func testArrayElementAccess() throws {
        let lua = try LuaState()
        lua.register(ColorPalette.self, as: "ColorPalette")

        // Create a palette and test element access
        let output = try lua.execute("""
            local palette = ColorPalette.new("Rainbow")
            palette.colors = {"red", "orange", "yellow", "green", "blue", "indigo", "violet"}

            -- Test reading individual elements
            print("First color:", palette.colors[1])
            print("Third color:", palette.colors[3])
            print("Last color:", palette.colors[7])

            -- Test modifying individual elements
            palette.colors[1] = "crimson"
            palette.colors[3] = "gold"
            print("Modified colors:", palette.colors[1], palette.colors[3])

            -- Test array length
            print("Number of colors:", #palette.colors)

            -- Test iteration
            print("All colors:")
            for i, color in ipairs(palette.colors) do
                print(i, color)
            end
        """)

        XCTAssertTrue(output.contains("First color:\tred"))
        XCTAssertTrue(output.contains("Modified colors:\tcrimson\tgold"))
        XCTAssertTrue(output.contains("Number of colors:\t7"))
    }

    func testArrayElementAppend() throws {
        let lua = try LuaState()
        lua.register(ColorPalette.self, as: "ColorPalette")

        let output = try lua.execute("""
            local palette = ColorPalette.new("Basic")
            palette.colors = {"red", "green", "blue"}

            -- Append by setting at length + 1
            palette.colors[4] = "yellow"
            print("Length after append:", #palette.colors)
            print("New color:", palette.colors[4])

            -- Try to set beyond bounds (should fail)
            local success, err = pcall(function()
                palette.colors[10] = "purple"
            end)
            print("Out of bounds set success:", success)
        """)

        XCTAssertTrue(output.contains("Length after append:\t4"))
        XCTAssertTrue(output.contains("New color:\tyellow"))
        XCTAssertTrue(output.contains("Out of bounds set success:\tfalse"))
    }

    func testArrayProxyMethods() throws {
        let lua = try LuaState()
        lua.register(ColorPalette.self, as: "ColorPalette")

        let output = try lua.execute("""
            local palette = ColorPalette.new("Test")
            palette.colors = {"red", "green", "blue"}

            -- Test count property
            print("Count:", palette.colors.count)

            -- Note: toArray returns the array directly as a property
            -- We can still iterate and work with the proxy directly

            -- Test tostring
            print("String representation:", tostring(palette.colors))
        """)

        XCTAssertTrue(output.contains("Count:\t3"))
        XCTAssertTrue(output.contains("[\"red\", \"green\", \"blue\"]"))
    }

    func testAllArrayTypes() throws {
        let lua = try LuaState()

        // Test with a class that has all array types
        @LuaBridgeable
        class DataArrays: LuaBridgeable {
            var strings: [String] = []
            var integers: [Int] = []
            var doubles: [Double] = []
            var booleans: [Bool] = []

            init() {}

            var description: String {
                return "DataArrays(strings: \(strings.count), integers: \(integers.count), doubles: \(doubles.count), booleans: \(booleans.count))"
            }
        }

        lua.register(DataArrays.self, as: "DataArrays")

        let output = try lua.execute("""
            local data = DataArrays.new()

            -- Test string array
            data.strings = {"hello", "world"}
            data.strings[2] = "lua"
            print("Strings:", data.strings[1], data.strings[2])

            -- Test integer array
            data.integers = {10, 20, 30}
            data.integers[1] = 15
            print("Integers:", data.integers[1], data.integers[2])

            -- Test double array
            data.doubles = {1.1, 2.2, 3.3}
            data.doubles[3] = 3.14159
            print("Doubles:", data.doubles[3])

            -- Test boolean array
            data.booleans = {true, false, true}
            data.booleans[2] = true
            print("Booleans:", data.booleans[1], data.booleans[2], data.booleans[3])
        """)

        XCTAssertTrue(output.contains("Strings:\thello\tlua"))
        XCTAssertTrue(output.contains("Integers:\t15\t20"))
        XCTAssertTrue(output.contains("Doubles:\t3.14159"))
        XCTAssertTrue(output.contains("Booleans:\ttrue\ttrue\ttrue"))
    }
}
