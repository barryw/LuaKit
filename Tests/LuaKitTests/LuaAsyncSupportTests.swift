//
//  LuaAsyncSupportTests.swift
//  LuaKit
//
//  Tests for LuaAsyncSupport functionality
//

import XCTest
@testable import LuaKit

final class LuaAsyncSupportTests: XCTestCase {
    var lua: LuaState!
    
    override func setUp() {
        super.setUp()
        lua = try! LuaState()
    }
    
    override func tearDown() {
        lua = nil
        super.tearDown()
    }
    
    // MARK: - LuaAsyncHandle Tests
    
    func testAsyncHandleCreation() {
        let handle = LuaAsyncHandle()
        XCTAssertNotNil(handle)
    }
    
    func testAsyncHandleCompletion() {
        let handle = LuaAsyncHandle()
        let expectation = self.expectation(description: "Async completion")
        
        var receivedResult: Any?
        var receivedError: Error?
        
        handle.onComplete { result, error in
            receivedResult = result
            receivedError = error
            expectation.fulfill()
        }
        
        handle.complete(result: "Success", error: nil)
        
        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertNotNil(receivedResult)
            XCTAssertEqual(receivedResult as? String, "Success")
            XCTAssertNil(receivedError)
        }
    }
    
    func testAsyncHandleCompletionWithError() {
        let handle = LuaAsyncHandle()
        let expectation = self.expectation(description: "Async error completion")
        
        let testError = NSError(domain: "TestDomain", code: 42, userInfo: nil)
        
        handle.onComplete { result, error in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            XCTAssertEqual((error as? NSError)?.code, 42)
            expectation.fulfill()
        }
        
        handle.complete(result: nil, error: testError)
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testAsyncHandleDoubleCompletion() {
        let handle = LuaAsyncHandle()
        var callCount = 0
        
        handle.onComplete { _, _ in
            callCount += 1
        }
        
        // First completion should work
        handle.complete(result: "First", error: nil)
        
        // Second completion should be ignored
        handle.complete(result: "Second", error: nil)
        
        // Give time for any async operations
        let expectation = self.expectation(description: "Wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertEqual(callCount, 1)
        }
    }
    
    func testAsyncHandleAlreadyCompleted() {
        let handle = LuaAsyncHandle()
        
        // Complete first
        handle.complete(result: "Done", error: nil)
        
        // Then set callback
        let expectation = self.expectation(description: "Already completed")
        
        handle.onComplete { result, error in
            // Should be called immediately with nil values when already completed
            XCTAssertNil(result)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - LuaAsyncRegistry Tests
    
    func testAsyncRegistry() {
        let handle1 = LuaAsyncHandle()
        let handle2 = LuaAsyncHandle()
        
        let id1 = LuaAsyncRegistry.register(handle1)
        let id2 = LuaAsyncRegistry.register(handle2)
        
        XCTAssertNotEqual(id1, id2)
        
        // Retrieve handles
        let retrieved1 = LuaAsyncRegistry.get(id1)
        let retrieved2 = LuaAsyncRegistry.get(id2)
        
        XCTAssertNotNil(retrieved1)
        XCTAssertNotNil(retrieved2)
        XCTAssertTrue(retrieved1 === handle1)
        XCTAssertTrue(retrieved2 === handle2)
        
        // Remove handle
        LuaAsyncRegistry.remove(id1)
        XCTAssertNil(LuaAsyncRegistry.get(id1))
        XCTAssertNotNil(LuaAsyncRegistry.get(id2))
        
        // Clean up
        LuaAsyncRegistry.remove(id2)
    }
    
    func testAsyncRegistryInvalidId() {
        let invalidId = UUID()
        XCTAssertNil(LuaAsyncRegistry.get(invalidId))
        
        // Removing invalid ID should not crash
        LuaAsyncRegistry.remove(invalidId)
    }
    
    // MARK: - LuaState Async Support Tests
    
    func testRegisterAsyncSupport() {
        lua.registerAsyncSupport()
        
        // Test createAsyncHandle function
        let handleId = try! lua.execute("return createAsyncHandle()")
        XCTAssertFalse(handleId.isEmpty)
        
        // Verify it's a valid UUID
        let trimmedId = handleId.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertNotNil(UUID(uuidString: trimmedId))
    }
    
    func testCompleteAsyncFunction() {
        lua.registerAsyncSupport()
        
        // Create handle and set up completion
        let handleId = try! lua.execute("return createAsyncHandle()").trimmingCharacters(in: .whitespacesAndNewlines)
        let uuid = UUID(uuidString: handleId)!
        let handle = LuaAsyncRegistry.get(uuid)!
        
        let expectation = self.expectation(description: "Async completion via Lua")
        
        handle.onComplete { result, error in
            XCTAssertEqual(result as? String, "Test Result")
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        // Complete via Lua
        _ = try! lua.execute("""
            completeAsync('\(handleId)', 'Test Result', nil)
        """)
        
        waitForExpectations(timeout: 1.0)
        
        // Verify handle was removed from registry
        XCTAssertNil(LuaAsyncRegistry.get(uuid))
    }
    
    func testCompleteAsyncWithError() {
        lua.registerAsyncSupport()
        
        let handleId = try! lua.execute("return createAsyncHandle()").trimmingCharacters(in: .whitespacesAndNewlines)
        let uuid = UUID(uuidString: handleId)!
        let handle = LuaAsyncRegistry.get(uuid)!
        
        let expectation = self.expectation(description: "Async error completion via Lua")
        
        handle.onComplete { result, error in
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.localizedDescription, "Test Error")
            expectation.fulfill()
        }
        
        // Complete with error via Lua
        _ = try! lua.execute("""
            completeAsync('\(handleId)', nil, 'Test Error')
        """)
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testCompleteAsyncInvalidHandle() {
        lua.registerAsyncSupport()
        
        // Should not crash with invalid handle ID
        _ = try! lua.execute("""
            completeAsync('invalid-uuid', 'result', nil)
        """)
        
        // Also test with valid UUID that's not registered
        let fakeUuid = UUID().uuidString
        _ = try! lua.execute("""
            completeAsync('\(fakeUuid)', 'result', nil)
        """)
    }
    
    // MARK: - LuaAsyncWrapper Tests
    
    func testAsyncWrapper() {
        let expectation = self.expectation(description: "Async wrapper")
        var didExecute = false
        
        let asyncFunc: () async throws -> String = {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            didExecute = true
            return "Async Result"
        }
        
        let wrapped = LuaAsyncWrapper.wrap(asyncFunc)
        wrapped()
        
        // Wait for async execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertTrue(didExecute)
        }
    }
    
    func testAsyncWrapperWithError() {
        let expectation = self.expectation(description: "Async wrapper error")
        
        enum TestError: Error {
            case testError
        }
        
        let asyncFunc: () async throws -> String = {
            throw TestError.testError
        }
        
        let wrapped = LuaAsyncWrapper.wrap(asyncFunc)
        wrapped()
        
        // Just verify it doesn't crash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - Integration Tests
    
    func testAsyncLuaIntegration() {
        lua.registerAsyncSupport()
        
        // Register an async Swift function
        lua.registerFunction("delayedGreeting") { (name: String) -> String in
            let handle = LuaAsyncHandle()
            let id = LuaAsyncRegistry.register(handle)
            
            // Simulate async operation
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                handle.complete(result: "Hello, \(name)!", error: nil)
                LuaAsyncRegistry.remove(id)
            }
            
            return id.uuidString
        }
        
        let script = """
            local handleId = delayedGreeting('Lua')
            -- In real usage, you'd set up a callback here
            return handleId
        """
        
        let result = try! lua.execute(script)
        let handleId = result.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertNotNil(UUID(uuidString: handleId))
    }
    
    func testAsyncPatternExample() {
        lua.registerAsyncSupport()
        
        // This demonstrates a pattern for async operations
        let expectation = self.expectation(description: "Async pattern")
        var luaCallbackResult: String?
        
        // Register a callback handler with a simple approach
        lua.registerFunction("setAsyncCallback") { (handleId: String) in
            guard let uuid = UUID(uuidString: handleId),
                  let handle = LuaAsyncRegistry.get(uuid) else {
                return
            }
            
            handle.onComplete { result, error in
                if let result = result as? String {
                    luaCallbackResult = "Received: \(result)"
                } else if let error = error {
                    luaCallbackResult = "Error: \(error.localizedDescription)"
                }
                expectation.fulfill()
            }
        }
        
        let script = """
            local handleId = createAsyncHandle()
            
            setAsyncCallback(handleId)
            
            -- Simulate async completion
            completeAsync(handleId, 'Async Data', nil)
            
            return handleId
        """
        
        _ = try! lua.execute(script)
        
        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertEqual(luaCallbackResult, "Received: Async Data")
        }
    }
}