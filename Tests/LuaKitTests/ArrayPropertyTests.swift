//
//  ArrayPropertyTests.swift
//  LuaKitTests
//
//  Tests for array property support
//

import XCTest
import Lua
@testable import LuaKit

// Test class with various array properties
@LuaBridgeable
class ConfigModel: LuaBridgeable {
    public var servers: [String] = []
    public var ports: [Int] = []
    public var weights: [Double] = []
    public var enabledFeatures: [Bool] = []
    
    // Mixed regular and array properties
    public var name: String
    public var timeout: Int
    
    public init(name: String = "default") {
        self.name = name
        self.timeout = 30
    }
    
    public var description: String {
        return "ConfigModel(name: \(name), servers: \(servers.count), ports: \(ports.count))"
    }
}

// Test array validation
@LuaBridgeable
class ValidatedArrayModel: LuaBridgeable {
    public var allowedIPs: [String] = []
    public var scores: [Int] = []
    
    public init() {}
    
    public func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        switch propertyName {
        case "allowedIPs":
            if let ips = newValue as? [String] {
                // Validate IP format
                for ip in ips {
                    let parts = ip.split(separator: ".")
                    if parts.count != 4 {
                        return .failure(PropertyValidationError("Invalid IP format: \(ip)"))
                    }
                    for part in parts {
                        guard let num = Int(part), num >= 0 && num <= 255 else {
                            return .failure(PropertyValidationError("Invalid IP component: \(part) in \(ip)"))
                        }
                    }
                }
            }
        case "scores":
            if let scores = newValue as? [Int] {
                // Validate score range
                for score in scores {
                    if score < 0 || score > 100 {
                        return .failure(PropertyValidationError("Score must be between 0 and 100, got \(score)"))
                    }
                }
            }
        default:
            break
        }
        return .success(())
    }
    
    public var description: String {
        return "ValidatedArrayModel(ips: \(allowedIPs.count), scores: \(scores.count))"
    }
}

class ArrayPropertyTests: XCTestCase {
    
    func testStringArrayProperty() throws {
        let lua = try LuaState()
        lua.register(ConfigModel.self, as: "ConfigModel")
        
        let config = ConfigModel(name: "test")
        lua.globals["config"] = config
        
        // Set array from Lua
        _ = try lua.execute("""
            config.servers = {"server1.com", "server2.com", "server3.com"}
        """)
        
        XCTAssertEqual(config.servers.count, 3)
        XCTAssertEqual(config.servers[0], "server1.com")
        XCTAssertEqual(config.servers[1], "server2.com")
        XCTAssertEqual(config.servers[2], "server3.com")
        
        // Read array from Lua
        let result = try lua.executeReturning("""
            return config.servers[2]  -- Lua uses 1-based indexing
        """, as: String.self)
        
        XCTAssertEqual(result, "server2.com")
    }
    
    func testIntArrayProperty() throws {
        let lua = try LuaState()
        lua.register(ConfigModel.self, as: "ConfigModel")
        
        let config = ConfigModel()
        config.ports = [80, 443]
        lua.globals["config"] = config
        
        // Modify array from Lua
        _ = try lua.execute("""
            -- Add more ports
            config.ports = {80, 443, 8080, 8443}
        """)
        
        XCTAssertEqual(config.ports.count, 4)
        XCTAssertEqual(config.ports, [80, 443, 8080, 8443])
        
        // Use Lua table functions
        _ = try lua.execute("""
            local ports = config.ports
            table.insert(ports, 9000)
            config.ports = ports
        """)
        
        XCTAssertEqual(config.ports.count, 5)
        XCTAssertEqual(config.ports.last, 9000)
    }
    
    func testDoubleArrayProperty() throws {
        let lua = try LuaState()
        lua.register(ConfigModel.self, as: "ConfigModel")
        
        let config = ConfigModel()
        lua.globals["config"] = config
        
        _ = try lua.execute("""
            config.weights = {0.1, 0.3, 0.6}
        """)
        
        XCTAssertEqual(config.weights.count, 3)
        XCTAssertEqual(config.weights[0], 0.1, accuracy: 0.001)
        XCTAssertEqual(config.weights[1], 0.3, accuracy: 0.001)
        XCTAssertEqual(config.weights[2], 0.6, accuracy: 0.001)
        
        // Calculate sum in Lua
        let sum = try lua.executeReturning("""
            local sum = 0
            for i, w in ipairs(config.weights) do
                sum = sum + w
            end
            return sum
        """, as: Double.self)
        
        XCTAssertEqual(sum, 1.0, accuracy: 0.001)
    }
    
