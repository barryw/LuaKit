//
//  LuaCallbackTests.swift
//  LuaKitTests
//
//  Tests for LuaCallback functionality
//

import Lua
@testable import LuaKit
import XCTest

final class LuaCallbackTests: XCTestCase {
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

    func testCreateCallbackFromGlobal() throws {
        try lua.execute("""
            function myCallback()
                return 42
            end
        """)

        let callback = try lua.getCallback("myCallback")
        XCTAssertTrue(callback.isValid)
    }

    func testCreateCallbackFromStack() throws {
        try lua.execute("""
            function testFunc()
                return "hello"
            end
        """)

        lua_getglobal(lua.luaState, "testFunc")
        let callback = try lua.createCallback()
        XCTAssertTrue(callback.isValid)
    }

    func testCreateCallbackFromNonFunction() throws {
        lua.globals["notAFunc"] = 42

        XCTAssertThrowsError(try lua.getCallback("notAFunc")) { error in
            XCTAssertTrue(error is LuaError)
        }
    }

    func testCreateCallbackFromCallable() throws {
        try lua.execute("""
            function add(a, b)
                return a + b
            end
        """)

        let callable = try lua.getFunction("add")
        let callback = try LuaCallback(from: callable)
        XCTAssertTrue(callback.isValid)
    }

    // MARK: - Call with Return Value Tests

    func testCallNoArgs() throws {
        try lua.execute("""
            function getNumber()
                return 100
            end
        """)

        let callback = try lua.getCallback("getNumber")
        let result: Int = try callback.call()
        XCTAssertEqual(result, 100)
    }

    func testCallOneArg() throws {
        try lua.execute("""
            function double(x)
                return x * 2
            end
        """)

        let callback = try lua.getCallback("double")
        let result: Int = try callback.call(21)
        XCTAssertEqual(result, 42)
    }

    func testCallTwoArgs() throws {
        try lua.execute("""
            function add(a, b)
                return a + b
            end
        """)

        let callback = try lua.getCallback("add")
        let result: Int = try callback.call(10, 20)
        XCTAssertEqual(result, 30)
    }

    func testCallThreeArgs() throws {
        try lua.execute("""
            function concat(a, b, c)
                return a .. b .. c
            end
        """)

        let callback = try lua.getCallback("concat")
        let result: String = try callback.call("Hello", " ", "World")
        XCTAssertEqual(result, "Hello World")
    }

    func testCallReturningString() throws {
        try lua.execute("""
            function greet(name)
                return "Hello, " .. name .. "!"
            end
        """)

        let callback = try lua.getCallback("greet")
        let result: String = try callback.call("Swift")
        XCTAssertEqual(result, "Hello, Swift!")
    }

    func testCallReturningBool() throws {
        try lua.execute("""
            function isPositive(n)
                return n > 0
            end
        """)

        let callback = try lua.getCallback("isPositive")

        let result1: Bool = try callback.call(5)
        XCTAssertTrue(result1)

        let result2: Bool = try callback.call(-5)
        XCTAssertFalse(result2)
    }

    func testCallReturningDouble() throws {
        try lua.execute("""
            function divide(a, b)
                return a / b
            end
        """)

        let callback = try lua.getCallback("divide")
        let result: Double = try callback.call(10.0, 4.0)
        XCTAssertEqual(result, 2.5)
    }

    // MARK: - Call Void Tests

    func testCallVoidNoArgs() throws {
        try lua.execute("""
            counter = 0
            function increment()
                counter = counter + 1
            end
        """)

        let callback = try lua.getCallback("increment")
        try callback.callVoid()

        let counter = lua.globals["counter"] as? Int
        XCTAssertEqual(counter, 1)
    }

    func testCallVoidOneArg() throws {
        try lua.execute("""
            lastValue = 0
            function setLast(value)
                lastValue = value
            end
        """)

        let callback = try lua.getCallback("setLast")
        try callback.callVoid(42)

        let lastValue = lua.globals["lastValue"] as? Int
        XCTAssertEqual(lastValue, 42)
    }

    func testCallVoidTwoArgs() throws {
        try lua.execute("""
            storedSum = 0
            function storeSum(a, b)
                storedSum = a + b
            end
        """)

        let callback = try lua.getCallback("storeSum")
        try callback.callVoid(10, 20)

        let storedSum = lua.globals["storedSum"] as? Int
        XCTAssertEqual(storedSum, 30)
    }

