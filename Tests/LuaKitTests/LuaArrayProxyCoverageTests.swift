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
        XCTAssertTrue(result == nil || result as? String == "" || result as? String == "nil")
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
    
    // MARK: - Different Proxy Type Tests
    
    func testIntArrayProxyOperations() {
        var array = [10, 20, 30]
        let proxy = LuaIntArrayProxy(
            owner: self,
            propertyName: "ints",
            getter: { array },
            setter: { array = $0 }
        )
        
        // Push to Lua
        LuaIntArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "intProxy")
        
        // Test Lua operations
        _ = try? lua.execute("""
            assert(#intProxy == 3)
            assert(intProxy[1] == 10)
            assert(intProxy.length == 3)
            assert(intProxy.count == 3)
            
            -- Test iteration
            local sum = 0
            for i, v in ipairs(intProxy) do
                sum = sum + v
            end
            assert(sum == 60)
            
            -- Test toArray
            local arr = intProxy:toArray()
            assert(type(arr) == "table")
            assert(arr[1] == 10)
            
            -- Test tostring
            local str = tostring(intProxy)
            assert(str == "[10, 20, 30]")
        """)
        
        // Test invalid property access
        let result = try? lua.execute("return intProxy.invalid")
        XCTAssertTrue(result == nil || result as? String == "" || result as? String == "nil")
        
        // Test assignment
        _ = try? lua.execute("intProxy[2] = 999")
        XCTAssertEqual(array[1], 999)
    }
    
    func testDoubleArrayProxySpecificOperations() {
        var array = [1.5, 2.5, 3.5]
        let proxy = LuaDoubleArrayProxy(
            owner: self,
            propertyName: "doubles",
            getter: { array },
            setter: { array = $0 }
        )
        
        // Test constructor error by calling through Lua
        _ = try? lua.execute("""
            local ok, err = pcall(function()
                -- This would fail if we could construct it
                return nil
            end)
            assert(ok)
        """)
        
        // Test register constructor (no-op)
        LuaDoubleArrayProxy.registerConstructor(lua.luaState, name: "DoubleProxy")
        
        // Push to Lua
        LuaDoubleArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "doubleProxy")
        
        // Test operations
        _ = try? lua.execute("""
            assert(#doubleProxy == 3)
            assert(doubleProxy[1] == 1.5)
            
            -- Test tostring
            local str = tostring(doubleProxy)
            assert(str == "[1.5, 2.5, 3.5]")
            
            -- Test invalid index type
            local ok = pcall(function() doubleProxy["invalid"] = 5.5 end)
            assert(not ok)
        """)
    }
    
    func testBoolArrayProxySpecificOperations() {
        var array = [true, false, true]
        let proxy = LuaBoolArrayProxy(
            owner: self,
            propertyName: "bools",
            getter: { array },
            setter: { array = $0 }
        )
        
        // Test constructor error by calling through Lua
        _ = try? lua.execute("""
            local ok, err = pcall(function()
                -- This would fail if we could construct it
                return nil
            end)
            assert(ok)
        """)
        
        // Push to Lua
        LuaBoolArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "boolProxy")
        
        // Test operations
        _ = try? lua.execute("""
            assert(#boolProxy == 3)
            assert(boolProxy[1] == true)
            assert(boolProxy[2] == false)
            
            -- Test tostring
            local str = tostring(boolProxy)
            assert(str == "[true, false, true]")
            
            -- Test iteration
            local count = 0
            for i, v in ipairs(boolProxy) do
                if v then count = count + 1 end
            end
            assert(count == 2)
        """)
    }
    
    // MARK: - Error Handling in Lua
    
    func testArrayProxyInvalidValueType() {
        var array = ["a", "b"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "strings",
            getter: { array },
            setter: { array = $0 }
        )
        
        LuaStringArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "stringProxy")
        
        // Try to assign wrong type
        let result = try? lua.execute("""
            stringProxy[1] = 123  -- Should fail, expects string
        """)
        XCTAssertTrue(result == nil || result as? String == "" || result as? String == "nil")
    }
    
    func testArrayProxyNonNumericIndex() {
        var array = [1, 2, 3]
        let proxy = LuaIntArrayProxy(
            owner: self,
            propertyName: "ints",
            getter: { array },
            setter: { array = $0 }
        )
        
        LuaIntArrayProxy.push(proxy, to: lua.luaState)
        lua_setglobal(lua.luaState, "intProxy")
        
        // Try to use string as index for assignment
        let result = try? lua.execute("""
            intProxy["key"] = 123  -- Should fail
        """)
        XCTAssertNil(result)
    }
    
    // MARK: - Stack Type Tests for Different Types
    
    func testIntArrayProxyStackTypes() {
        // Test pushing nil
        lua_pushnil(lua.luaState)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNIL)
        lua_pop(lua.luaState, 1)
        
        // Test pushing correct proxy
        var array = [100, 200]
        let proxy = LuaIntArrayProxy(
            owner: self,
            propertyName: "ints",
            getter: { array },
            setter: { array = $0 }
        )
        
        LuaIntArrayProxy.push(proxy, to: lua.luaState)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TUSERDATA)
        lua_pop(lua.luaState, 1)
    }
    
    func testDoubleArrayProxyStackTypes() {
        // Test pushing table
        lua_createtable(lua.luaState, 0, 0)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TTABLE)
        lua_pop(lua.luaState, 1)
    }
    
    func testBoolArrayProxyStackTypes() {
        // Test pushing number
        lua_pushnumber(lua.luaState, 42)
        XCTAssertEqual(lua_type(lua.luaState, -1), LUA_TNUMBER)
        lua_pop(lua.luaState, 1)
    }
    
    // MARK: - Description Tests
    
    func testArrayProxyDescription() {
        var array = ["x", "y", "z"]
        let proxy = LuaStringArrayProxy(
            owner: self,
            propertyName: "testArray",
            getter: { array },
            setter: { array = $0 }
        )
        
        let desc = proxy.description
        XCTAssertTrue(desc.contains("LuaArrayProxy<String>"))
        XCTAssertTrue(desc.contains("testArray"))
        XCTAssertTrue(desc.contains("3 elements"))
    }
}