//
//  BridgeableTests.swift
//  LuaKitTests
//
//  Created by Barry Walker on 7/8/25.
//

import XCTest
import CLua
@testable import LuaKit

// Test class that will be bridged to Lua
class TestPerson: LuaBridgeable, CustomStringConvertible {
    var name: String
    var age: Int
    
    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    
    func greet() -> String {
        return "Hello, I'm \(name) and I'm \(age) years old"
    }
    
    func haveBirthday() {
        age += 1
    }
    
    var description: String {
        return "Person(name: \(name), age: \(age))"
    }
    
    // MARK: - LuaBridgeable
    static func registerMethods(_ L: OpaquePointer) {
        registerLuaMethods(L, methods: [
            LuaMethod(name: "greet", function: { L in
                guard let L = L else { return 0 }
                guard let obj = TestPerson.checkUserdata(L, at: 1) else {
                    return luaError(L, "Invalid TestPerson object")
                }
                let result = obj.greet()
                String.push(result, to: L)
                return 1
            }),
            LuaMethod(name: "haveBirthday", function: { L in
                guard let L = L else { return 0 }
                guard let obj = TestPerson.checkUserdata(L, at: 1) else {
                    return luaError(L, "Invalid TestPerson object")
                }
                obj.haveBirthday()
                return 0
            })
        ])
        
        // Property getters/setters
        lua_pushstring(L, "__index")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = TestPerson.checkUserdata(L, at: 1) else { return 0 }
            guard let key = String.pull(from: L, at: 2) else { return 0 }
            
            switch key {
            case "name":
                String.push(obj.name, to: L)
                return 1
            case "age":
                Int.push(obj.age, to: L)
                return 1
            default:
                lua_getmetatable(L, 1)
                lua_pushstring(L, key)
                lua_rawget(L, -2)
                return 1
            }
        }, 0)
        lua_settable(L, -3)
        
        lua_pushstring(L, "__newindex")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = TestPerson.checkUserdata(L, at: 1) else { return 0 }
            guard let key = String.pull(from: L, at: 2) else { return 0 }
            
            switch key {
            case "name":
                if let value = String.pull(from: L, at: 3) {
                    obj.name = value
                }
            case "age":
                if let value = Int.pull(from: L, at: 3) {
                    obj.age = value
                }
            default:
                break
            }
            return 0
        }, 0)
        lua_settable(L, -3)
        
        lua_pushstring(L, "__tostring")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = TestPerson.checkUserdata(L, at: 1) else { return 0 }
            String.push(obj.description, to: L)
            return 1
        }, 0)
        lua_settable(L, -3)
    }
    
    static func registerConstructor(_ L: OpaquePointer, name: String) {
        lua_createtable(L, 0, 1)
        
        lua_pushstring(L, "new")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            return TestPerson.luaNew(L)
        }, 0)
        lua_settable(L, -3)
        
        lua_setglobal(L, name)
    }
    
    static func luaNew(_ L: OpaquePointer) -> Int32 {
        guard let name = String.pull(from: L, at: 1) else {
            return luaError(L, "Expected string for name")
        }
        let age = Int(luaL_checkinteger(L, 2))
        
        let instance = TestPerson(name: name, age: age)
        push(instance, to: L)
        
        return 1
    }
}

// Test class with different property types
class TestCalculator: LuaBridgeable {
    var lastResult: Double = 0
    
    init() {}
    
    func add(_ a: Double, _ b: Double) -> Double {
        lastResult = a + b
        return lastResult
    }
    
    func multiply(_ a: Double, _ b: Double) -> Double {
        lastResult = a * b
        return lastResult
    }
    
    var description: String {
        return "Calculator(lastResult: \(lastResult))"
    }
    
