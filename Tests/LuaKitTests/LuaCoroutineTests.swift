//
//  LuaCoroutineTests.swift
//  LuaKitTests
//
//  Tests for LuaCoroutine functionality
//

import Lua
@testable import LuaKit
import XCTest

final class LuaCoroutineTests: XCTestCase {
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

    // MARK: - Creation Tests

    func testCreateCoroutineFromCode() throws {
        let coro = try lua.createCoroutine("""
            return 42
        """)

        XCTAssertTrue(coro.isValid)
        XCTAssertEqual(coro.status, .suspended)
    }

    func testCreateCoroutineFromFunction() throws {
        try lua.execute("""
            function myGenerator()
                return 100
            end
        """)

        let coro = try lua.createCoroutine(from: "myGenerator")
        XCTAssertTrue(coro.isValid)
        XCTAssertEqual(coro.status, .suspended)
    }

    func testCreateCoroutineFromCallable() throws {
        try lua.execute("""
            function producer()
                return "hello"
            end
        """)

        let callable = try lua.getFunction("producer")
        let coro = try LuaCoroutine(from: callable)
        XCTAssertTrue(coro.isValid)
        XCTAssertEqual(coro.status, .suspended)
    }

    func testCreateCoroutineSyntaxError() throws {
        XCTAssertThrowsError(try lua.createCoroutine("this is not valid lua {{{{")) { error in
            XCTAssertTrue(error is LuaError)
            if case LuaError.syntax = error {
                // Expected
            } else {
                XCTFail("Expected syntax error")
            }
        }
    }

    // MARK: - Resume Tests

    func testResumeSimpleReturn() throws {
        let coro = try lua.createCoroutine("""
            return 42
        """)

        let result: Int = try coro.resume()
        XCTAssertEqual(result, 42)
        XCTAssertEqual(coro.status, .dead)
    }

    func testResumeWithYield() throws {
        let coro = try lua.createCoroutine("""
            coroutine.yield(10)
            coroutine.yield(20)
            return 30
        """)

        let v1: Int = try coro.resume()
        XCTAssertEqual(v1, 10)
        XCTAssertEqual(coro.status, .suspended)

        let v2: Int = try coro.resume()
        XCTAssertEqual(v2, 20)
        XCTAssertEqual(coro.status, .suspended)

        let v3: Int = try coro.resume()
        XCTAssertEqual(v3, 30)
        XCTAssertEqual(coro.status, .dead)
    }

    func testResumeStringValues() throws {
        let coro = try lua.createCoroutine("""
            coroutine.yield("first")
            coroutine.yield("second")
            return "done"
        """)

        let v1: String = try coro.resume()
        XCTAssertEqual(v1, "first")

        let v2: String = try coro.resume()
        XCTAssertEqual(v2, "second")

        let v3: String = try coro.resume()
        XCTAssertEqual(v3, "done")
    }

    func testResumeWithArgument() throws {
        let coro = try lua.createCoroutine("""
            local x = ...
            return x * 2
        """)

        let result: Int = try coro.resume(21)
        XCTAssertEqual(result, 42)
    }

    func testResumeWithTwoArguments() throws {
        let coro = try lua.createCoroutine("""
            local a, b = ...
            return a + b
        """)

        let result: Int = try coro.resume(10, 20)
        XCTAssertEqual(result, 30)
    }

    func testResumeVoid() throws {
        let coro = try lua.createCoroutine("""
            counter = 0
            for i = 1, 3 do
                counter = counter + 1
                coroutine.yield()
            end
        """)

        try coro.resumeVoid()
        XCTAssertEqual(lua.globals["counter"] as? Int, 1)

        try coro.resumeVoid()
        XCTAssertEqual(lua.globals["counter"] as? Int, 2)

        try coro.resumeVoid()
        XCTAssertEqual(lua.globals["counter"] as? Int, 3)
    }

    func testResumeVoidWithArgument() throws {
        let coro = try lua.createCoroutine("""
            local sum = 0
            while true do
                local value = coroutine.yield()
                if value then
                    sum = sum + value
                    result = sum
                end
            end
        """)

        // First resume starts the coroutine
        try coro.resumeVoid()

        // Pass values
        try coro.resumeVoid(10)
        XCTAssertEqual(lua.globals["result"] as? Int, 10)

        try coro.resumeVoid(20)
        XCTAssertEqual(lua.globals["result"] as? Int, 30)

        try coro.resumeVoid(5)
        XCTAssertEqual(lua.globals["result"] as? Int, 35)
    }

