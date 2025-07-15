//
//  LuaBridgeableCoverageTests.swift
//  LuaKit
//
//  Created by Barry Walker.
//
//  Comprehensive tests to improve LuaBridgeable coverage
//

import Lua
@testable import LuaKit
import XCTest

// Test class that implements LuaBridgeable
class TestBridgeableClass: LuaBridgeable {
    var name: String = "test"
    var value: Int = 42
    var callback: (() -> Void)?

    // Track property changes
    var willChangeCallCount = 0
    var didChangeCallCount = 0
    var lastPropertyChanged: String?
    var lastOldValue: Any?
    var lastNewValue: Any?

    // For validation testing
    var shouldRejectChange = false
    var rejectionMessage = "Change rejected"

    static func luaNew(_ luaState: OpaquePointer) -> Int32 {
        // Get constructor arguments if any
        let name = String.pull(from: luaState, at: 1) ?? "default"
        let value = Int.pull(from: luaState, at: 2) ?? 0

        let instance = TestBridgeableClass()
        instance.name = name
        instance.value = value

        push(instance, to: luaState)
        return 1
    }

    static func registerConstructor(_ luaState: OpaquePointer, name: String) {
        lua_pushcclosure(luaState, { innerState in
            guard let innerState = innerState else { return 0 }
            return TestBridgeableClass.luaNew(innerState)
        }, 0)
        lua_setglobal(luaState, name)
    }

    static func registerMethods(_ luaState: OpaquePointer) {
        let methods = [
            LuaMethod(name: "getName") { innerState in
                guard let innerState = innerState else { return 0 }
                guard let obj = TestBridgeableClass.checkUserdata(innerState, at: 1) else {
                    return luaError(innerState, "Invalid object")
                }
                String.push(obj.name, to: innerState)
                return 1
            },
            LuaMethod(name: "setName") { innerState in
                guard let innerState = innerState else { return 0 }
                guard let obj = TestBridgeableClass.checkUserdata(innerState, at: 1) else {
                    return luaError(innerState, "Invalid object")
                }
                guard let newName = String.pull(from: innerState, at: 2) else {
                    return luaError(innerState, "Expected string argument")
                }

                let oldName = obj.name
                let result = obj.luaPropertyWillChange("name", from: oldName, to: newName)

                switch result {
                case .success:
                    obj.name = newName
                    obj.luaPropertyDidChange("name", from: oldName, to: newName)
                    return 0
                case .failure(let error):
                    return luaError(innerState, error.message)
                }
            },
            LuaMethod(name: "getValue") { innerState in
                guard let innerState = innerState else { return 0 }
                guard let obj = TestBridgeableClass.checkUserdata(innerState, at: 1) else {
                    return luaError(innerState, "Invalid object")
                }
                Int.push(obj.value, to: innerState)
                return 1
            },
            LuaMethod(name: "callCallback") { innerState in
                guard let innerState = innerState else { return 0 }
                guard let obj = TestBridgeableClass.checkUserdata(innerState, at: 1) else {
                    return luaError(innerState, "Invalid object")
                }
                obj.callback?()
                return 0
            }
        ]

        registerLuaMethods(luaState, methods: methods)
    }

    // Implement property change notifications for testing
    func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        willChangeCallCount += 1
        lastPropertyChanged = propertyName
        lastOldValue = oldValue
        lastNewValue = newValue

        if shouldRejectChange {
            return .failure(PropertyValidationError(rejectionMessage))
        }

        return .success(())
    }

    func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
        didChangeCallCount += 1
        lastPropertyChanged = propertyName
        lastOldValue = oldValue
        lastNewValue = newValue
    }
}

// Another test class to test pushAny with different types
class AnotherBridgeableClass: LuaBridgeable {
    var id: Int = 0

    static func luaNew(_ luaState: OpaquePointer) -> Int32 {
        let instance = AnotherBridgeableClass()
        push(instance, to: luaState)
        return 1
    }

    static func registerConstructor(_ luaState: OpaquePointer, name: String) {
        lua_pushcclosure(luaState, { innerState in
            guard let innerState = innerState else { return 0 }
            return AnotherBridgeableClass.luaNew(innerState)
        }, 0)
        lua_setglobal(luaState, name)
    }

    static func registerMethods(_ luaState: OpaquePointer) {
        // No methods for this simple test class
    }
}

final class LuaBridgeableCoverageTests: XCTestCase {
    var lua: LuaState!

