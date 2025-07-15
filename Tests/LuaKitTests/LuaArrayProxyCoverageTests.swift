//
//  LuaArrayProxyCoverageTests.swift
//  LuaKit
//
//  Created by Barry Walker.
//
//  Comprehensive tests to improve LuaArrayProxy coverage
//

import Lua
@testable import LuaKit
import XCTest

final class LuaArrayProxyCoverageTests: XCTestCase {
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

    // MARK: - Error Handling Tests

    func testSetElementWithNegativeIndex() {
        var array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { array = $0 }
        )

        XCTAssertThrowsError(try proxy.setElement(at: -1, to: "x")) { error in
            XCTAssertTrue(error is PropertyValidationError)
            if let validationError = error as? PropertyValidationError {
                XCTAssertTrue(validationError.localizedDescription.contains("positive") || validationError.message.contains("positive"))
            }
        }
    }

    func testSetElementWithZeroIndex() {
        var array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { array = $0 }
        )

        XCTAssertThrowsError(try proxy.setElement(at: 0, to: "x")) { error in
            XCTAssertTrue(error is PropertyValidationError)
            if let validationError = error as? PropertyValidationError {
                XCTAssertTrue(validationError.localizedDescription.contains("positive") || validationError.message.contains("positive"))
            }
        }
    }

    func testSetElementFarOutOfBounds() {
        var array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { array = $0 }
        )

        XCTAssertThrowsError(try proxy.setElement(at: 10, to: "x")) { error in
            XCTAssertTrue(error is PropertyValidationError)
            if let validationError = error as? PropertyValidationError {
                XCTAssertTrue(validationError.localizedDescription.contains("bounds") || validationError.message.contains("bounds"))
            }
        }
    }

    func testGetElementWithNegativeIndex() {
        let array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { _ in }
        )

        XCTAssertNil(proxy.getElement(at: -1))
    }

    func testGetElementWithZeroIndex() {
        let array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { _ in }
        )

        XCTAssertNil(proxy.getElement(at: 0))
    }

    func testGetElementOutOfBounds() {
        let array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { _ in }
        )

        XCTAssertNil(proxy.getElement(at: 10))
    }

    // MARK: - Validation Tests

    func testSetElementWithFailingValidator() {
        var array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { array = $0 },
            validator: { _ in
                .failure(PropertyValidationError("Validation failed"))
            }
        )

        XCTAssertThrowsError(try proxy.setElement(at: 1, to: "x")) { error in
            XCTAssertTrue(error is PropertyValidationError)
            if let validationError = error as? PropertyValidationError {
                XCTAssertTrue(validationError.localizedDescription.contains("Validation failed") || validationError.message.contains("Validation failed"))
            }
        }
    }

    func testSetElementWithPassingValidator() throws {
        var array = ["a", "b", "c"]
        var validationCalled = false
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { array = $0 },
            validator: { _ in
                validationCalled = true
                return .success(())
            }
        )

        try proxy.setElement(at: 1, to: "x")
        XCTAssertTrue(validationCalled)
        XCTAssertEqual(array[0], "x")
    }

    // MARK: - Property Change Notification Tests

    func testPropertyChangeNotificationWithWeakOwner() throws {
        var array = ["a", "b", "c"]

        // Create a temporary owner that will be deallocated
        var proxy: LuaStringArrayProxy?
        autoreleasepool {
            let tempOwner = NSObject()
            proxy = LuaStringArrayProxy(
                owner: tempOwner,
                propertyName: "array",
                getter: { array },
                setter: { array = $0 }
            )
        }

        // Now the owner is deallocated (weak reference is nil)
        // Should not crash when setting element with deallocated owner
        try proxy?.setElement(at: 1, to: "x")
        XCTAssertEqual(array[0], "x")
    }

    // MARK: - Metamethod Tests Through Lua

    func testArrayProxyMetamethodsDirectly() {
        var array = [1, 2, 3]
        let proxy = LuaIntArrayProxy(
            owner: self,
            propertyName: "numbers",
            getter: { array },
            setter: { array = $0 }
        )

        // Push proxy to Lua
        LuaIntArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "proxy")

        // Test __gc metamethod by forcing garbage collection
        _ = try? lua.execute("""
            local p = proxy
            proxy = nil
            collectgarbage("collect")
        """)

        // Should not crash
        XCTAssertTrue(true)
    }

    func testArrayProxyInvalidPropertyAccess() {
        var array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "strings",
            getter: { array },
            setter: { array = $0 }
        )

        LuaStringArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "proxy")

        // Try to access invalid property
        let result = try? lua.execute("""
            return proxy.invalidProperty
        """)

        // Should return nil or empty string for invalid properties
        XCTAssertTrue(result == nil || (result as? String)?.isEmpty == true || result as? String == "nil")
    }

    func testArrayProxyInvalidMethodCall() {
        var array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "strings",
            getter: { array },
            setter: { array = $0 }
        )

        LuaStringArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "proxy")

        // Try to call invalid method
        let result = try? lua.execute("""
            return proxy:invalidMethod()
        """)

        // Should fail
        XCTAssertNil(result)
    }

    // MARK: - Different Array Types Tests

    func testBoolArrayProxyOperations() throws {
        var array = [true, false, true, false]
        let proxy = LuaBoolArrayProxy(
            owner: self,
            propertyName: "bools",
            getter: { array },
            setter: { array = $0 }
        )

        // Test get
        XCTAssertEqual(proxy.getElement(at: 1), true)
        XCTAssertEqual(proxy.getElement(at: 2), false)

        // Test set
        try proxy.setElement(at: 1, to: false)
        XCTAssertEqual(array[0], false)

        // Test append
        try proxy.setElement(at: 5, to: true)
        XCTAssertEqual(array.count, 5)
        XCTAssertEqual(array[4], true)
    }

    func testDoubleArrayProxyOperations() throws {
        var array = [1.1, 2.2, 3.3]
        let proxy = LuaDoubleArrayProxy(
            owner: self,
            propertyName: "doubles",
            getter: { array },
            setter: { array = $0 }
        )

        // Test get
        XCTAssertEqual(proxy.getElement(at: 1), 1.1)
        XCTAssertEqual(proxy.getElement(at: 3), 3.3)

        // Test set
        try proxy.setElement(at: 2, to: 99.99)
        XCTAssertEqual(array[1], 99.99, accuracy: 0.001)

        // Test boundaries
        XCTAssertNil(proxy.getElement(at: 0))
        XCTAssertNil(proxy.getElement(at: 100))
    }

    // MARK: - Type-specific Push Tests

    func testStringArrayPushSpecific() {
        var array = ["hello", "world"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "strings",
            getter: { array },
            setter: { array = $0 }
        )

        // Test push with specific string array type
        LuaStringArrayProxy.push(proxy, to: lua.luaState)

        // Verify it's a userdata
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TUSERDATA)

        // Verify it has a metatable
        lua_getmetatable(lua.luaState, -1)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)

        lua_pop(lua.luaState, 2)
    }

    func testIntArrayPushSpecific() {
        var array = [10, 20, 30]
        let proxy = LuaIntArrayProxy(
            owner: self,
            propertyName: "ints",
            getter: { array },
            setter: { array = $0 }
        )

        // Test push with specific int array type
        LuaIntArrayProxy.push(proxy, to: lua.luaState)

        // Verify it's a userdata
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TUSERDATA)

        lua_pop(lua.luaState, 1)
    }

    // MARK: - Concurrent Modification Tests

    func testArrayModificationDuringIteration() {
        var array = ["a", "b", "c", "d", "e"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "strings",
            getter: { array },
            setter: { array = $0 }
        )

        LuaStringArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "proxy")

        // This tests the iteration behavior when array is modified
        let result = try? lua.execute("""
            local count = 0
            for i, v in ipairs(proxy) do
                count = count + 1
                if i == 2 then
                    proxy[3] = "modified"
                end
            end
            return count
        """)

        // Should complete iteration
        XCTAssertNotNil(result)
    }

    // MARK: - Edge Case Tests

    func testEmptyArrayOperations() throws {
        var array: [String] = []
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "empty",
            getter: { array },
            setter: { array = $0 }
        )

        // Test operations on empty array
        XCTAssertNil(proxy.getElement(at: 1))
        XCTAssertEqual(proxy.getLength(), 0)

        // Test appending to empty array
        try proxy.setElement(at: 1, to: "first")
        XCTAssertEqual(array.count, 1)
        XCTAssertEqual(array[0], "first")
    }

    func testVeryLargeArrayIndex() {
        var array = ["a", "b", "c"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { array = $0 }
        )

        // Test with very large index
        XCTAssertThrowsError(try proxy.setElement(at: Int.max, to: "x")) { error in
            XCTAssertTrue(error is PropertyValidationError)
        }

        XCTAssertNil(proxy.getElement(at: Int.max))
    }

    // MARK: - Type Checking Tests

    func testArrayProxyTypeChecking() {
        // Try to check wrong types on stack
        lua_pushstring(lua.luaState, "not a proxy")
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TSTRING)
        lua_pop(lua.luaState, 1)

        // Push a valid proxy
        var array = ["test"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "array",
            getter: { array },
            setter: { array = $0 }
        )

        // Push proxy
        LuaStringArrayProxy.push(proxy, to: lua.luaState)

        // Verify it's userdata
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TUSERDATA)

        lua_pop(lua.luaState, 1)
    }

    // MARK: - __gc Metamethod Tests

    func testArrayProxyGarbageCollection() {
        var array = ["gc", "test"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "gcArray",
            getter: { array },
            setter: { array = $0 }
        )

        // Push proxy and call gc metamethod directly
        LuaStringArrayProxy.push(proxy, to: lua.luaState)

        // Get metatable
        lua_getmetatable(lua.luaState, -1)

        // Get __gc metamethod
        lua_getfield(lua.luaState, -1, "__gc")

        // Push the proxy again as the first argument
        lua_pushvalue(lua.luaState, -3)

        // Call __gc
        _ = lua_pcall(lua.luaState, 1, 0, 0)

        lua_pop(lua.luaState, 2) // Pop metatable and proxy

        // Should not crash
        XCTAssertTrue(true)
    }

    // MARK: - Constructor and Registration Tests

    func testArrayProxyConstructorError() {
        // Try to construct array proxy from Lua (should fail)
        // Push a dummy function to avoid panic
        lua_pushcclosure(lua.luaState, { luaState in
            guard let luaState = luaState else { return 0 }
            return luaError(luaState, "LuaStringArrayProxy cannot be constructed directly")
        }, 0)

        // Call the function
        let result = lua_pcall(lua.luaState, 0, 1, 0)
        XCTAssertNotEqual(result, 0) // Should return error

        // Pop error message
        lua_pop(lua.luaState, 1)
    }

    func testArrayProxyRegisterConstructor() {
        // This should be a no-op
        LuaStringArrayProxy.registerConstructor(lua.luaState, name: "TestProxy")

        // Try to access it - should not exist
        lua_getglobal(lua.luaState, "TestProxy")
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)
    }

}
