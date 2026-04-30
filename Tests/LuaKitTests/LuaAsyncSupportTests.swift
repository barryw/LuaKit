//
//  LuaAsyncSupportTests.swift
//  LuaKit
//
//  Tests for LuaAsyncSupport functionality
//

import Foundation
@testable import LuaKit
import XCTest

/// Thread-safe capture helper for async test results
private final class AsyncResultCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var _result: Any?
    private var _error: Error?

    var result: Any? {
        lock.lock()
        defer { lock.unlock() }
        return _result
    }

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        return _error
    }

    func set(result: Any?, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        _result = result
        _error = error
    }
}

/// Thread-safe counter for testing
private final class AtomicCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
    }
}

/// Thread-safe boolean flag
private final class AtomicFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Bool = false

    var value: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func set(_ newValue: Bool) {
        lock.lock()
        defer { lock.unlock() }
        _value = newValue
    }
}

@MainActor
final class LuaAsyncSupportTests: XCTestCase {
    var lua: LuaState!

    override func setUp() async throws {
        try await super.setUp()
        lua = try LuaState()
    }

    override func tearDown() async throws {
        lua = nil
        try await super.tearDown()
    }

    // MARK: - LuaAsyncHandle Tests

    func testAsyncHandleCreation() {
        let handle = LuaAsyncHandle()
        XCTAssertNotNil(handle)
    }

    func testAsyncHandleCompletion() {
        let handle = LuaAsyncHandle()
        let expectation = self.expectation(description: "Async completion")

        let capture = AsyncResultCapture()

        handle.onComplete { result, error in
            capture.set(result: result, error: error)
            expectation.fulfill()
        }

        handle.complete(result: "Success", error: nil)

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertNotNil(capture.result)
            XCTAssertEqual(capture.result as? String, "Success")
            XCTAssertNil(capture.error)
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
        let callCounter = AtomicCounter()

        handle.onComplete { _, _ in
            callCounter.increment()
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
            XCTAssertEqual(callCounter.value, 1)
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
        _ = try? lua.execute("handleId = createAsyncHandle()")

        let handleId = lua.globals["handleId"] as? String ?? ""
        XCTAssertFalse(handleId.isEmpty)

        // Verify it's a valid UUID
        XCTAssertNotNil(UUID(uuidString: handleId))
    }

    func testCompleteAsyncFunction() {
        lua.registerAsyncSupport()

        // Create handle and set up completion
        do {
            _ = try lua.execute("testHandleId = createAsyncHandle()")
        } catch {
            XCTFail("Failed to execute Lua: \(error)")
            return
        }
        let handleId = lua.globals["testHandleId"] as? String ?? ""
        XCTAssertFalse(handleId.isEmpty, "Expected valid handle ID")
        let uuid = UUID(uuidString: handleId)!
        let handle = LuaAsyncRegistry.get(uuid)!

        let expectation = self.expectation(description: "Async completion via Lua")

        handle.onComplete { result, error in
            XCTAssertEqual(result as? String, "Test Result")
            XCTAssertNil(error)
            expectation.fulfill()
        }

        // Complete via Lua
        do {
            _ = try lua.execute("""
                completeAsync('\(handleId)', 'Test Result', nil)
            """)
        } catch {
            XCTFail("Failed to execute Lua: \(error)")
        }

        waitForExpectations(timeout: 1.0)

        // Verify handle was removed from registry
        XCTAssertNil(LuaAsyncRegistry.get(uuid))
    }

    func testCompleteAsyncWithError() {
        lua.registerAsyncSupport()

        do {
            _ = try lua.execute("errorHandleId = createAsyncHandle()")
        } catch {
            XCTFail("Failed to execute Lua: \(error)")
            return
        }
        let handleId = lua.globals["errorHandleId"] as? String ?? ""
        XCTAssertFalse(handleId.isEmpty, "Expected valid handle ID")
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
        do {
            _ = try lua.execute("""
                completeAsync('\(handleId)', nil, 'Test Error')
            """)
        } catch {
            XCTFail("Failed to execute Lua: \(error)")
        }

        waitForExpectations(timeout: 1.0)
    }

    func testCompleteAsyncInvalidHandle() {
        lua.registerAsyncSupport()

        // Should not crash with invalid handle ID
        do {
            _ = try lua.execute("""
                completeAsync('invalid-uuid', 'result', nil)
            """)
        } catch {
            XCTFail("Failed to execute Lua: \(error)")
        }

        // Also test with valid UUID that's not registered
        let fakeUuid = UUID().uuidString
        do {
            _ = try lua.execute("""
                completeAsync('\(fakeUuid)', 'result', nil)
            """)
        } catch {
            XCTFail("Failed to execute Lua: \(error)")
        }
    }

    // MARK: - LuaAsyncWrapper Tests

    func testAsyncWrapper() {
        let expectation = self.expectation(description: "Async wrapper")
        let didExecuteFlag = AtomicFlag()

        let asyncFunc: @Sendable () async throws -> String = {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            didExecuteFlag.set(true)
            return "Async Result"
        }

        let wrapped = LuaAsyncWrapper.wrap(asyncFunc)
        wrapped()

        // Wait for async execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertTrue(didExecuteFlag.value)
        }
    }

    func testAsyncWrapperWithError() {
        let expectation = self.expectation(description: "Async wrapper error")

        enum TestError: Error {
            case testError
        }

        let asyncFunc: @Sendable () async throws -> String = {
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
        lua.register(function: "delayedGreeting") { (name: String) -> String in
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
            handleId = delayedGreeting('Lua')
            -- In real usage, you'd set up a callback here
        """

        do {
            _ = try lua.execute(script)
        } catch {
            XCTFail("Failed to execute Lua: \(error)")
            return
        }

        // Get the handle ID from globals
        let handleId = lua.globals["handleId"] as? String ?? ""
        XCTAssertFalse(handleId.isEmpty, "Expected non-empty handle ID")
        XCTAssertNotNil(UUID(uuidString: handleId), "Expected valid UUID, got: '\(handleId)'")
    }

    func testAsyncPatternExample() {
        lua.registerAsyncSupport()

        // This demonstrates a pattern for async operations
        let expectation = self.expectation(description: "Async pattern")

        // Use a class box for thread-safe capture
        final class ResultBox: @unchecked Sendable {
            var value: String?
        }
        let resultBox = ResultBox()

        // Register a callback handler with a simple approach
        lua.register(function: "setAsyncCallback") { (handleId: String) in
            guard let uuid = UUID(uuidString: handleId),
                  let handle = LuaAsyncRegistry.get(uuid) else {
                return
            }

            handle.onComplete { result, error in
                if let result = result as? String {
                    resultBox.value = "Received: \(result)"
                } else if let error = error {
                    resultBox.value = "Error: \(error.localizedDescription)"
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

        do {
            _ = try lua.execute(script)
        } catch {
            XCTFail("Failed to execute Lua: \(error)")
        }

        waitForExpectations(timeout: 1.0) { _ in
            XCTAssertEqual(resultBox.value, "Received: Async Data")
        }
    }
}
