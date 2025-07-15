//
//  LuaErrorContextTests.swift
//  LuaKit
//
//  Tests for LuaErrorContext functionality
//

import Lua
@testable import LuaKit
import XCTest

final class LuaErrorContextTests: XCTestCase {
    var L: OpaquePointer!

    override func setUp() {
        super.setUp()
        L = luaL_newstate()
        luaL_openlibs(L)
    }

    override func tearDown() {
        lua_close(L)
        L = nil
        super.tearDown()
    }

    // MARK: - LuaErrorContext Tests

    func testErrorContextCreation() {
        let context = LuaErrorContext(
            functionName: "testFunction",
            argumentIndex: 1,
            expectedType: "number",
            actualType: "string",
            additionalInfo: "Value must be positive",
            hint: "Use tonumber() to convert string to number"
        )

        XCTAssertEqual(context.functionName, "testFunction")
        XCTAssertEqual(context.argumentIndex, 1)
        XCTAssertEqual(context.expectedType, "number")
        XCTAssertEqual(context.actualType, "string")
        XCTAssertEqual(context.additionalInfo, "Value must be positive")
        XCTAssertEqual(context.hint, "Use tonumber() to convert string to number")
    }

    func testErrorContextMessageGeneration() {
        let context = LuaErrorContext(
            functionName: "calculate",
            argumentIndex: 2,
            expectedType: "number",
            actualType: "table"
        )

        let message = context.generateMessage()
        XCTAssertTrue(message.contains("Error: Invalid argument #2 to 'calculate'"))
        XCTAssertTrue(message.contains("Expected: number"))
        XCTAssertTrue(message.contains("Got: table"))
    }

    func testErrorContextMessageWithoutArgumentIndex() {
        let context = LuaErrorContext(
            functionName: "process",
            expectedType: "string",
            actualType: "nil"
        )

        let message = context.generateMessage()
        XCTAssertTrue(message.contains("Error in 'process'"))
        XCTAssertTrue(message.contains("Expected: string"))
        XCTAssertTrue(message.contains("Got: nil"))
    }

    func testErrorContextMessageWithHint() {
        let context = LuaErrorContext(
            functionName: "parse",
            argumentIndex: 1,
            expectedType: "string",
            actualType: "number",
            additionalInfo: "Parser requires string input",
            hint: "Convert number to string using tostring()"
        )

        let message = context.generateMessage()
        XCTAssertTrue(message.contains("Parser requires string input"))
        XCTAssertTrue(message.contains("Hint: Convert number to string using tostring()"))
    }

    // MARK: - LuaKitError Tests

    func testInvalidArgumentError() {
        let context = LuaErrorContext(
            functionName: "testFunc",
            argumentIndex: 1,
            expectedType: "number",
            actualType: "string"
        )

        let error = LuaKitError.invalidArgument(context)
        let description = error.description

        XCTAssertTrue(description.contains("Invalid argument #1"))
        XCTAssertTrue(description.contains("testFunc"))
    }

    func testInvalidReturnTypeError() {
        let error = LuaKitError.invalidReturnType(
            expected: "string",
            got: "number",
            function: "getString"
        )

        let description = error.description
        XCTAssertTrue(description.contains("Invalid return type from 'getString'"))
        XCTAssertTrue(description.contains("Expected: string"))
        XCTAssertTrue(description.contains("Got: number"))
    }

    func testMissingRequiredParameterError() {
        let error = LuaKitError.missingRequiredParameter(
            parameter: "username",
            function: "login"
        )

        let description = error.description
        XCTAssertTrue(description.contains("Missing required parameter 'username'"))
        XCTAssertTrue(description.contains("function 'login'"))
    }

    func testValidationFailedError() {
        let error = LuaKitError.validationFailed(
            property: "age",
            value: -5,
            reason: "Age must be positive"
        )

        let description = error.description
        XCTAssertTrue(description.contains("Validation failed for property 'age'"))
        XCTAssertTrue(description.contains("Value: -5"))
        XCTAssertTrue(description.contains("Reason: Age must be positive"))
    }

    func testEnumConversionFailedError() {
        let error = LuaKitError.enumConversionFailed(
            type: "Direction",
            value: "northwest",
            validValues: ["north", "south", "east", "west"]
        )

        let description = error.description
        XCTAssertTrue(description.contains("Invalid value 'northwest' for enum type 'Direction'"))
        XCTAssertTrue(description.contains("Valid values: north, south, east, west"))
    }

    func testAsyncOperationFailedError() {
        let error = LuaKitError.asyncOperationFailed(
            function: "fetchData",
            reason: "Network timeout"
        )

        let description = error.description
        XCTAssertTrue(description.contains("Async operation 'fetchData' failed"))
        XCTAssertTrue(description.contains("Reason: Network timeout"))
    }

    // MARK: - OpaquePointer Extension Tests

    func testLuaTypeNameForBasicTypes() {
        // Test nil
        lua_pushnil(L)
        XCTAssertEqual(L.luaTypeName(at: -1), "nil")
        lua_pop(L, 1)

        // Test boolean
        lua_pushboolean(L, 1)
        XCTAssertEqual(L.luaTypeName(at: -1), "boolean")
        lua_pop(L, 1)

        // Test integer
        lua_pushinteger(L, 42)
        XCTAssertEqual(L.luaTypeName(at: -1), "integer")
        lua_pop(L, 1)

        // Test number
        lua_pushnumber(L, 3.14)
        XCTAssertEqual(L.luaTypeName(at: -1), "number")
        lua_pop(L, 1)

        // Test string
        lua_pushstring(L, "test")
        XCTAssertEqual(L.luaTypeName(at: -1), "string")
        lua_pop(L, 1)

        // Test table
        lua_newtable(L)
        XCTAssertEqual(L.luaTypeName(at: -1), "table")
        lua_pop(L, 1)

        // Test function
        lua_pushcclosure(L, { _ in 0 }, 0)
        XCTAssertEqual(L.luaTypeName(at: -1), "function")
        lua_pop(L, 1)
    }

