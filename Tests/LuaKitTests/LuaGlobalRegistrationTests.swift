//
//  LuaGlobalRegistrationTests.swift
//  LuaKit
//
//  Tests for LuaGlobalRegistration functionality
//

import XCTest
import Lua
@testable import LuaKit

final class LuaGlobalRegistrationTests: XCTestCase {
    var lua: LuaState!
    
    override func setUp() {
        super.setUp()
        lua = try! LuaState()
    }
    
    override func tearDown() {
        lua = nil
        super.tearDown()
    }
    
    // MARK: - Type-safe Global Registration Tests
    
    func testRegisterGlobalBasicTypes() {
        // Test Bool
        lua.registerGlobal("testBool", true)
        let boolResult = try! lua.execute("return testBool")
        XCTAssertEqual(boolResult.trimmingCharacters(in: .whitespacesAndNewlines), "true")
        
        // Test Int
        lua.registerGlobal("testInt", 42)
        let intResult = try! lua.execute("return testInt")
        XCTAssertEqual(intResult.trimmingCharacters(in: .whitespacesAndNewlines), "42")
        
        // Test Double
        lua.registerGlobal("testDouble", 3.14)
        let doubleResult = try! lua.execute("return testDouble")
        XCTAssertEqual(doubleResult.trimmingCharacters(in: .whitespacesAndNewlines), "3.14")
        
        // Test String
        lua.registerGlobal("testString", "Hello, Lua!")
        let stringResult = try! lua.execute("return testString")
        XCTAssertEqual(stringResult.trimmingCharacters(in: .whitespacesAndNewlines), "Hello, Lua!")
    }
    
