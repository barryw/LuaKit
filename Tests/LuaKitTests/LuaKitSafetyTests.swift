//
//  LuaKitSafetyTests.swift
//  LuaKitTests
//
//  Regression tests for stack balance, lifetime, and edge-case conversion bugs.
//

import Lua
@testable import LuaKit
import XCTest

final class LuaKitSafetyTests: XCTestCase {
    func testPrintWithNoArgumentsDoesNotCrash() throws {
        let lua = try LuaState()

        let output = try lua.execute("print()")

        XCTAssertEqual(output, "\n")
    }

    func testExecuteDoesNotLeaveReturnValuesOnStack() throws {
        let lua = try LuaState()
        let initialTop = lua_gettop(lua.luaState)

        for _ in 0..<10 {
            _ = try lua.execute("return 1, 2, 3")
            XCTAssertEqual(lua_gettop(lua.luaState), initialTop)
        }
    }

    func testExecuteReturningTypeMismatchReportsActualType() throws {
        let lua = try LuaState()

        XCTAssertThrowsError(try lua.execute("return 'not a number'", returning: Int.self)) { error in
            guard case .typeMismatch(_, let actual, _) = error as? LuaError else {
                return XCTFail("Expected type mismatch, got \(error)")
            }
            XCTAssertEqual(actual, "string")
        }
    }

    func testLuaStateDeallocatesAfterPrintCaptureRegistration() throws {
        weak var weakState: LuaState?

        autoreleasepool {
            let state = try? LuaState()
            weakState = state
            _ = try? state?.execute("print('alive')")
        }

        XCTAssertNil(weakState)
    }

    func testLuaValuePullsTableFromPositiveIndex() throws {
        let state = try LuaState()
        let L = state.luaState

        lua_createtable(L, 0, 1)
        luaPushString(L, "value")
        lua_setfield(L, 1, "key")

        let value = LuaValue.pull(from: L, at: 1)

        XCTAssertEqual(value, .table(["key": .string("value")]))
        lua_pop(L, 1)
    }

    func testLuaFunctionUnsupportedReturnPushesNil() throws {
        struct UnsupportedReturn {}

        let lua = try LuaState()
        let function = LuaFunction { () -> UnsupportedReturn in
            UnsupportedReturn()
        }

        function.push(to: lua.luaState)
        XCTAssertEqual(lua_pcall(lua.luaState, 0, 1, 0), LUA_OK)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)
    }

    func testLuaTableSequenceVisitsEachEntryOnce() throws {
        let lua = try LuaState()
        try lua.execute("data = {a = 1, b = 2, c = 3}")

        let table = try XCTUnwrap(lua.getTable("data"))
        var found: [String: Double] = [:]

        for (key, value) in table {
            if case .string(let key) = key, case .number(let value) = value {
                found[key] = value
            }
        }

        XCTAssertEqual(found, ["a": 1, "b": 2, "c": 3])
    }

    func testStringConversionPreservesEmbeddedNullBytes() throws {
        let lua = try LuaState()

        let result = try lua.execute("return 'a\\0b'", returning: String.self)

        XCTAssertEqual(Array(result.utf8), [97, 0, 98])
    }

    func testStringPushPreservesEmbeddedNullBytes() throws {
        let lua = try LuaState()

        lua.globals["value"] = "a\u{0}b"
        let length = try lua.execute("return #value", returning: Int.self)

        XCTAssertEqual(length, 3)
    }
}
