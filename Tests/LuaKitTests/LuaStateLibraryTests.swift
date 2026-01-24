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
        let result = try lua.executeReturning("return type(io)", as: String.self)
        XCTAssertEqual(result, "table")
    }

    func testSelectiveLibraryLoading() throws {
        let lua = try LuaState(libraries: [.base, .string])
        // string should be available
        let stringResult = try lua.executeReturning("return type(string)", as: String.self)
        XCTAssertEqual(stringResult, "table")
        // io should NOT be available
        let ioResult = try lua.executeReturning("return type(io)", as: String.self)
        XCTAssertEqual(ioResult, "nil")
    }

    func testSandboxedCannotAccessIO() throws {
        let lua = try LuaState(libraries: .sandboxed)
        let result = try lua.executeReturning("return type(io)", as: String.self)
        XCTAssertEqual(result, "nil")
    }

    func testSandboxedCannotAccessOS() throws {
        let lua = try LuaState(libraries: .sandboxed)
        let result = try lua.executeReturning("return type(os)", as: String.self)
        XCTAssertEqual(result, "nil")
    }

    func testEmptyLibrariesStillWorks() throws {
        let lua = try LuaState(libraries: [])
        // Even with no libraries, basic Lua should work
        let result = try lua.executeReturning("return 1 + 1", as: Int.self)
        XCTAssertEqual(result, 2)
    }

    func testSandboxedHasBasicFunctions() throws {
        let lua = try LuaState(libraries: .sandboxed)
        // Basic functions should work
        let result = try lua.executeReturning("return type('hello')", as: String.self)
        XCTAssertEqual(result, "string")
    }

    func testSandboxedHasStringLibrary() throws {
        let lua = try LuaState(libraries: .sandboxed)
        // String library should be available
        let result = try lua.executeReturning("return string.upper('hello')", as: String.self)
        XCTAssertEqual(result, "HELLO")
    }

    func testSandboxedHasMathLibrary() throws {
        let lua = try LuaState(libraries: .sandboxed)
        // Math library should be available
        let result = try lua.executeReturning("return math.abs(-42)", as: Int.self)
        XCTAssertEqual(result, 42)
    }

    func testSandboxedCannotAccessPackage() throws {
        let lua = try LuaState(libraries: .sandboxed)
        let result = try lua.executeReturning("return type(package)", as: String.self)
        XCTAssertEqual(result, "nil")
    }

    func testSandboxedCannotAccessDebug() throws {
        let lua = try LuaState(libraries: .sandboxed)
        let result = try lua.executeReturning("return type(debug)", as: String.self)
        XCTAssertEqual(result, "nil")
    }
}