    func testCallVoidThreeArgs() throws {
        try lua.execute("""
            storedConcat = ""
            function storeConcat(a, b, c)
                storedConcat = a .. b .. c
            end
        """)

        let callback = try lua.getCallback("storeConcat")
        try callback.callVoid("A", "B", "C")

        let storedConcat = lua.globals["storedConcat"] as? String
        XCTAssertEqual(storedConcat, "ABC")
    }

    func testCallVoidFourArgs() throws {
        try lua.execute("""
            storedProduct = 0
            function storeProduct(a, b, c, d)
                storedProduct = a * b * c * d
            end
        """)

        let callback = try lua.getCallback("storeProduct")
        try callback.callVoid(2, 3, 4, 5)

        let storedProduct = lua.globals["storedProduct"] as? Int
        XCTAssertEqual(storedProduct, 120)
    }

    // MARK: - Error Handling Tests

    func testCallWithRuntimeError() throws {
        try lua.execute("""
            function errorFunc()
                error("This is an error!")
            end
        """)

        let callback = try lua.getCallback("errorFunc")

        XCTAssertThrowsError(try callback.callVoid()) { error in
            XCTAssertTrue(error is LuaError)
            if case LuaError.runtime(let message) = error {
                XCTAssertTrue(message.contains("This is an error!"))
            }
        }
    }

    func testCallWithTypeMismatch() throws {
        try lua.execute("""
            function getString()
                return "not a number"
            end
        """)

        let callback = try lua.getCallback("getString")

        XCTAssertThrowsError(try {
            let _: Int = try callback.call()
        }()) { error in
            XCTAssertTrue(error is LuaError)
        }
    }

    // MARK: - Validity Tests

    func testIsValidWithActiveState() throws {
        try lua.execute("function test() end")
        let callback = try lua.getCallback("test")

        XCTAssertTrue(callback.isValid)
        XCTAssertNotNil(callback.state)
    }

    func testIsValidAfterStateDealloc() throws {
        weak var weakState: LuaState?
        var callback: LuaCallback?

        autoreleasepool {
            let state = try? LuaState()
            weakState = state
            _ = try? state?.execute("function testCallback() return 42 end")
            callback = try? state?.getCallback("testCallback")
        }

        XCTAssertNil(weakState)
        XCTAssertNotNil(callback)
        XCTAssertFalse(callback!.isValid)
        XCTAssertNil(callback!.state)
    }

    func testCallAfterStateDealloc() throws {
        var callback: LuaCallback?

        autoreleasepool {
            let state = try? LuaState()
            _ = try? state?.execute("function testCallback() return 42 end")
            callback = try? state?.getCallback("testCallback")
        }

        XCTAssertNotNil(callback)
        XCTAssertThrowsError(try callback!.call() as Int) { error in
            guard case LuaError.stateInvalid = error else {
                return XCTFail("Expected LuaError.stateInvalid, got \(error)")
            }
        }
    }

    // MARK: - Multiple Callback Tests

    func testMultipleCallbacks() throws {
        try lua.execute("""
            function add(a, b) return a + b end
            function multiply(a, b) return a * b end
            function subtract(a, b) return a - b end
        """)

        let add = try lua.getCallback("add")
        let multiply = try lua.getCallback("multiply")
        let subtract = try lua.getCallback("subtract")

        let sum: Int = try add.call(5, 3)
        let product: Int = try multiply.call(5, 3)
        let diff: Int = try subtract.call(5, 3)

        XCTAssertEqual(sum, 8)
        XCTAssertEqual(product, 15)
        XCTAssertEqual(diff, 2)
    }

    func testCallbackStoredAndCalledLater() throws {
        try lua.execute("""
            function createHandler(multiplier)
                return function(value)
                    return value * multiplier
                end
            end
        """)

        // Create a handler with multiplier 10
        // Push the result onto the stack
        lua_getglobal(lua.luaState, "createHandler")
        lua_pushinteger(lua.luaState, 10)
        XCTAssertEqual(lua_pcall(lua.luaState, 1, 1, 0), LUA_OK)

        // Create callback from the returned function
        let handler = try lua.createCallback()

        // Store it and call later
        let result: Int = try handler.call(5)
        XCTAssertEqual(result, 50)
    }

    // MARK: - Sendable Tests

    func testCallbackIsSendable() throws {
        try lua.execute("""
            function getAnswer()
                return 42
            end
        """)

        let callback = try lua.getCallback("getAnswer")

        // Test that callback can be used across task boundaries
        // This compiles if LuaCallback is properly Sendable
        let _: @Sendable () -> LuaCallback = { callback }

        let result: Int = try callback.call()
        XCTAssertEqual(result, 42)
    }
}