    // MARK: - Generator Pattern Tests

    func testGeneratorPattern() throws {
        let coro = try lua.createCoroutine("""
            for i = 1, 5 do
                coroutine.yield(i * 10)
            end
            return 0  -- sentinel value
        """)

        var values: [Int] = []

        while coro.status == .suspended {
            let value: Int = try coro.resume()
            values.append(value)
        }

        XCTAssertEqual(values, [10, 20, 30, 40, 50, 0])
    }

    func testFibonacciGenerator() throws {
        let coro = try lua.createCoroutine("""
            local a, b = 0, 1
            for _ = 1, 10 do
                coroutine.yield(a)
                a, b = b, a + b
            end
            return -1  -- sentinel value indicating end
        """)

        var fibs: [Int] = []
        while coro.status == .suspended {
            let value: Int = try coro.resume()
            if value >= 0 {
                fibs.append(value)
            }
        }

        XCTAssertEqual(fibs, [0, 1, 1, 2, 3, 5, 8, 13, 21, 34])
    }

    // MARK: - Status Tests

    func testStatusTransitions() throws {
        let coro = try lua.createCoroutine("""
            coroutine.yield()
            return "done"
        """)

        XCTAssertEqual(coro.status, .suspended)

        try coro.resumeVoid()
        XCTAssertEqual(coro.status, .suspended)

        let _: String = try coro.resume()
        XCTAssertEqual(coro.status, .dead)
    }

    // MARK: - Error Handling Tests

    func testCoroutineRuntimeError() throws {
        let coro = try lua.createCoroutine("""
            error("Something went wrong!")
        """)

        XCTAssertThrowsError(try coro.resumeVoid()) { error in
            XCTAssertTrue(error is LuaError)
            if case LuaError.coroutineError(let message) = error {
                XCTAssertTrue(message.contains("Something went wrong!"))
            } else {
                XCTFail("Expected coroutineError")
            }
        }

        XCTAssertEqual(coro.status, .dead)
    }

    func testTypeMismatchOnResume() throws {
        let coro = try lua.createCoroutine("""
            return "not a number"
        """)

        XCTAssertThrowsError(try {
            let _: Int = try coro.resume()
        }()) { error in
            XCTAssertTrue(error is LuaError)
        }
    }

    // MARK: - Validity Tests

    func testIsValidWithActiveState() throws {
        let coro = try lua.createCoroutine("return 1")
        XCTAssertTrue(coro.isValid)
    }

    // MARK: - Multiple Coroutines Tests

    func testMultipleCoroutines() throws {
        let coro1 = try lua.createCoroutine("""
            coroutine.yield(1)
            return 2
        """)

        let coro2 = try lua.createCoroutine("""
            coroutine.yield(10)
            return 20
        """)

        let v1: Int = try coro1.resume()
        let v10: Int = try coro2.resume()

        XCTAssertEqual(v1, 1)
        XCTAssertEqual(v10, 10)

        let v2: Int = try coro1.resume()
        let v20: Int = try coro2.resume()

        XCTAssertEqual(v2, 2)
        XCTAssertEqual(v20, 20)
    }

    func testCoroutinesWithSharedState() throws {
        // Set up shared state
        lua.globals["shared"] = 0

        let coro1 = try lua.createCoroutine("""
            for i = 1, 3 do
                shared = shared + 1
                coroutine.yield(shared)
            end
        """)

        let coro2 = try lua.createCoroutine("""
            for i = 1, 3 do
                shared = shared + 10
                coroutine.yield(shared)
            end
        """)

        // Interleave execution
        let v1: Int = try coro1.resume()  // shared = 1
        let v2: Int = try coro2.resume()  // shared = 11
        let v3: Int = try coro1.resume()  // shared = 12
        let v4: Int = try coro2.resume()  // shared = 22

        XCTAssertEqual(v1, 1)
        XCTAssertEqual(v2, 11)
        XCTAssertEqual(v3, 12)
        XCTAssertEqual(v4, 22)
    }

    // MARK: - Sendable Tests

    func testCoroutineIsSendable() throws {
        let coro = try lua.createCoroutine("return 42")

        // This compiles if LuaCoroutine is properly Sendable
        let _: @Sendable () -> LuaCoroutine = { coro }

        let result: Int = try coro.resume()
        XCTAssertEqual(result, 42)
    }
}
