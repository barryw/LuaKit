//
//  LuaArrayProxySimpleTests.swift
//  LuaKit
//
//  Simplified tests for LuaArrayProxy functionality
//

import Lua
@testable import LuaKit
import XCTest

// Simple test class
class TestOwner {
    var strings: [String] = ["a", "b", "c"]
    var numbers: [Int] = [1, 2, 3]
    var doubles: [Double] = [1.1, 2.2, 3.3]
    var bools: [Bool] = [true, false, true]
}

final class LuaArrayProxySimpleTests: XCTestCase {
    var lua: LuaState!
    var owner: TestOwner!

    override func setUp() {
        super.setUp()
        do {
            lua = try LuaState()
            owner = TestOwner()
        } catch {
            XCTFail("Failed to create LuaState: \(error)")
        }
    }

    override func tearDown() {
        lua = nil
        owner = nil
        super.tearDown()
    }

    // MARK: - Basic Proxy Tests

    func testStringArrayProxy() {
        let proxy = LuaStringArrayProxy(
            owner: owner,
            propertyName: "strings",
            getter: { self.owner.strings },
            setter: { self.owner.strings = $0 }
        )

        // Test length
        XCTAssertEqual(proxy.getLength(), 3)

        // Test get element (1-based indexing)
        XCTAssertEqual(proxy.getElement(at: 1), "a")
        XCTAssertEqual(proxy.getElement(at: 2), "b")
        XCTAssertEqual(proxy.getElement(at: 3), "c")

        // Test out of bounds
        XCTAssertNil(proxy.getElement(at: 0))
        XCTAssertNil(proxy.getElement(at: 4))

        // Test set element
        do {
            try proxy.setElement(at: 2, to: "B")
            XCTAssertEqual(owner.strings, ["a", "B", "c"])
        } catch {
            XCTFail("Failed to set element: \(error)")
        }

        // Test append (set at count + 1)
        do {
            try proxy.setElement(at: 4, to: "d")
            XCTAssertEqual(owner.strings, ["a", "B", "c", "d"])
        } catch {
            XCTFail("Failed to append element: \(error)")
        }

        // Test toArray
        XCTAssertEqual(proxy.toArray(), ["a", "B", "c", "d"])

        // Test description
        XCTAssertTrue(proxy.description.contains("LuaArrayProxy<String>"))
        XCTAssertTrue(proxy.description.contains("4 elements"))
    }

    func testIntArrayProxy() {
        let proxy = LuaIntArrayProxy(
            owner: owner,
            propertyName: "numbers",
            getter: { self.owner.numbers },
            setter: { self.owner.numbers = $0 }
        )

        XCTAssertEqual(proxy.getLength(), 3)
        XCTAssertEqual(proxy.getElement(at: 1), 1)
        XCTAssertEqual(proxy.getElement(at: 2), 2)
        XCTAssertEqual(proxy.getElement(at: 3), 3)

        do {
            try proxy.setElement(at: 1, to: 10)
            XCTAssertEqual(owner.numbers, [10, 2, 3])
        } catch {
            XCTFail("Failed to set element: \(error)")
        }
    }

    func testDoubleArrayProxy() {
        let proxy = LuaDoubleArrayProxy(
            owner: owner,
            propertyName: "doubles",
            getter: { self.owner.doubles },
            setter: { self.owner.doubles = $0 }
        )

        XCTAssertEqual(proxy.getLength(), 3)
        XCTAssertEqual(proxy.getElement(at: 1), 1.1)
        XCTAssertEqual(proxy.getElement(at: 2), 2.2)
        XCTAssertEqual(proxy.getElement(at: 3), 3.3)

        do {
            try proxy.setElement(at: 3, to: 9.9)
            XCTAssertEqual(owner.doubles, [1.1, 2.2, 9.9])
        } catch {
            XCTFail("Failed to set element: \(error)")
        }
    }

    func testBoolArrayProxy() {
        let proxy = LuaBoolArrayProxy(
            owner: owner,
            propertyName: "bools",
            getter: { self.owner.bools },
            setter: { self.owner.bools = $0 }
        )

        XCTAssertEqual(proxy.getLength(), 3)
        XCTAssertEqual(proxy.getElement(at: 1), true)
        XCTAssertEqual(proxy.getElement(at: 2), false)
        XCTAssertEqual(proxy.getElement(at: 3), true)

        do {
            try proxy.setElement(at: 2, to: true)
            XCTAssertEqual(owner.bools, [true, true, true])
        } catch {
            XCTFail("Failed to set element: \(error)")
        }
    }

    // MARK: - Validation Tests

    func testValidation() {
        let proxy = LuaStringArrayProxy(
            owner: owner,
            propertyName: "strings",
            getter: { self.owner.strings },
            setter: { self.owner.strings = $0 },
            validator: { array in
                if array.contains("invalid") {
                    return .failure(PropertyValidationError("'invalid' is not allowed"))
                }
                return .success(())
            }
        )

        // Valid set should work
        do {
            try proxy.setElement(at: 1, to: "valid")
            XCTAssertEqual(owner.strings[0], "valid")
        } catch {
            XCTFail("Valid set failed: \(error)")
        }

        // Invalid set should fail
        do {
            try proxy.setElement(at: 1, to: "invalid")
            XCTFail("Should have thrown validation error")
        } catch {
            // Just check that we got an error
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Bounds Checking Tests

    func testBoundsChecking() {
        let proxy = LuaStringArrayProxy(
            owner: owner,
            propertyName: "strings",
            getter: { self.owner.strings },
            setter: { self.owner.strings = $0 }
        )

        // Test negative index
        do {
            try proxy.setElement(at: 0, to: "fail")
            XCTFail("Should have thrown bounds error")
        } catch {
            // Just check that we got an error
            XCTAssertNotNil(error)
        }

        // Test too large index
        do {
            try proxy.setElement(at: 10, to: "fail")
            XCTFail("Should have thrown bounds error")
        } catch {
            // Just check that we got an error
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Empty Array Tests

    func testEmptyArrayOperations() {
        owner.strings = []
        let proxy = LuaStringArrayProxy(
            owner: owner,
            propertyName: "strings",
            getter: { self.owner.strings },
            setter: { self.owner.strings = $0 }
        )

        XCTAssertEqual(proxy.getLength(), 0)
        XCTAssertNil(proxy.getElement(at: 1))

        // Test append to empty
        do {
            try proxy.setElement(at: 1, to: "first")
            XCTAssertEqual(owner.strings, ["first"])
        } catch {
            XCTFail("Failed to append to empty array: \(error)")
        }
    }

    // MARK: - Performance Tests

    func testLargeArrayPerformance() {
        // Create a large array
        var largeArray = [String]()
        for index in 0..<1_000 {
            largeArray.append("item\(index)")
        }

        owner.strings = largeArray
        let proxy = LuaStringArrayProxy(
            owner: owner,
            propertyName: "strings",
            getter: { self.owner.strings },
            setter: { self.owner.strings = $0 }
        )

        // Test access performance
        measure {
            _ = proxy.getElement(at: 500)
            _ = proxy.getLength()
        }
    }
}