//
//  BasicTests.swift
//  LuaKitTests
//
//  Created by Barry Walker on 7/8/25.
//

import XCTest
@testable import LuaKit

final class BasicTests: XCTestCase {
    
    func testLuaStateCreation() throws {
        let lua = try LuaState()
        XCTAssertNotNil(lua)
    }
    
    func testBasicExecution() throws {
        let lua = try LuaState()
        
        var output = ""
        lua.setPrintHandler { text in
            output += text
        }
        
        _ = try lua.execute("print('Hello from Lua!')")
        XCTAssertEqual(output, "Hello from Lua!\n")
    }
    
    func testReturnValues() throws {
        let lua = try LuaState()
        
        let intResult = try lua.executeReturning("return 42", as: Int.self)
        XCTAssertEqual(intResult, 42)
        
        let doubleResult = try lua.executeReturning("return 3.14", as: Double.self)
        XCTAssertEqual(doubleResult, 3.14, accuracy: 0.001)
        
        let stringResult = try lua.executeReturning("return 'Hello'", as: String.self)
        XCTAssertEqual(stringResult, "Hello")
        
        let boolResult = try lua.executeReturning("return true", as: Bool.self)
        XCTAssertEqual(boolResult, true)
    }
    
    func testSyntaxError() throws {
        let lua = try LuaState()
        
        XCTAssertThrowsError(try lua.execute("invalid lua code")) { error in
            guard case LuaError.syntax = error else {
                XCTFail("Expected syntax error")
                return
            }
        }
    }
    
    func testRuntimeError() throws {
        let lua = try LuaState()
        
        XCTAssertThrowsError(try lua.execute("error('test error')")) { error in
            guard case LuaError.runtime(let message) = error else {
                XCTFail("Expected runtime error")
                return
            }
            XCTAssertTrue(message.contains("test error"))
        }
    }
    
    func testTypeMismatch() throws {
        let lua = try LuaState()
        
        XCTAssertThrowsError(try lua.executeReturning("return 'not a number'", as: Int.self)) { error in
            guard case LuaError.typeMismatch = error else {
                XCTFail("Expected type mismatch error")
                return
            }
        }
    }
    
    func testQuickStartExample() throws {
        // Test the exact Quick Start example from README
        let lua = try LuaState()
        
        // Execute Lua code
        try lua.execute("print('Hello from Lua!')")
        
        // Get values from Lua
        let result = try lua.executeReturning("return 2 + 2", as: Int.self)
        XCTAssertEqual(result, 4)
    }
    
    func testErrorHandlingDocumentationPattern() throws {
        // Test the exact error handling pattern shown in README
        let lua = try LuaState()
        
        do {
            try lua.execute("invalid lua code")
            XCTFail("Should have thrown syntax error")
        } catch LuaError.syntax(let message) {
            // Success - we caught the syntax error as documented
            XCTAssertFalse(message.isEmpty)
        } catch {
            XCTFail("Expected LuaError.syntax, got \(error)")
        }
        
        do {
            try lua.execute("error('test runtime error')")
            XCTFail("Should have thrown runtime error")
        } catch LuaError.runtime(let message) {
            // Success - we caught the runtime error as documented
            XCTAssertTrue(message.contains("test runtime error"))
        } catch {
            XCTFail("Expected LuaError.runtime, got \(error)")
        }
    }
}