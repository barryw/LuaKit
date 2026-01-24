//
//  LuaCallableTests.swift
//  LuaKitTests
//
//  Tests for LuaCallable - calling Lua functions from Swift
//

import Lua
@testable import LuaKit
import XCTest

final class LuaCallableTests: XCTestCase {
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

    // MARK: - Basic Function Lookup Tests

    func testGetGlobalFunction() throws {
        try lua.execute("""
            function greet()
                return "Hello"
            end
        """)

        let greet = try lua.getFunction("greet")
        XCTAssertNotNil(greet)
    }

    func testGetNonExistentFunction() throws {
        XCTAssertThrowsError(try lua.getFunction("nonExistent")) { error in
            guard case LuaError.functionNotFound = error else {
                XCTFail("Expected functionNotFound error, got \(error)")
                return
            }
        }
    }

    func testGetNonFunctionGlobal() throws {
        try lua.execute("notAFunction = 42")

        XCTAssertThrowsError(try lua.getFunction("notAFunction")) { error in
            guard case LuaError.functionNotFound(let message) = error else {
                XCTFail("Expected functionNotFound error, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("number"))
        }
    }

    // MARK: - Path-based Function Lookup Tests

    func testGetFunctionByPath() throws {
        try lua.execute("""
            Module = {
                submodule = {
                    greet = function(name)
                        return "Hello, " .. name
                    end
                }
            }
        """)

        let greet = try lua.getFunction(path: "Module.submodule.greet")
        let result: String = try greet.call("World")
        XCTAssertEqual(result, "Hello, World")
    }

    func testGetFunctionInvalidPath() throws {
        try lua.execute("Module = { value = 42 }")

        XCTAssertThrowsError(try lua.getFunction(path: "Module.value.func")) { error in
            guard case LuaError.functionNotFound(let message) = error else {
                XCTFail("Expected functionNotFound error, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("not a table"))
        }
    }

    // MARK: - Call with Return Value Tests

    func testCallNoArgs() throws {
        try lua.execute("""
            function getAnswer()
                return 42
            end
        """)

        let getAnswer = try lua.getFunction("getAnswer")
        let result: Int = try getAnswer.call()
        XCTAssertEqual(result, 42)
    }

    func testCallOneArg() throws {
        try lua.execute("""
            function double(n)
                return n * 2
            end
        """)

        let double = try lua.getFunction("double")
        let result: Int = try double.call(21)
        XCTAssertEqual(result, 42)
    }

    func testCallTwoArgs() throws {
        try lua.execute("""
            function add(a, b)
                return a + b
            end
        """)

        let add = try lua.getFunction("add")
        let result: Int = try add.call(10, 32)
        XCTAssertEqual(result, 42)
    }

    func testCallThreeArgs() throws {
        try lua.execute("""
            function combine(a, b, c)
                return a .. "-" .. b .. "-" .. c
            end
        """)

        let combine = try lua.getFunction("combine")
        let result: String = try combine.call("one", "two", "three")
        XCTAssertEqual(result, "one-two-three")
    }

    func testCallFourArgs() throws {
        try lua.execute("""
            function sum4(a, b, c, d)
                return a + b + c + d
            end
        """)

        let sum4 = try lua.getFunction("sum4")
        let result: Int = try sum4.call(1, 2, 3, 4)
        XCTAssertEqual(result, 10)
    }

    func testCallFiveArgs() throws {
        try lua.execute("""
            function sum5(a, b, c, d, e)
                return a + b + c + d + e
            end
        """)

        let sum5 = try lua.getFunction("sum5")
        let result: Int = try sum5.call(1, 2, 3, 4, 5)
        XCTAssertEqual(result, 15)
    }

    func testCallSixArgs() throws {
        try lua.execute("""
            function sum6(a, b, c, d, e, f)
                return a + b + c + d + e + f
            end
        """)

        let sum6 = try lua.getFunction("sum6")
        let result: Int = try sum6.call(1, 2, 3, 4, 5, 6)
        XCTAssertEqual(result, 21)
    }

    // MARK: - Call with Void Return Tests

    func testCallVoidNoArgs() throws {
        try lua.execute("""
            counter = 0
            function increment()
                counter = counter + 1
            end
        """)

        let increment = try lua.getFunction("increment")
        try increment.callVoid()

        XCTAssertEqual(lua.globals["counter"] as? Int, 1)
    }

    func testCallVoidWithArgs() throws {
        try lua.execute("""
            result = ""
            function setResult(value)
                result = value
            end
        """)

        let setResult = try lua.getFunction("setResult")
        try setResult.callVoid("Hello")

        XCTAssertEqual(lua.globals["result"] as? String, "Hello")
    }

    // MARK: - Type Conversion Tests

    func testCallWithDifferentTypes() throws {
        try lua.execute("""
            function format(name, age, score, active)
                return name .. " is " .. age .. " years old with score " .. score .. " (" .. tostring(active) .. ")"
            end
        """)

        let format = try lua.getFunction("format")
        let result: String = try format.call("Alice", 30, 95.5, true)
        XCTAssertEqual(result, "Alice is 30 years old with score 95.5 (true)")
    }

    func testCallReturningDouble() throws {
        try lua.execute("""
            function getPi()
                return 3.14159
            end
        """)

        let getPi = try lua.getFunction("getPi")
        let result: Double = try getPi.call()
        XCTAssertEqual(result, 3.14159, accuracy: 0.00001)
    }

    func testCallReturningBool() throws {
        try lua.execute("""
            function isPositive(n)
                return n > 0
            end
        """)

        let isPositive = try lua.getFunction("isPositive")

        let resultTrue: Bool = try isPositive.call(5)
        XCTAssertTrue(resultTrue)

        let resultFalse: Bool = try isPositive.call(-5)
        XCTAssertFalse(resultFalse)
    }

    // MARK: - Error Handling Tests

    func testCallWithRuntimeError() throws {
        try lua.execute("""
            function willFail()
                error("Something went wrong")
            end
        """)

        let willFail = try lua.getFunction("willFail")
        XCTAssertThrowsError(try willFail.callVoid()) { error in
            guard case LuaError.runtime(let message) = error else {
                XCTFail("Expected runtime error, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("Something went wrong"))
        }
    }

    func testCallWithTypeMismatch() throws {
        try lua.execute("""
            function getString()
                return "not a number"
            end
        """)

        let getString = try lua.getFunction("getString")
        XCTAssertThrowsError(try {
            let _: Int = try getString.call()
        }()) { error in
            guard case LuaError.typeMismatch = error else {
                XCTFail("Expected typeMismatch error, got \(error)")
                return
            }
        }
    }

    // MARK: - Multiple Calls Test

    func testMultipleCalls() throws {
        try lua.execute("""
            function factorial(n)
                if n <= 1 then return 1 end
                return n * factorial(n - 1)
            end
        """)

        let factorial = try lua.getFunction("factorial")

        let result1: Int = try factorial.call(5)
        XCTAssertEqual(result1, 120)

        let result2: Int = try factorial.call(6)
        XCTAssertEqual(result2, 720)

        let result3: Int = try factorial.call(1)
        XCTAssertEqual(result3, 1)
    }

    // MARK: - Array Return Tests

    func testCallReturningArray() throws {
        try lua.execute("""
            function getNumbers()
                return {1, 2, 3, 4, 5}
            end
        """)

        let getNumbers = try lua.getFunction("getNumbers")
        let result: [Int] = try getNumbers.call()
        XCTAssertEqual(result, [1, 2, 3, 4, 5])
    }

    func testCallWithArrayArg() throws {
        try lua.execute("""
            function sum(numbers)
                local total = 0
                for _, n in ipairs(numbers) do
                    total = total + n
                end
                return total
            end
        """)

        let sum = try lua.getFunction("sum")
        let result: Int = try sum.call([1, 2, 3, 4, 5])
        XCTAssertEqual(result, 15)
    }
}
