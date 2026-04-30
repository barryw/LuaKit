//
//  Lua55FeatureTests.swift
//  LuaKit
//
//  Created by Barry Walker on 1/23/26.
//

@testable import LuaKit
import XCTest

/// Smoke tests verifying Lua 5.5 features work correctly
final class Lua55FeatureTests: XCTestCase {
    func testTableCreate() throws {
        let lua = try LuaState()
        // table.create is new in Lua 5.5
        let result = try lua.execute("""
            local t = table.create(10)
            return type(t)
        """, returning: String.self)
        XCTAssertEqual(result, "table")
    }

    func testTableCreateWithHashPart() throws {
        let lua = try LuaState()
        // table.create(nseq, nhash) - nseq is array size, nhash is hash size
        // It just pre-allocates space, doesn't fill with values
        let result = try lua.execute("""
            local t = table.create(5, 3)
            -- Table is created empty but with pre-allocated space
            -- Add some values to verify it works
            t[1] = 100
            t["key"] = "value"
            return t[1]
        """, returning: Int.self)
        XCTAssertEqual(result, 100)
    }

    func testLargeArraysWork() throws {
        let lua = try LuaState()
        // Lua 5.5 has ~60% smaller arrays
        let result = try lua.execute("""
            local t = {}
            for i = 1, 10000 do
                t[i] = i
            end
            return #t
        """, returning: Int.self)
        XCTAssertEqual(result, 10_000)
    }

    func testLuaVersionIs55() throws {
        let lua = try LuaState()
        let result = try lua.execute("return _VERSION", returning: String.self)
        XCTAssertEqual(result, "Lua 5.5")
    }
}
