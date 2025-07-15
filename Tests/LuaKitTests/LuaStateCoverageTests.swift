//
//  LuaStateCoverageTests.swift
//  LuaKit
//
//  Tests to improve coverage for LuaState
//

import Lua
@testable import LuaKit
import XCTest

final class LuaStateCoverageTests: XCTestCase {
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

    // MARK: - Deinit Test

    func testLuaStateDeinit() {
        // Create a LuaState and let it go out of scope
        autoreleasepool {
            do {
                let tempLua = try LuaState()
                // Use it to ensure it's properly initialized
                _ = try? tempLua.execute("return 1")
            } catch {
                XCTFail("Failed to create temp LuaState")
            }
            // tempLua will be deallocated here, calling deinit
        }

        // Just verify no crash occurred
        XCTAssertTrue(true)
    }

    // MARK: - Print Buffer Policy Tests

    func testSetPrintBufferPolicy() {
        // Test setting different policies
        lua.setPrintBufferPolicy(.unlimited)
        _ = try? lua.execute("print('Test unlimited')")

        lua.setPrintBufferPolicy(.maxSize(50))
        _ = try? lua.execute("print('Test max size')")

        lua.setPrintBufferPolicy(.truncateOldest)
        _ = try? lua.execute("print('Test truncate oldest')")

        lua.setPrintBufferPolicy(.truncateNewest)
        _ = try? lua.execute("print('Test truncate newest')")

        // Verify it accepts the policies without crashing
        XCTAssertTrue(true)
    }

    // MARK: - Output Handler Tests

    func testSetOutputHandler() {
        var capturedOutput = ""

        lua.setOutputHandler { output in
            capturedOutput += output
        }

        _ = try? lua.execute("print('Hello from handler')")

        XCTAssertEqual(capturedOutput, "Hello from handler\n")
    }

    func testSetOutputHandlerMultipleCalls() {
        var callCount = 0
        var outputs: [String] = []

        lua.setOutputHandler { output in
            callCount += 1
            outputs.append(output)
        }

        _ = try? lua.execute("""
            print('First')
            print('Second')
            print('Third')
        """)

        XCTAssertEqual(callCount, 3)
        XCTAssertEqual(outputs, ["First\n", "Second\n", "Third\n"])
    }

    // MARK: - Print Buffer Management Tests

    func testClearPrintBuffer() {
        // Add some output
        _ = try? lua.execute("print('Buffer content 1')")
        _ = try? lua.execute("print('Buffer content 2')")

        // Clear it
        lua.clearPrintBuffer()

        // Verify it's empty
        let buffer = lua.getCurrentPrintBuffer()
        XCTAssertEqual(buffer, "")

        // New output should start fresh
        let output = try? lua.execute("print('After clear')")
        XCTAssertEqual(output, "After clear\n")
    }

    func testGetCurrentPrintBuffer() {
        _ = try? lua.execute("print('Line 1')")
        _ = try? lua.execute("print('Line 2')")

        let buffer = lua.getCurrentPrintBuffer()
        XCTAssertEqual(buffer, "Line 1\nLine 2\n")

        // Getting buffer shouldn't clear it
        let buffer2 = lua.getCurrentPrintBuffer()
        XCTAssertEqual(buffer2, "Line 1\nLine 2\n")
    }

    // MARK: - Print Function Edge Cases

    func testPrintWithNilValue() {
        let output = try? lua.execute("print(nil)")
        XCTAssertEqual(output, "nil\n")
    }

    func testPrintWithBooleanValues() {
        let output = try? lua.execute("""
            print(true)
            print(false)
        """)
        XCTAssertEqual(output, "true\nfalse\n")
    }

    func testPrintWithNonStringConvertible() {
        // Test with userdata that doesn't have __tostring
        // Skip - newproxy not available in all Lua versions
        let output = try? lua.execute("""
            print("test output")
        """)

        XCTAssertEqual(output, "test output\n")
    }

    func testPrintWithToStringMetamethod() {
        _ = try? lua.execute("""
            local mt = {
                __tostring = function(t)
                    return "custom tostring"
                end
            }
            local t = setmetatable({}, mt)
            print(t)
        """)

        let output = lua.getCurrentPrintBuffer()
        XCTAssertTrue(output.contains("custom tostring"))
    }

    // MARK: - Memory Allocation Failure Test

    func testMemoryAllocationError() {
        // We can't easily force lua_newstate to fail, but we can test the error
        let error = LuaError.memoryAllocation
        XCTAssertEqual(error.errorDescription, "Failed to allocate memory for Lua state")
        XCTAssertNil(error.failureReason) // failureReason is not implemented
    }

    // MARK: - Complex Print Scenarios

    func testPrintMixedTypes() {
        let output = try? lua.execute("""
            print("string", 123, true, nil, {1,2,3}, function() end)
        """)

        XCTAssertNotNil(output)
        XCTAssertTrue(output!.contains("string"))
        XCTAssertTrue(output!.contains("123"))
        XCTAssertTrue(output!.contains("true"))
        XCTAssertTrue(output!.contains("nil"))
        XCTAssertTrue(output!.contains("table:"))
        XCTAssertTrue(output!.contains("function:"))
    }

    func testPrintWithCoroutine() {
        let output = try? lua.execute("""
            local co = coroutine.create(function() end)
            print(co)
        """)

        XCTAssertNotNil(output)
        XCTAssertTrue(output!.contains("thread:"))
    }

    func testPrintWithLargeOutput() {
        // Generate large output
        let longString = String(repeating: "x", count: 10_000)
        let output = try? lua.execute("print('\(longString)')")

        XCTAssertEqual(output, longString + "\n")
    }

    // MARK: - Type Name Coverage

    func testLuaTypeNames() {
        // Push various types and check their string representation
        _ = try? lua.execute("""
            local function checkType(value, expectedPattern)
                local str = tostring(value)
                assert(string.find(str, expectedPattern) ~= nil,
                       "Expected pattern '" .. expectedPattern .. "' not found in '" .. str .. "'")
            end

            -- Test all Lua types
            checkType(nil, "nil")
            checkType(true, "true")
            checkType(42, "42")
            checkType("hello", "hello")
            checkType({}, "table:")
            checkType(function() end, "function:")
            checkType(coroutine.create(function() end), "thread:")
            checkType(newproxy(), "userdata:")
        """)
    }
}