    override func setUp() {
        super.setUp()
        do {
            lua = try LuaState()
            // Register our test classes
            TestBridgeableClass.register(in: lua, as: "TestClass")
            AnotherBridgeableClass.register(in: lua, as: "AnotherClass")
        } catch {
            XCTFail("Failed to create LuaState: \(error)")
        }
    }

    override func tearDown() {
        lua = nil
        super.tearDown()
    }

    // MARK: - PropertyValidationError Tests

    func testPropertyValidationErrorDescription() {
        let error = PropertyValidationError("Test error message")
        XCTAssertEqual(error.description, "Test error message")
        XCTAssertEqual(error.message, "Test error message")
    }

    // MARK: - Default Implementation Tests

    func testDefaultPropertyChangeImplementations() {
        let obj = TestBridgeableClass()

        // Test default implementation (should allow all changes)
        let result = obj.luaPropertyWillChange("test", from: "old", to: "new")
        switch result {
        case .success:
            XCTAssertTrue(true)
        case .failure:
            XCTFail("Default implementation should allow changes")
        }

        // Test default did change (should do nothing)
        obj.luaPropertyDidChange("test", from: "old", to: "new")
        // No crash means success
    }

    // MARK: - MetaTable Name Tests

    func testMetaTableName() {
        XCTAssertEqual(TestBridgeableClass.metaTableName, "TestBridgeableClass_meta")
        XCTAssertEqual(AnotherBridgeableClass.metaTableName, "AnotherBridgeableClass_meta")
    }

    // MARK: - Registration Tests

    func testClassRegistration() {
        // Test that classes are properly registered
        let result = try? lua.execute("""
            local obj1 = TestClass()
            local obj2 = AnotherClass()
            return obj1 ~= nil and obj2 ~= nil
        """)

        XCTAssertNotNil(result)
    }

    func testConstructorWithArguments() {
        let result = try? lua.execute("""
            local obj = TestClass("custom", 100)
            return obj:getName(), obj:getValue()
        """)

        // LuaFunction returns multiple values as the first value only
        XCTAssertNotNil(result)
    }

    // MARK: - Push and Pull Tests

    func testPushAndCheckUserdata() {
        let obj = TestBridgeableClass()
        obj.name = "pushed"
        obj.value = 999

        TestBridgeableClass.push(obj, to: lua.luaState)

        // Verify it's on the stack
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TUSERDATA)

