//
//  LuaDebugTests.swift
//  LuaKit
//
//  Tests for LuaDebug functionality
//

@testable import LuaKit
import XCTest

final class LuaDebugTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset debug configuration before each test
        LuaDebugConfig.isEnabled = false
        LuaDebugConfig.logLevel = .info
        LuaDebugConfig.logger = nil
    }

    override func tearDown() {
        // Clean up after tests
        LuaPerformanceTracker.reset()
        super.tearDown()
    }

    // MARK: - LuaDebugConfig Tests

    func testDebugConfigDefaults() {
        XCTAssertFalse(LuaDebugConfig.isEnabled)
        XCTAssertEqual(LuaDebugConfig.logLevel, .info)
        XCTAssertNotNil(LuaDebugConfig.logger)
    }

    func testDebugLogging() {
        var capturedMessages: [(String, LuaDebugConfig.LogLevel)] = []

        LuaDebugConfig.logger = { message, level in
            capturedMessages.append((message, level))
        }

        LuaDebugConfig.isEnabled = true

        // Test different log levels
        LuaDebugConfig.log("Verbose message", level: .verbose)
        LuaDebugConfig.log("Info message", level: .info)
        LuaDebugConfig.log("Warning message", level: .warning)
        LuaDebugConfig.log("Error message", level: .error)

        // With default log level (.info), verbose should be filtered out
        XCTAssertEqual(capturedMessages.count, 3)
        XCTAssertTrue(capturedMessages[0].0.contains("Info message"))
        XCTAssertEqual(capturedMessages[0].1, .info)
        XCTAssertTrue(capturedMessages[1].0.contains("Warning message"))
        XCTAssertEqual(capturedMessages[1].1, .warning)
        XCTAssertTrue(capturedMessages[2].0.contains("Error message"))
        XCTAssertEqual(capturedMessages[2].1, .error)
    }

    func testLogLevelFiltering() {
        var capturedCount = 0
        LuaDebugConfig.logger = { _, _ in capturedCount += 1 }
        LuaDebugConfig.isEnabled = true

        // Set to error level - only error messages should pass
        LuaDebugConfig.logLevel = .error

        LuaDebugConfig.log("Verbose", level: .verbose)
        LuaDebugConfig.log("Info", level: .info)
        LuaDebugConfig.log("Warning", level: .warning)
        LuaDebugConfig.log("Error", level: .error)

        XCTAssertEqual(capturedCount, 1)
    }

    func testDebugDisabled() {
        var capturedCount = 0
        LuaDebugConfig.logger = { _, _ in capturedCount += 1 }
        LuaDebugConfig.isEnabled = false

        LuaDebugConfig.log("Should not log", level: .error)

        XCTAssertEqual(capturedCount, 0)
    }

    // MARK: - LuaDebuggable Tests

    class TestDebuggable: LuaDebuggable {
        var luaDebugEnabled = true
    }

    func testLuaDebuggable() {
        var capturedMessage: String?
        LuaDebugConfig.logger = { message, _ in
            capturedMessage = message
        }
        LuaDebugConfig.isEnabled = true

        let debuggable = TestDebuggable()
        debuggable.luaDebugLog("Test message")

        XCTAssertNotNil(capturedMessage)
        XCTAssertTrue(capturedMessage!.contains("[TestDebuggable]"))
        XCTAssertTrue(capturedMessage!.contains("Test message"))
    }

    func testLuaDebuggableDisabled() {
        var capturedCount = 0
        LuaDebugConfig.logger = { _, _ in capturedCount += 1 }
        LuaDebugConfig.isEnabled = true

        let debuggable = TestDebuggable()
        debuggable.luaDebugEnabled = false
        debuggable.luaDebugLog("Should not log")

        XCTAssertEqual(capturedCount, 0)
    }

    // MARK: - LuaMethodDebugContext Tests

    func testMethodDebugContextEntry() {
        var capturedMessage: String?
        LuaDebugConfig.logger = { message, _ in
            capturedMessage = message
        }
        LuaDebugConfig.isEnabled = true
        LuaDebugConfig.logLevel = .verbose

        let context = LuaMethodDebugContext(
            className: "TestClass",
            methodName: "testMethod",
            parameters: [("param1", "value1"), ("param2", "42")]
        )

        context.logEntry()

        XCTAssertNotNil(capturedMessage)
        XCTAssertTrue(capturedMessage!.contains("TestClass.testMethod"))
        XCTAssertTrue(capturedMessage!.contains("param1: value1"))
        XCTAssertTrue(capturedMessage!.contains("param2: 42"))
        XCTAssertTrue(capturedMessage!.contains("Started"))
    }

    func testMethodDebugContextExit() {
        var capturedMessage: String?
        LuaDebugConfig.logger = { message, _ in
            capturedMessage = message
        }
        LuaDebugConfig.isEnabled = true
        LuaDebugConfig.logLevel = .verbose

        let context = LuaMethodDebugContext(
            className: "TestClass",
            methodName: "testMethod"
        )

        // Add small delay to ensure measurable duration
        Thread.sleep(forTimeInterval: 0.01)

        context.logExit(result: "Success")

        XCTAssertNotNil(capturedMessage)
        XCTAssertTrue(capturedMessage!.contains("TestClass.testMethod"))
        XCTAssertTrue(capturedMessage!.contains("Completed in"))
        XCTAssertTrue(capturedMessage!.contains("ms"))
        XCTAssertTrue(capturedMessage!.contains("returned: Success"))
    }

    func testMethodDebugContextError() {
        var capturedMessage: String?
        var capturedLevel: LuaDebugConfig.LogLevel?
        LuaDebugConfig.logger = { message, level in
            capturedMessage = message
            capturedLevel = level
        }
        LuaDebugConfig.isEnabled = true

        let context = LuaMethodDebugContext(
            className: "TestClass",
            methodName: "testMethod"
        )

        context.logError("Something went wrong")

        XCTAssertNotNil(capturedMessage)
        XCTAssertTrue(capturedMessage!.contains("TestClass.testMethod"))
        XCTAssertTrue(capturedMessage!.contains("ERROR: Something went wrong"))
        XCTAssertEqual(capturedLevel, .error)
    }

    // MARK: - LuaPropertyDebugContext Tests

    func testPropertyDebugContextGetter() {
        var capturedMessage: String?
        LuaDebugConfig.logger = { message, _ in
            capturedMessage = message
        }
        LuaDebugConfig.isEnabled = true
        LuaDebugConfig.logLevel = .verbose

        let context = LuaPropertyDebugContext(
            className: "TestClass",
            propertyName: "testProperty",
            isGetter: true
        )

        context.logAccess(value: "propertyValue")

        XCTAssertNotNil(capturedMessage)
        XCTAssertTrue(capturedMessage!.contains("TestClass.testProperty"))
        XCTAssertTrue(capturedMessage!.contains("Read value: propertyValue"))
    }

    func testPropertyDebugContextSetter() {
        var capturedMessage: String?
        LuaDebugConfig.logger = { message, _ in
            capturedMessage = message
        }
        LuaDebugConfig.isEnabled = true
        LuaDebugConfig.logLevel = .verbose

        let context = LuaPropertyDebugContext(
            className: "TestClass",
            propertyName: "testProperty",
            isGetter: false
        )

        context.logAccess(value: "newValue")

        XCTAssertNotNil(capturedMessage)
        XCTAssertTrue(capturedMessage!.contains("TestClass.testProperty"))
        XCTAssertTrue(capturedMessage!.contains("Set value: newValue"))
    }

    func testPropertyValidationFailure() {
        var capturedMessage: String?
        var capturedLevel: LuaDebugConfig.LogLevel?
        LuaDebugConfig.logger = { message, level in
            capturedMessage = message
            capturedLevel = level
        }
        LuaDebugConfig.isEnabled = true

        let context = LuaPropertyDebugContext(
            className: "TestClass",
            propertyName: "age",
            isGetter: false
        )

        context.logValidationFailure(value: "-5", reason: "Age must be positive")

        XCTAssertNotNil(capturedMessage)
        XCTAssertTrue(capturedMessage!.contains("TestClass.age"))
        XCTAssertTrue(capturedMessage!.contains("Validation failed"))
        XCTAssertTrue(capturedMessage!.contains("'-5'"))
        XCTAssertTrue(capturedMessage!.contains("Age must be positive"))
        XCTAssertEqual(capturedLevel, .warning)
    }

    // MARK: - LuaPerformanceTracker Tests

    func testPerformanceTracking() {
        LuaDebugConfig.isEnabled = true

        // Track some method executions
        LuaPerformanceTracker.track(className: "TestClass", methodName: "method1", duration: 0.005)
        LuaPerformanceTracker.track(className: "TestClass", methodName: "method1", duration: 0.003)
        LuaPerformanceTracker.track(className: "TestClass", methodName: "method2", duration: 0.010)

        let report = LuaPerformanceTracker.report()

        XCTAssertTrue(report.contains("LuaKit Performance Report"))
        XCTAssertTrue(report.contains("TestClass.method1"))
        XCTAssertTrue(report.contains("2 calls"))
        XCTAssertTrue(report.contains("TestClass.method2"))
        XCTAssertTrue(report.contains("1 calls"))
    }

    func testPerformanceTrackingDisabled() {
        LuaDebugConfig.isEnabled = false

        LuaPerformanceTracker.track(className: "TestClass", methodName: "method1", duration: 0.005)

        let report = LuaPerformanceTracker.report()
        XCTAssertFalse(report.contains("TestClass.method1"))
    }

    func testPerformanceReset() {
        LuaDebugConfig.isEnabled = true

        LuaPerformanceTracker.track(className: "TestClass", methodName: "method1", duration: 0.005)
        LuaPerformanceTracker.reset()

        let report = LuaPerformanceTracker.report()
        XCTAssertFalse(report.contains("TestClass.method1"))
    }

    // MARK: - LuaMemoryTracker Tests

    func testMemoryTracking() {
        var capturedMessages: [String] = []
        LuaDebugConfig.logger = { message, _ in
            capturedMessages.append(message)
        }
        LuaDebugConfig.isEnabled = true
        LuaDebugConfig.logLevel = .verbose

        LuaMemoryTracker.trackAllocation("TestClass")
        LuaMemoryTracker.trackAllocation("TestClass")
        LuaMemoryTracker.trackAllocation("OtherClass")
        LuaMemoryTracker.trackDeallocation("TestClass")

        let report = LuaMemoryTracker.report()

        XCTAssertTrue(report.contains("LuaKit Memory Report"))
        XCTAssertTrue(report.contains("TestClass: 1 instances"))
        XCTAssertTrue(report.contains("OtherClass: 1 instances"))

        // Check log messages
        XCTAssertTrue(capturedMessages.contains { $0.contains("TestClass - Instance allocated (total: 1)") })
        XCTAssertTrue(capturedMessages.contains { $0.contains("TestClass - Instance allocated (total: 2)") })
        XCTAssertTrue(capturedMessages.contains { $0.contains("TestClass - Instance deallocated (remaining: 1)") })
    }

    // MARK: - LuaState Extension Tests

    func testLuaStateDebugExtensions() throws {
        let lua = try LuaState()

        // Test setDebugMode
        XCTAssertFalse(LuaDebugConfig.isEnabled)
        lua.setDebugMode(true)
        XCTAssertTrue(LuaDebugConfig.isEnabled)

        // Test setDebugLogLevel
        lua.setDebugLogLevel(.error)
        XCTAssertEqual(LuaDebugConfig.logLevel, .error)

        // Test performance report
        LuaPerformanceTracker.track(className: "Test", methodName: "method", duration: 0.001)
        let perfReport = lua.getPerformanceReport()
        XCTAssertTrue(perfReport.contains("Test.method"))

        // Test memory report
        LuaMemoryTracker.trackAllocation("TestClass")
        let memReport = lua.getMemoryReport()
        XCTAssertTrue(memReport.contains("TestClass"))

        // Test reset metrics
        lua.resetDebugMetrics()
        let emptyReport = lua.getPerformanceReport()
        XCTAssertFalse(emptyReport.contains("Test.method"))

        // Clean up
        lua.setDebugMode(false)
    }

    // MARK: - Thread Safety Tests

    func testPerformanceTrackerThreadSafety() {
        LuaDebugConfig.isEnabled = true

        let expectation = self.expectation(description: "Concurrent tracking")
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()

        // Perform many concurrent operations
        for index in 0..<100 {
            group.enter()
            queue.async {
                LuaPerformanceTracker.track(
                    className: "Class\(index % 10)",
                    methodName: "method\(index % 5)",
                    duration: Double(index) * 0.0001
                )
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let report = LuaPerformanceTracker.report()
            XCTAssertTrue(report.contains("Class"))
            XCTAssertTrue(report.contains("method"))
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    func testMemoryTrackerThreadSafety() {
        LuaDebugConfig.isEnabled = true

        let expectation = self.expectation(description: "Concurrent memory tracking")
        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        let group = DispatchGroup()

        // Perform many concurrent operations
        for index in 0..<100 {
            group.enter()
            queue.async {
                if index % 2 == 0 {
                    LuaMemoryTracker.trackAllocation("Class\(index % 10)")
                } else {
                    LuaMemoryTracker.trackDeallocation("Class\(index % 10)")
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let report = LuaMemoryTracker.report()
            // Report should be valid (not crash)
            XCTAssertTrue(report.contains("Memory Report"))
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }
}