    func testLuaTypeNameWithMetatable() {
        // Create a table with metatable
        lua_newtable(L)

        // Create metatable with __name
        lua_newtable(L)
        lua_pushstring(L, "MyCustomType")
        lua_setfield(L, -2, "__name")

        // Set metatable
        lua_setmetatable(L, -2)

        XCTAssertEqual(L.luaTypeName(at: -1), "MyCustomType")
        lua_pop(L, 1)
    }

    func testLuaValueDescription() {
        // Test nil
        lua_pushnil(L)
        XCTAssertEqual(L.luaValueDescription(at: -1), "nil")
        lua_pop(L, 1)

        // Test boolean true
        lua_pushboolean(L, 1)
        XCTAssertEqual(L.luaValueDescription(at: -1), "true")
        lua_pop(L, 1)

        // Test boolean false
        lua_pushboolean(L, 0)
        XCTAssertEqual(L.luaValueDescription(at: -1), "false")
        lua_pop(L, 1)

        // Test integer
        lua_pushinteger(L, 123)
        XCTAssertEqual(L.luaValueDescription(at: -1), "123")
        lua_pop(L, 1)

        // Test number
        lua_pushnumber(L, 45.67)
        XCTAssertEqual(L.luaValueDescription(at: -1), "45.67")
        lua_pop(L, 1)

        // Test string
        lua_pushstring(L, "hello")
        XCTAssertEqual(L.luaValueDescription(at: -1), "\"hello\"")
        lua_pop(L, 1)

        // Test table
        lua_newtable(L)
        XCTAssertEqual(L.luaValueDescription(at: -1), "table")
        lua_pop(L, 1)

        // Test function
        lua_pushcclosure(L, { _ in 0 }, 0)
        XCTAssertEqual(L.luaValueDescription(at: -1), "function")
        lua_pop(L, 1)
    }

    // MARK: - Type Validation Tests

    func testValidateLuaTypeSuccess() {
        lua_pushnumber(L, 42)

        let result = validateLuaType(
            L,
            at: -1,
            expectedTypes: [LUA_TNUMBER],
            functionName: "testFunc"
        )

        XCTAssertTrue(result)
        lua_pop(L, 1)
    }

    func testValidateLuaTypeMultipleTypes() {
        lua_pushstring(L, "test")

        let result = validateLuaType(
            L,
            at: -1,
            expectedTypes: [LUA_TNUMBER, LUA_TSTRING],
            functionName: "testFunc"
        )

        XCTAssertTrue(result)
        lua_pop(L, 1)
    }

    func testValidateLuaTypeFailure() {
        lua_pushstring(L, "not a number")

        // Wrap in pcall to catch the error
        lua_pushcclosure(L, { L in
            lua_pushstring(L!, "not a number")
            _ = validateLuaType(
                L!,
                at: -1,
                expectedTypes: [LUA_TNUMBER],
                functionName: "calculate",
                parameterName: "amount"
            )
            return 0
        }, 0)

        let result = lua_pcall(L, 0, 0, 0)
        XCTAssertNotEqual(result, 0) // Should have error

        if result != 0 {
            let error = String(cString: lua_tostring(L, -1)!)
            XCTAssertTrue(error.contains("calculate"))
            XCTAssertTrue(error.contains("amount"))
            lua_pop(L, 1)
        }
    }

    // MARK: - luaDetailedError Tests

    func testLuaDetailedError() {
        // Test in protected mode
        lua_pushcclosure(L, { L in
            _ = luaDetailedError(
                L!,
                functionName: "process",
                argumentIndex: 2,
                expectedType: "table",
                actualType: "string",
                additionalInfo: "Configuration table required",
                hint: "Pass a table with configuration options"
            )
            return 0
        }, 0)

        let result = lua_pcall(L, 0, 0, 0)
        XCTAssertNotEqual(result, 0)

        if result != 0 {
            let error = String(cString: lua_tostring(L, -1)!)
            XCTAssertTrue(error.contains("Invalid argument #2 to 'process'"))
            XCTAssertTrue(error.contains("Expected: table"))
            XCTAssertTrue(error.contains("Got: string"))
            XCTAssertTrue(error.contains("Configuration table required"))
            XCTAssertTrue(error.contains("Hint: Pass a table with configuration options"))
            lua_pop(L, 1)
        }
    }

    func testLuaDetailedErrorWithAutomaticType() {
        // Push a boolean value
        lua_pushboolean(L, 1)

        // Test in protected mode
        lua_pushcclosure(L, { L in
            lua_pushboolean(L!, 1)
            _ = luaDetailedError(
                L!,
                functionName: "calculate",
                argumentIndex: 1,
                expectedType: "number"
                // actualType will be determined automatically
            )
            return 0
        }, 0)

        let result = lua_pcall(L, 0, 0, 0)
        XCTAssertNotEqual(result, 0)

        if result != 0 {
            let error = String(cString: lua_tostring(L, -1)!)
            XCTAssertTrue(error.contains("Got: boolean"))
            lua_pop(L, 1)
        }
    }
}