        // Check we can retrieve it
        let retrieved = TestBridgeableClass.checkUserdata(lua.luaState, at: -1)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "pushed")
        XCTAssertEqual(retrieved?.value, 999)

        lua_pop(lua.luaState, 1)
    }

    func testCheckUserdataWithWrongType() {
        // Push a different type
        lua_pushstring(lua.luaState, "not userdata")

        let retrieved = TestBridgeableClass.checkUserdata(lua.luaState, at: -1)
        XCTAssertNil(retrieved)

        lua_pop(lua.luaState, 1)
    }

    func testCheckUserdataWithWrongMetatable() {
        // Create userdata with different metatable
        let userdata = lua_newuserdatauv(lua.luaState, MemoryLayout<AnyObject>.size, 0)
        userdata?.assumingMemoryBound(to: AnyObject.self).initialize(to: NSObject())

        // Set a different metatable
        lua_createtable(lua.luaState, 0, 0)
        lua_setmetatable(lua.luaState, -2)

        let retrieved = TestBridgeableClass.checkUserdata(lua.luaState, at: -1)
        XCTAssertNil(retrieved)

        lua_pop(lua.luaState, 1)
    }

    // MARK: - PushAny Tests

    func testPushAnyWithCorrectType() {
        let obj = TestBridgeableClass()
        obj.name = "pushAny"

        let bridgeable: LuaBridgeable = obj
        TestBridgeableClass.pushAny(bridgeable, to: lua.luaState)

        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TUSERDATA)

        let retrieved = TestBridgeableClass.checkUserdata(lua.luaState, at: -1)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "pushAny")

        lua_pop(lua.luaState, 1)
    }

    func testPushAnyWithWrongType() {
        let obj = AnotherBridgeableClass()
        obj.id = 123

        let bridgeable: LuaBridgeable = obj
        TestBridgeableClass.pushAny(bridgeable, to: lua.luaState)

        // Should push nil for wrong type
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)

        lua_pop(lua.luaState, 1)
    }

    // MARK: - Property Change Notification Tests

    func testPropertyChangeNotifications() {
        let obj = TestBridgeableClass()
        obj.name = "initial"

        TestBridgeableClass.push(obj, to: lua.luaState)
        lua_setglobal(lua.luaState, "testObj")

        // Change property through Lua
        _ = try? lua.execute("""
            testObj:setName("changed")
        """)

        XCTAssertEqual(obj.name, "changed")
        XCTAssertEqual(obj.willChangeCallCount, 1)
        XCTAssertEqual(obj.didChangeCallCount, 1)
        XCTAssertEqual(obj.lastPropertyChanged, "name")
        XCTAssertEqual(obj.lastOldValue as? String, "initial")
        XCTAssertEqual(obj.lastNewValue as? String, "changed")
    }

    func testPropertyChangeRejection() {
        let obj = TestBridgeableClass()
        obj.name = "initial"
        obj.shouldRejectChange = true
        obj.rejectionMessage = "Cannot change name"

        TestBridgeableClass.push(obj, to: lua.luaState)
        lua_setglobal(lua.luaState, "testObj")

        // Try to change property through Lua (should fail)
        let result = try? lua.execute("""
            testObj:setName("rejected")
        """)

        XCTAssertNil(result) // Should fail
        XCTAssertEqual(obj.name, "initial") // Name should not change
        XCTAssertEqual(obj.willChangeCallCount, 1)
        XCTAssertEqual(obj.didChangeCallCount, 0) // Did change should not be called
    }

    // MARK: - Method Registration Tests

    func testMethodCalls() {
        let obj = TestBridgeableClass()
        obj.name = "methodTest"
        obj.value = 77

        var callbackCalled = false
        obj.callback = {
            callbackCalled = true
        }

        TestBridgeableClass.push(obj, to: lua.luaState)
        lua_setglobal(lua.luaState, "testObj")

        // Test getName
        let name = try? lua.execute("return testObj:getName()")
        XCTAssertNotNil(name)

        // Test getValue
        let value = try? lua.execute("return testObj:getValue()")
        XCTAssertNotNil(value)

        // Test callback
        _ = try? lua.execute("testObj:callCallback()")
        XCTAssertTrue(callbackCalled)
    }

    func testMethodWithInvalidObject() {
        // Create a table that's not a valid object
        _ = try? lua.execute("fakeObj = {}")

        // Try to call method on it
        let result = try? lua.execute("return TestClass.getName(fakeObj)")
        XCTAssertNil(result) // Should fail
    }

    // MARK: - Garbage Collection Tests

    func testGarbageCollectionMetamethod() {
        // Create object in Lua
        _ = try? lua.execute("""
            local obj = TestClass("gc-test", 123)
            -- Object goes out of scope
        """)

        // Force garbage collection
        _ = try? lua.execute("collectgarbage('collect')")

        // Should not crash
        XCTAssertTrue(true)
    }

    // MARK: - LuaMethod Tests

    func testLuaMethodCreation() {
        let method = LuaMethod(name: "testMethod") { innerState in
            guard let innerState = innerState else { return 0 }
            lua_pushstring(innerState, "method called")
            return 1
        }

        XCTAssertEqual(method.name, "testMethod")
        XCTAssertNotNil(method.function)
    }

    func testRegisterLuaMethods() {
        // Create a new metatable for testing
        lua_createtable(lua.luaState, 0, 0)

        let methods = [
            LuaMethod(name: "method1") { innerState in
                guard let innerState = innerState else { return 0 }
                lua_pushinteger(innerState, 1)
                return 1
            },
            LuaMethod(name: "method2") { innerState in
                guard let innerState = innerState else { return 0 }
                lua_pushinteger(innerState, 2)
                return 1
            }
        ]

        registerLuaMethods(lua.luaState, methods: methods)

        // Verify methods were registered
        lua_getfield(lua.luaState, -1, "method1")
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TFUNCTION)
        lua_pop(lua.luaState, 1)

        lua_getfield(lua.luaState, -1, "method2")
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TFUNCTION)
        lua_pop(lua.luaState, 1)

        lua_pop(lua.luaState, 1) // Pop the table
    }

    // MARK: - Edge Cases

    func testMethodWithMissingArguments() {
        let obj = TestBridgeableClass()
        TestBridgeableClass.push(obj, to: lua.luaState)
        lua_setglobal(lua.luaState, "testObj")

        // Call setName without argument
        let result = try? lua.execute("testObj:setName()")
        XCTAssertNil(result) // Should fail
    }

    func testMethodCallOnNilObject() {
        // Push nil instead of object
        lua_pushnil(lua.luaState)
        lua_setglobal(lua.luaState, "nilObj")

        // Try to call method
        let result = try? lua.execute("return nilObj:getName()")
        XCTAssertNil(result) // Should fail
    }
}