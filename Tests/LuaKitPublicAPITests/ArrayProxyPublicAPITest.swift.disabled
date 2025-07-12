//
//  ArrayProxyPublicAPITest.swift
//  Test array proxy functionality using only public API
//
//  IMPORTANT: This file imports LuaKit WITHOUT @testable
//  to ensure the public API works for external consumers
//

import Lua
import LuaKit  // NOT @testable - testing public API only
import XCTest

class ArrayProxyPublicAPITest: XCTestCase {
    func testArrayElementAccessFromPublicAPI() throws {
        // This test verifies that array element access works
        // when using LuaKit as an external dependency

        let lua = try LuaState()

        // Define a class as an external consumer would
        @LuaBridgeable
        class ColorPalette: LuaBridgeable {
            var name: String
            var colors: [String]

            init(name: String = "Untitled") {
                self.name = name
                self.colors = []
            }

            var description: String {
                return "ColorPalette(\(name): \(colors.count) colors)"
            }
        }

        // Register the class
        lua.register(ColorPalette.self, as: "ColorPalette")

        // This is the exact scenario that was failing in 1.1.0
        let output = try lua.execute("""
            -- Create a palette
            local palette = ColorPalette.new("TestPalette")

            -- Set initial colors
            palette.colors = {"red", "green", "blue"}
            print("Initial count:", #palette.colors)

            -- THIS WAS FAILING IN 1.1.0 due to internal initializer
            palette.colors[1] = "crimson"
            palette.colors[2] = "lime"
            palette.colors[3] = "navy"

            print("After modifications:")
            for i, color in ipairs(palette.colors) do
                print(i, color)
            end

            -- Test appending
            palette.colors[#palette.colors + 1] = "yellow"
            print("After append:", #palette.colors, "colors")

            return true
        """)

        // Verify the test ran successfully
        XCTAssertTrue(output.contains("crimson"))
        XCTAssertTrue(output.contains("lime"))
        XCTAssertTrue(output.contains("navy"))
        XCTAssertTrue(output.contains("4\tcolors"))
    }

    func testAllArrayTypes() throws {
        let lua = try LuaState()

        @LuaBridgeable
        class DataContainer: LuaBridgeable {
            var strings: [String] = []
            var integers: [Int] = []
            var doubles: [Double] = []
            var booleans: [Bool] = []

            init() {}

            var description: String {
                return "DataContainer"
            }
        }

        lua.register(DataContainer.self, as: "DataContainer")

        let output = try lua.execute("""
            local data = DataContainer.new()

            -- Test each array type
            data.strings = {"a", "b", "c"}
            data.strings[2] = "B"

            data.integers = {1, 2, 3}
            data.integers[3] = 30

            data.doubles = {1.1, 2.2, 3.3}
            data.doubles[1] = 10.5

            data.booleans = {true, false, true}
            data.booleans[2] = true

            print("Strings:", data.strings[1], data.strings[2], data.strings[3])
            print("Integers:", data.integers[1], data.integers[2], data.integers[3])
            print("Doubles:", data.doubles[1])
            print("Booleans:", data.booleans[1], data.booleans[2], data.booleans[3])

            return true
        """)

        XCTAssertTrue(output.contains("Strings:\ta\tB\tc"))
        XCTAssertTrue(output.contains("Integers:\t1\t2\t30"))
        XCTAssertTrue(output.contains("Doubles:\t10.5"))
        XCTAssertTrue(output.contains("Booleans:\ttrue\ttrue\ttrue"))
    }

    func testArrayProxyIsAccessible() throws {
        // This test specifically verifies that the array proxy
        // initializer is public and can be accessed by macro-generated code

        let lua = try LuaState()

        @LuaBridgeable
        class TestClass: LuaBridgeable {
            var items: [String] = []
            init() {}
            var description: String { return "TestClass" }
        }

        lua.register(TestClass.self, as: "TestClass")

        // If the initializer is internal, this will fail with:
        // "LuaStringArrayProxy initializer is inaccessible due to 'internal' protection level"
        _ = try lua.execute("""
            local obj = TestClass.new()
            obj.items = {"test"}
            obj.items[1] = "modified"  -- This line triggers proxy creation
            return obj.items[1]
        """)

        // If we get here, the fix is working
        XCTAssertTrue(true, "Array proxy initializer is accessible")
    }
}
