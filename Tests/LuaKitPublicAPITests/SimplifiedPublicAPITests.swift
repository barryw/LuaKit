//
//  SimplifiedPublicAPITests.swift
//  LuaKitPublicAPITests
//
//  Simplified tests focusing on the core public API that should work
//  when imported normally (without @testable).
//

import XCTest
import LuaKit  // Note: NOT using @testable import

/// Simplified test suite that focuses on the essential public API
final class SimplifiedPublicAPITests: XCTestCase {
    
    // MARK: - Basic LuaState Tests
    
    func testLuaStateCreationAndExecution() throws {
        // Test that we can create a LuaState
        let lua = try LuaState()
        XCTAssertNotNil(lua)
        
        // Test basic execution
        _ = try lua.execute("x = 10")
        
        // Test execution with return value
        let result = try lua.executeReturning("return 42", as: Int.self)
        XCTAssertEqual(result, 42)
    }
    
    func testPrintCapture() throws {
        let lua = try LuaState()
        
        var capturedOutput = ""
        lua.setPrintHandler { output in
            capturedOutput = output
        }
        
        _ = try lua.execute("print('Hello from Lua')")
        XCTAssertEqual(capturedOutput.trimmingCharacters(in: .newlines), "Hello from Lua")
    }
    
    // MARK: - Type Conversion Tests
    
    func testBasicTypeConversions() throws {
        let lua = try LuaState()
        
        // Test different return types
        let intResult = try lua.executeReturning("return 42", as: Int.self)
        XCTAssertEqual(intResult, 42)
        
        let doubleResult = try lua.executeReturning("return 3.14", as: Double.self)
        XCTAssertEqual(doubleResult, 3.14, accuracy: 0.001)
        
        let stringResult = try lua.executeReturning("return 'test'", as: String.self)
        XCTAssertEqual(stringResult, "test")
        
        let boolResult = try lua.executeReturning("return true", as: Bool.self)
        XCTAssertEqual(boolResult, true)
    }
    
    // MARK: - Global Variable Tests
    
    func testGlobalVariableAccess() throws {
        let lua = try LuaState()
        
        // Set globals
        lua.globals["testNumber"] = 123
        lua.globals["testString"] = "hello"
        lua.globals["testBool"] = true
        
        // Verify from Lua
        let number = try lua.executeReturning("return testNumber", as: Int.self)
        XCTAssertEqual(number, 123)
        
        let string = try lua.executeReturning("return testString", as: String.self)
        XCTAssertEqual(string, "hello")
        
        let bool = try lua.executeReturning("return testBool", as: Bool.self)
        XCTAssertEqual(bool, true)
        
        // Test getting globals
        XCTAssertEqual(lua.globals["testNumber"] as? Int, 123)
        XCTAssertEqual(lua.globals["testString"] as? String, "hello")
        XCTAssertEqual(lua.globals["testBool"] as? Bool, true)
    }
    
    // MARK: - Array Tests
    
    func testArrayHandling() throws {
        let lua = try LuaState()
        
        // Arrays and dictionaries are not directly supported in lua.globals
        // This is a limitation of the current public API
        // Users would need to use LuaTable or other mechanisms
        
        // Test creating arrays in Lua and retrieving them
        _ = try lua.execute("numbers = {10, 20, 30, 40, 50}")
        
        // Verify array length from Lua
        let length = try lua.executeReturning("return #numbers", as: Int.self)
        XCTAssertEqual(length, 5)
        
        // Verify array elements (Lua arrays are 1-indexed)
        let first = try lua.executeReturning("return numbers[1]", as: Int.self)
        XCTAssertEqual(first, 10)
        
        let last = try lua.executeReturning("return numbers[5]", as: Int.self)
        XCTAssertEqual(last, 50)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() throws {
        let lua = try LuaState()
        
        // Test syntax error
        XCTAssertThrowsError(try lua.execute("invalid syntax")) { error in
            XCTAssertTrue(error is LuaError)
        }
        
        // Test runtime error
        XCTAssertThrowsError(try lua.execute("error('test error')")) { error in
            XCTAssertTrue(error is LuaError)
        }
    }
    
    // MARK: - LuaValue Tests
    
    func testLuaValueEnum() {
        // Test that we can create LuaValue instances
        let nilValue = LuaValue.nil
        let boolValue = LuaValue.boolean(true)
        let numberValue = LuaValue.number(42)
        let stringValue = LuaValue.string("test")
        let tableValue = LuaValue.table(["key": "value"])
        
        // Test equality
        XCTAssertEqual(LuaValue.nil, LuaValue.nil)
        XCTAssertEqual(LuaValue.boolean(true), LuaValue.boolean(true))
        XCTAssertEqual(LuaValue.number(42), LuaValue.number(42))
        XCTAssertEqual(LuaValue.string("test"), LuaValue.string("test"))
        
        // Test inequality
        XCTAssertNotEqual(LuaValue.boolean(true), LuaValue.boolean(false))
        XCTAssertNotEqual(LuaValue.number(42), LuaValue.number(43))
        
        // Verify all values were created
        XCTAssertNotNil(nilValue)
        XCTAssertNotNil(boolValue)
        XCTAssertNotNil(numberValue)
        XCTAssertNotNil(stringValue)
        XCTAssertNotNil(tableValue)
    }
    
    // MARK: - Table Tests
    
    func testTableOperations() throws {
        let lua = try LuaState()
        
        // Create a table from Lua since direct dictionary assignment is not supported
        _ = try lua.execute("""
            config = {
                host = "localhost",
                port = 8080,
                secure = true
            }
        """)
        
        // Access table values from Lua
        let host = try lua.executeReturning("return config.host", as: String.self)
        XCTAssertEqual(host, "localhost")
        
        let port = try lua.executeReturning("return config.port", as: Int.self)
        XCTAssertEqual(port, 8080)
        
        let secure = try lua.executeReturning("return config.secure", as: Bool.self)
        XCTAssertEqual(secure, true)
        
        // Test the createTable method if it's public
        let table = lua.createTable()
        // Note: We can't do much with the table without additional public API
        XCTAssertNotNil(table)
    }
}