    // MARK: - LuaBridgeable
    static func registerMethods(_ L: OpaquePointer) {
        registerLuaMethods(L, methods: [
            LuaMethod(name: "add", function: { L in
                guard let L = L else { return 0 }
                guard let obj = TestCalculator.checkUserdata(L, at: 1) else {
                    return luaError(L, "Invalid TestCalculator object")
                }
                let a = lua_tonumberx(L, 2, nil)
                let b = lua_tonumberx(L, 3, nil)
                let result = obj.add(a, b)
                Double.push(result, to: L)
                return 1
            }),
            LuaMethod(name: "multiply", function: { L in
                guard let L = L else { return 0 }
                guard let obj = TestCalculator.checkUserdata(L, at: 1) else {
                    return luaError(L, "Invalid TestCalculator object")
                }
                let a = lua_tonumberx(L, 2, nil)
                let b = lua_tonumberx(L, 3, nil)
                let result = obj.multiply(a, b)
                Double.push(result, to: L)
                return 1
            })
        ])
        
        // Property getter
        lua_pushstring(L, "__index")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = TestCalculator.checkUserdata(L, at: 1) else { return 0 }
            guard let key = String.pull(from: L, at: 2) else { return 0 }
            
            switch key {
            case "lastResult":
                Double.push(obj.lastResult, to: L)
                return 1
            default:
                lua_getmetatable(L, 1)
                lua_pushstring(L, key)
                lua_rawget(L, -2)
                return 1
            }
        }, 0)
        lua_settable(L, -3)
        
        lua_pushstring(L, "__tostring")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let obj = TestCalculator.checkUserdata(L, at: 1) else { return 0 }
            String.push(obj.description, to: L)
            return 1
        }, 0)
        lua_settable(L, -3)
    }
    
    static func registerConstructor(_ L: OpaquePointer, name: String) {
        lua_createtable(L, 0, 1)
        
        lua_pushstring(L, "new")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            return TestCalculator.luaNew(L)
        }, 0)
        lua_settable(L, -3)
        
        lua_setglobal(L, name)
    }
    
    static func luaNew(_ L: OpaquePointer) -> Int32 {
        let instance = TestCalculator()
        push(instance, to: L)
        return 1
    }
}

final class BridgeableTests: XCTestCase {
    
    func testBridgeClass() throws {
        let lua = try LuaState()
        
        // Register the class
        lua.register(TestPerson.self, as: "Person")
        
        var output = ""
        lua.setPrintHandler { text in
            output += text
        }
        
        // Use from Lua
        _ = try lua.execute("""
            local p = Person.new("Alice", 25)
            print(p)
            print("Name:", p.name)
            print("Age:", p.age)
            print(p:greet())
            
            p:haveBirthday()
            print("After birthday:", p.age)
            
            p.name = "Alicia"
            print("After name change:", p.name)
        """)
        
        XCTAssertTrue(output.contains("Alice"))
        XCTAssertTrue(output.contains("25"))
        XCTAssertTrue(output.contains("Hello, I'm Alice and I'm 25 years old"))
        XCTAssertTrue(output.contains("26"))
        XCTAssertTrue(output.contains("Alicia"))
    }
    
    func testBridgeFromSwiftToLua() throws {
        let lua = try LuaState()
        lua.register(TestPerson.self, as: "Person")
        
        // Create in Swift
        let person = TestPerson(name: "Bob", age: 30)
        
        // Pass to Lua
        lua.globals.set("bob", to: lua.toReference(person))
        
        // Modify in Lua
        _ = try lua.execute("""
            bob.age = 31
            bob.name = "Robert"
        """)
        
        // Verify changes in Swift
        XCTAssertEqual(person.age, 31)
        XCTAssertEqual(person.name, "Robert")
    }
    
    func testCalculator() throws {
        let lua = try LuaState()
        lua.register(TestCalculator.self, as: "Calculator")
        
        var output = ""
        lua.setPrintHandler { text in
            output += text
        }
        
        _ = try lua.execute("""
            local calc = Calculator.new()
            print("2 + 3 =", calc:add(2, 3))
            print("Last result:", calc.lastResult)
            
            print("4 * 5 =", calc:multiply(4, 5))
            print("Last result:", calc.lastResult)
        """)
        
        XCTAssertTrue(output.contains("2 + 3 =\t5"))
        XCTAssertTrue(output.contains("4 * 5 =\t20"))
    }
    
    func testMultipleInstances() throws {
        let lua = try LuaState()
        lua.register(TestPerson.self, as: "Person")
        
        var output = ""
        lua.setPrintHandler { text in
            output += text
        }
        
        _ = try lua.execute("""
            local people = {}
            people[1] = Person.new("Alice", 25)
            people[2] = Person.new("Bob", 30)
            people[3] = Person.new("Charlie", 35)
            
            for i = 1, 3 do
                print(people[i]:greet())
            end
        """)
        
        XCTAssertTrue(output.contains("Alice"))
        XCTAssertTrue(output.contains("Bob"))
        XCTAssertTrue(output.contains("Charlie"))
    }
}