    func testBoolArrayProperty() throws {
        let lua = try LuaState()
        lua.register(ConfigModel.self, as: "ConfigModel")
        
        let config = ConfigModel()
        lua.globals["config"] = config
        
        _ = try lua.execute("""
            config.enabledFeatures = {true, false, true, true}
        """)
        
        XCTAssertEqual(config.enabledFeatures.count, 4)
        XCTAssertEqual(config.enabledFeatures, [true, false, true, true])
        
        // Count enabled features
        let enabledCount = try lua.executeReturning("""
            local count = 0
            for _, enabled in ipairs(config.enabledFeatures) do
                if enabled then count = count + 1 end
            end
            return count
        """, as: Int.self)
        
        XCTAssertEqual(enabledCount, 3)
    }
    
    func testEmptyArrays() throws {
        let lua = try LuaState()
        lua.register(ConfigModel.self, as: "ConfigModel")
        
        let config = ConfigModel()
        lua.globals["config"] = config
        
        // Set empty arrays
        _ = try lua.execute("""
            config.servers = {}
            config.ports = {}
            config.weights = {}
            config.enabledFeatures = {}
        """)
        
        XCTAssertTrue(config.servers.isEmpty)
        XCTAssertTrue(config.ports.isEmpty)
        XCTAssertTrue(config.weights.isEmpty)
        XCTAssertTrue(config.enabledFeatures.isEmpty)
    }
    
    func testArrayValidation() throws {
        let lua = try LuaState()
        lua.register(ValidatedArrayModel.self, as: "ValidatedModel")
        
        let model = ValidatedArrayModel()
        lua.globals["model"] = model
        
        // Valid IPs
        _ = try lua.execute("""
            model.allowedIPs = {"192.168.1.1", "10.0.0.1", "172.16.0.1"}
        """)
        
        XCTAssertEqual(model.allowedIPs.count, 3)
        
        // Invalid IP format
        XCTAssertThrowsError(try lua.execute("""
            model.allowedIPs = {"192.168.1.1", "invalid.ip", "10.0.0.1"}
        """)) { error in
            guard case LuaError.runtime(let message) = error else {
                XCTFail("Expected runtime error")
                return
            }
            XCTAssertTrue(message.contains("Invalid IP format"))
        }
        
        // Valid scores
        _ = try lua.execute("""
            model.scores = {85, 90, 77, 100}
        """)
        
        XCTAssertEqual(model.scores.count, 4)
        
        // Invalid score range
        XCTAssertThrowsError(try lua.execute("""
            model.scores = {85, 150, 77}  -- 150 is out of range
        """)) { error in
            guard case LuaError.runtime(let message) = error else {
                XCTFail("Expected runtime error")
                return
            }
            XCTAssertTrue(message.contains("Score must be between 0 and 100"))
        }
    }
    
    func testMixedTypes() throws {
        let lua = try LuaState()
        lua.register(ConfigModel.self, as: "ConfigModel")
        
        let config = ConfigModel()
        lua.globals["config"] = config
        
        // Set both array and regular properties
        _ = try lua.execute("""
            config.name = "production"
            config.timeout = 60
            config.servers = {"api1.example.com", "api2.example.com"}
            config.ports = {443, 443}
        """)
        
        XCTAssertEqual(config.name, "production")
        XCTAssertEqual(config.timeout, 60)
        XCTAssertEqual(config.servers.count, 2)
        XCTAssertEqual(config.ports.count, 2)
    }
    
    func testArrayTypeErrors() throws {
        let lua = try LuaState()
        lua.register(ConfigModel.self, as: "ConfigModel")
        
        let config = ConfigModel()
        lua.globals["config"] = config
        
        // Try to set non-array type
        XCTAssertThrowsError(try lua.execute("""
            config.servers = "not an array"
        """)) { error in
            guard case LuaError.runtime(let message) = error else {
                XCTFail("Expected runtime error")
                return
            }
            XCTAssertTrue(message.contains("Expected array of strings"))
        }
        
        // Test mixed array/dictionary table
        _ = try lua.execute("""
            config.ports = {first = 80, second = 443}  -- dictionary, not array
        """)
        
        // This will result in an empty array since there are no numeric keys
        XCTAssertEqual(config.ports.count, 0)
    }
    
    func testArrayFromSwiftToLua() throws {
        let lua = try LuaState()
        lua.register(ConfigModel.self, as: "ConfigModel")
        
        let config = ConfigModel()
        config.servers = ["db1.local", "db2.local", "db3.local"]
        config.ports = [5432, 5432, 5433]
        lua.globals["config"] = config
        
        // Read arrays in Lua
        let serverCount = try lua.executeReturning("""
            return #config.servers
        """, as: Int.self)
        
        XCTAssertEqual(serverCount, 3)
        
        // Iterate over array in Lua
        _ = try lua.execute("""
            for i, server in ipairs(config.servers) do
                print(i, server)
            end
        """)
        
        // Modify and check
        _ = try lua.execute("""
            local servers = config.servers
            servers[1] = "primary.local"
            config.servers = servers
        """)
        
        XCTAssertEqual(config.servers[0], "primary.local")
    }
}