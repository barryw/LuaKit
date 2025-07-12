//
//  LuaIgnoreTest.swift
//  LuaKitTests
//
//  Testing @LuaIgnore functionality
//

import Lua
@testable import LuaKit
import XCTest

@LuaBridgeable
class TestIgnoreClass: LuaBridgeable {
    var visibleProperty: String = "visible"

    @LuaIgnore
    var ignoredProperty: String = "ignored"

    func visibleMethod() -> String {
        return "visible method"
    }

    @LuaIgnore
    func ignoredMethod() -> String {
        return "ignored method"
    }

    init() {}

    var description: String {
        return "TestIgnoreClass"
    }
}

final class LuaIgnoreTest: XCTestCase {
    func testLuaIgnoreAttribute() throws {
        let lua = try LuaState()
        lua.register(TestIgnoreClass.self, as: "TestIgnoreClass")

        var output = ""
        lua.setPrintHandler { text in
            output += text
        }

        _ = try lua.execute("""
            local obj = TestIgnoreClass.new()

            -- Test visible property
            print("Visible property:", obj.visibleProperty)

            -- Test visible method
            print("Visible method:", obj:visibleMethod())

            -- Test ignored property (in Lua, missing properties return nil, not error)
            if obj.ignoredProperty == nil then
                print("Good: ignoredProperty is nil (not bridged)")
            else
                print("ERROR: ignoredProperty has value:", obj.ignoredProperty)
            end

            -- Test ignored method (missing methods cause errors when called)
            local ok, err = pcall(function() return obj:ignoredMethod() end)
            if not ok then
                print("Good: ignoredMethod not accessible")
            else
                print("ERROR: ignoredMethod was accessible:", obj:ignoredMethod())
            end
        """)

        XCTAssertTrue(output.contains("visible"))  // Just check for the value, not the full line
        XCTAssertTrue(output.contains("visible method"))
        XCTAssertTrue(output.contains("Good: ignoredProperty is nil (not bridged)"))
        XCTAssertTrue(output.contains("Good: ignoredMethod not accessible"))
    }
}