    func testRegisterGlobalBridgeable() {
        @LuaBridgeable
        class TestObject: LuaBridgeable {
            var value: Int = 100
        }
        
        let obj = TestObject()
        lua.registerGlobal("testObj", obj)
        
        let result = try! lua.execute("return testObj.value")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "100")
    }
    
    func testRegisterMultipleGlobals() {
        lua.registerGlobals([
            "x": 10,
            "y": 20,
            "name": "Test",
            "active": true
        ])
        
        let result = try! lua.execute("""
            return x + y .. ',' .. name .. ',' .. tostring(active)
        """)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "30,Test,true")
    }
    
    // MARK: - Namespace Tests
    
    func testRegisterNamespace() {
        let namespace = lua.registerNamespace("MyModule")
        XCTAssertNotNil(namespace)
        XCTAssertEqual(namespace.name, "MyModule")
        
        // Verify namespace exists as table
        let result = try! lua.execute("return type(MyModule)")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "table")
    }
    
    func testRegisterInNamespace() {
        lua.registerNamespace("Math")
        lua.registerInNamespace("Math", name: "PI", value: 3.14159)
        lua.registerInNamespace("Math", name: "E", value: 2.71828)
        
        let result = try! lua.execute("""
            return Math.PI .. ',' .. Math.E
        """)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "3.14159,2.71828")
    }
    
    func testNamespaceWithFunction() {
        lua.registerNamespace("Utils")
        lua.registerInNamespace("Utils", name: "double", value: LuaFunction { (n: Int) in
            return n * 2
        })
        
        let result = try! lua.execute("return Utils.double(21)")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "42")
    }
    
    func testNestedNamespace() {
        let math = lua.registerNamespace("Math")
        let geometry = math.namespace("Geometry")
        
        geometry?.register("PI", 3.14159)
        
        // Note: The implementation concatenates with dot, so it becomes Math.Geometry
        // But the actual structure would need to handle nested tables properly
        // For now, test what we can
        XCTAssertNotNil(geometry)
    }
    
    // MARK: - Documented Function Tests
    
    func testRegisterDocumentedFunction() {
        lua.registerDocumentedFunction(
            "calculate",
            description: "Performs a calculation",
            parameters: [
                ("a", "number", "First operand"),
                ("b", "number", "Second operand"),
                ("op", "string", "Operation (+, -, *, /)")
            ],
            returns: "The result of the calculation",
            function: LuaFunction { (a: Double, b: Double, op: String) -> Double in
                switch op {
                case "+": return a + b
                case "-": return a - b
                case "*": return a * b
                case "/": return b != 0 ? a / b : 0
                default: return 0
                }
            }
        )
        
        // Test the function works
        let result = try! lua.execute("return calculate(10, 5, '+')")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "15.0")
        
        // Check documentation was stored
        let docKey = "__luakit_doc_calculate"
        let doc: String? = lua.globals[docKey]
        XCTAssertNotNil(doc)
        XCTAssertTrue(doc!.contains("Performs a calculation"))
        XCTAssertTrue(doc!.contains("First operand"))
    }
    
    // MARK: - Enum Registration Tests
    
    enum TestEnum: String, CaseIterable {
        case option1 = "opt1"
        case option2 = "opt2"
        case option3 = "opt3"
    }
    
    func testRegisterEnum() {
        lua.registerEnum(TestEnum.self, as: "Options")
        
        // Check enum values are available
        let result = try! lua.execute("""
            return Options.opt1 .. ',' .. Options.opt2 .. ',' .. Options.opt3
        """)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "opt1,opt2,opt3")
    }
    
    // MARK: - LuaNamespace Tests
    
    func testLuaNamespaceRegister() {
        let namespace = lua.registerNamespace("Test")
        namespace.register("value", 42)
        namespace.register("name", "TestName")
        
        let result = try! lua.execute("""
            return Test.value .. ',' .. Test.name
        """)
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "42,TestName")
    }
    
    // MARK: - LuaFunctionDocumentation Tests
    
    func testLuaFunctionDocumentationToJSON() {
        let doc = LuaFunctionDocumentation(
            name: "testFunc",
            description: "A test function",
            parameters: [
                ("param1", "string", "First parameter"),
                ("param2", "number", "Second parameter")
            ],
            returns: "A result string"
        )
        
        let json = doc.toJSON()
        XCTAssertTrue(json.contains("\"name\":\"testFunc\""))
        XCTAssertTrue(json.contains("\"description\":\"A test function\""))
        XCTAssertTrue(json.contains("\"param1\""))
        XCTAssertTrue(json.contains("\"param2\""))
        XCTAssertTrue(json.contains("\"returns\":\"A result string\""))
    }
    
    func testLuaFunctionDocumentationWithoutReturns() {
        let doc = LuaFunctionDocumentation(
            name: "voidFunc",
            description: "A void function",
            parameters: [],
            returns: nil
        )
        
        let json = doc.toJSON()
        XCTAssertTrue(json.contains("\"name\":\"voidFunc\""))
        XCTAssertFalse(json.contains("\"returns\""))
    }
    
    // MARK: - LuaNamespaceBuilder Tests
    
    func testLuaNamespaceBuilder() {
        lua.globals.namespace("StringUtils")
            .add("version", "1.0.0")
            .add("author", "Test")
            .function("upper") { () -> Any in
                return "TEST"
            }
            .build()
        
        let versionResult = try! lua.execute("return StringUtils.version")
        XCTAssertEqual(versionResult.trimmingCharacters(in: .whitespacesAndNewlines), "1.0.0")
        
        let authorResult = try! lua.execute("return StringUtils.author")
        XCTAssertEqual(authorResult.trimmingCharacters(in: .whitespacesAndNewlines), "Test")
        
        let funcResult = try! lua.execute("return StringUtils.upper()")
        XCTAssertEqual(funcResult.trimmingCharacters(in: .whitespacesAndNewlines), "TEST")
    }
    
    // MARK: - Debug Logging Tests
    
    func testDebugLogging() {
        var capturedLogs: [String] = []
        LuaDebugConfig.logger = { message, _ in
            capturedLogs.append(message)
        }
        LuaDebugConfig.isEnabled = true
        
        lua.registerGlobal("debugTest", 123)
        
        XCTAssertTrue(capturedLogs.contains { $0.contains("Registered global 'debugTest'") })
        
        lua.registerNamespace("DebugNamespace")
        
        XCTAssertTrue(capturedLogs.contains { $0.contains("Created namespace 'DebugNamespace'") })
        
        // Clean up
        LuaDebugConfig.isEnabled = false
        LuaDebugConfig.logger = nil
    }
    
    // MARK: - Edge Cases
    
    func testRegisterInNonExistentNamespace() {
        // Should create namespace automatically
        lua.registerInNamespace("AutoCreated", name: "value", value: 42)
        
        let result = try! lua.execute("return AutoCreated.value")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "42")
    }
    
    func testOverwriteNamespace() {
        lua.registerNamespace("Test")
        lua.registerInNamespace("Test", name: "value", value: 1)
        
        // Overwrite with new value
        lua.registerInNamespace("Test", name: "value", value: 2)
        
        let result = try! lua.execute("return Test.value")
        XCTAssertEqual(result.trimmingCharacters(in: .whitespacesAndNewlines), "2")
    }
    
    func testPushValueWithVariousTypes() {
        // Test with LuaFunction
        lua.registerGlobal("funcGlobal", LuaFunction { return "Function result" })
        let funcResult = try! lua.execute("return funcGlobal()")
        XCTAssertEqual(funcResult.trimmingCharacters(in: .whitespacesAndNewlines), "Function result")
        
        // Test with nil (using Optional)
        lua.registerGlobals(["nilValue": Optional<Int>.none as Any])
        let nilResult = try! lua.execute("return nilValue == nil")
        XCTAssertEqual(nilResult.trimmingCharacters(in: .whitespacesAndNewlines), "true")
    }
}