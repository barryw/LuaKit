//
//  LuaStateLibraryTests.swift
//  LuaKit
//
//  Created by Barry Walker on 1/23/26.
//

@testable import LuaKit
import XCTest

final class LuaStateLibraryTests: XCTestCase {
    func testDefaultInitLoadsAllLibraries() throws {
        let lua = try LuaState()
        // io library should be available
        let result = try lua.execute("return type(io)", returning: String.self)
        XCTAssertEqual(result, "table")
    }

    func testSelectiveLibraryLoading() throws {
        let lua = try LuaState(libraries: [.base, .string])
        // string should be available
        let stringResult = try lua.execute("return type(string)", returning: String.self)
        XCTAssertEqual(stringResult, "table")
        // io should NOT be available
        let ioResult = try lua.execute("return type(io)", returning: String.self)
        XCTAssertEqual(ioResult, "nil")
    }

    func testSandboxedCannotAccessIO() throws {
        let lua = try LuaState(libraries: .sandboxed)
        let result = try lua.execute("return type(io)", returning: String.self)
        XCTAssertEqual(result, "nil")
    }

    func testSandboxedCannotAccessOS() throws {
        let lua = try LuaState(libraries: .sandboxed)
        let result = try lua.execute("return type(os)", returning: String.self)
        XCTAssertEqual(result, "nil")
    }

    func testEmptyLibrariesStillWorks() throws {
        let lua = try LuaState(libraries: [])
        // Even with no libraries, basic Lua should work
        let result = try lua.execute("return 1 + 1", returning: Int.self)
        XCTAssertEqual(result, 2)
    }

    func testSandboxedHasBasicFunctions() throws {
        let lua = try LuaState(libraries: .sandboxed)
        // Basic functions should work
        let result = try lua.execute("return type('hello')", returning: String.self)
        XCTAssertEqual(result, "string")
    }

    func testSandboxedHasStringLibrary() throws {
        let lua = try LuaState(libraries: .sandboxed)
        // String library should be available
        let result = try lua.execute("return string.upper('hello')", returning: String.self)
        XCTAssertEqual(result, "HELLO")
    }

    func testSandboxedHasMathLibrary() throws {
        let lua = try LuaState(libraries: .sandboxed)
        // Math library should be available
        let result = try lua.execute("return math.abs(-42)", returning: Int.self)
        XCTAssertEqual(result, 42)
    }

    func testSandboxedCannotAccessPackage() throws {
        let lua = try LuaState(libraries: .sandboxed)
        let result = try lua.execute("return type(package)", returning: String.self)
        XCTAssertEqual(result, "nil")
    }

    func testSandboxedCannotAccessDebug() throws {
        let lua = try LuaState(libraries: .sandboxed)
        let result = try lua.execute("return type(debug)", returning: String.self)
        XCTAssertEqual(result, "nil")
    }
}
