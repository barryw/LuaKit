//
//  LuaErrorTests.swift
//  LuaKit
//
//  Tests for LuaError enum
//

import XCTest
@testable import LuaKit

final class LuaErrorTests: XCTestCase {
    
    func testMemoryAllocationError() {
        let error = LuaError.memoryAllocation
        XCTAssertEqual(error.errorDescription, "Failed to allocate memory for Lua state")
        XCTAssertEqual(error.localizedDescription, "Failed to allocate memory for Lua state")
    }
    
    func testSyntaxError() {
        let errorMessage = "unexpected symbol near 'end'"
        let error = LuaError.syntax(errorMessage)
        XCTAssertEqual(error.errorDescription, "Lua syntax error: unexpected symbol near 'end'")
        XCTAssertEqual(error.localizedDescription, "Lua syntax error: unexpected symbol near 'end'")
    }
    
    func testRuntimeError() {
        let errorMessage = "attempt to index a nil value"
        let error = LuaError.runtime(errorMessage)
        XCTAssertEqual(error.errorDescription, "Lua runtime error: attempt to index a nil value")
        XCTAssertEqual(error.localizedDescription, "Lua runtime error: attempt to index a nil value")
    }
    
    func testTypeMismatchError() {
        let error = LuaError.typeMismatch(expected: "number", got: "string")
        XCTAssertEqual(error.errorDescription, "Type mismatch: expected number, got string")
        XCTAssertEqual(error.localizedDescription, "Type mismatch: expected number, got string")
    }
    
    func testInvalidArgumentError() {
        let message = "Function requires at least 2 arguments"
        let error = LuaError.invalidArgument(message)
        XCTAssertEqual(error.errorDescription, "Invalid argument: Function requires at least 2 arguments")
        XCTAssertEqual(error.localizedDescription, "Invalid argument: Function requires at least 2 arguments")
    }
    
    func testCustomError() {
        let customMessage = "Custom error occurred during processing"
        let error = LuaError.custom(customMessage)
        XCTAssertEqual(error.errorDescription, "Custom error occurred during processing")
        XCTAssertEqual(error.localizedDescription, "Custom error occurred during processing")
    }
    
    func testErrorEquality() {
        // Since LuaError doesn't conform to Equatable, we need to test using switch
        let error1 = LuaError.syntax("test")
        let error2 = LuaError.syntax("test")
        let error3 = LuaError.syntax("different")
        
        // Test same error types with same values
        switch (error1, error2) {
        case (.syntax(let msg1), .syntax(let msg2)):
            XCTAssertEqual(msg1, msg2)
        default:
            XCTFail("Expected both to be syntax errors")
        }
        
        // Test same error types with different values
        switch (error1, error3) {
        case (.syntax(let msg1), .syntax(let msg2)):
            XCTAssertNotEqual(msg1, msg2)
        default:
            XCTFail("Expected both to be syntax errors")
        }
        
        // Test different error types
        let runtimeError = LuaError.runtime("test")
        switch (error1, runtimeError) {
        case (.syntax(_), .runtime(_)):
            // Expected - different types
            break
        default:
            XCTFail("Expected different error types")
        }
    }
    
    func testErrorThrowingInContext() throws {
        // Test that LuaError can be thrown and caught properly
        func throwingFunction() throws {
            throw LuaError.runtime("test error")
        }
        
        XCTAssertThrowsError(try throwingFunction()) { error in
            guard let luaError = error as? LuaError else {
                XCTFail("Expected LuaError but got \(type(of: error))")
                return
            }
            
            if case .runtime(let message) = luaError {
                XCTAssertEqual(message, "test error")
            } else {
                XCTFail("Expected runtime error but got \(luaError)")
            }
        }
    }
    
    func testPatternMatching() {
        let errors: [LuaError] = [
            .memoryAllocation,
            .syntax("syntax issue"),
            .runtime("runtime issue"),
            .typeMismatch(expected: "bool", got: "nil"),
            .invalidArgument("bad arg"),
            .custom("custom")
        ]
        
        var counts = [
            "memory": 0,
            "syntax": 0,
            "runtime": 0,
            "typeMismatch": 0,
            "invalidArgument": 0,
            "custom": 0
        ]
        
        for error in errors {
            switch error {
            case .memoryAllocation:
                counts["memory"]! += 1
            case .syntax:
                counts["syntax"]! += 1
            case .runtime:
                counts["runtime"]! += 1
            case .typeMismatch:
                counts["typeMismatch"]! += 1
            case .invalidArgument:
                counts["invalidArgument"]! += 1
            case .custom:
                counts["custom"]! += 1
            }
        }
        
        XCTAssertEqual(counts["memory"], 1)
        XCTAssertEqual(counts["syntax"], 1)
        XCTAssertEqual(counts["runtime"], 1)
        XCTAssertEqual(counts["typeMismatch"], 1)
        XCTAssertEqual(counts["invalidArgument"], 1)
        XCTAssertEqual(counts["custom"], 1)
    }
}