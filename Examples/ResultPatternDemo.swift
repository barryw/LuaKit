//
//  ResultPatternDemo.swift
//  LuaKit
//
//  Demonstrates the Result pattern for property validation
//

import Foundation
import Lua
import LuaKit

@LuaBridgeable
public class Configuration: LuaBridgeable {
    public var apiUrl: String
    public var timeout: Int
    public var retryCount: Int
    
    public init(apiUrl: String, timeout: Int, retryCount: Int) {
        self.apiUrl = apiUrl
        self.timeout = timeout
        self.retryCount = retryCount
    }
    
    public func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        switch propertyName {
        case "apiUrl":
            guard let newUrl = newValue as? String,
                  let url = URL(string: newUrl),
                  ["http", "https"].contains(url.scheme) else {
                return .failure(PropertyValidationError("API URL must be a valid HTTP or HTTPS URL"))
            }
            
        case "timeout":
            guard let newTimeout = newValue as? Int else {
                return .failure(PropertyValidationError("Timeout must be an integer"))
            }
            if newTimeout < 1 {
                return .failure(PropertyValidationError("Timeout must be at least 1 second"))
            }
            if newTimeout > 300 {
                return .failure(PropertyValidationError("Timeout cannot exceed 5 minutes (300 seconds)"))
            }
            
        case "retryCount":
            guard let newRetries = newValue as? Int else {
                return .failure(PropertyValidationError("Retry count must be an integer"))
            }
            if newRetries < 0 {
                return .failure(PropertyValidationError("Retry count cannot be negative"))
            }
            if newRetries > 10 {
                return .failure(PropertyValidationError("Maximum 10 retries allowed to prevent infinite loops"))
            }
            
        default:
            break
        }
        
        return .success(())
    }
    
    public var description: String {
        return "Configuration(apiUrl: \(apiUrl), timeout: \(timeout)s, retries: \(retryCount))"
    }
}

public func demonstrateResultPattern() throws {
    let lua = try LuaState()
    lua.setPrintHandler { print("Lua: \($0)", terminator: "") }
    
    print("=== Result Pattern Demo ===\n")
    
    // Register our configuration class
    lua.register(Configuration.self, as: "Configuration")
    
    // Create a configuration instance
    let config = Configuration(
        apiUrl: "https://api.example.com",
        timeout: 30,
        retryCount: 3
    )
    lua.globals["config"] = config
    
    // Demonstrate various validation scenarios
    _ = try lua.execute("""
        print("Initial config:", config)
        print("")
        
        -- Helper function to test property changes
        function testChange(description, changeFunc)
            local success, err = pcall(changeFunc)
            if success then
                print("✅", description, "- Success")
            else
                -- Extract just the error message after the last colon
                local errorMsg = err:match("([^:]+)$"):gsub("^%s+", "")
                print("❌", description, "- Failed:", errorMsg)
            end
        end
        
        print("Testing API URL validation:")
        testChange("Valid HTTPS URL", function() 
            config.apiUrl = "https://newapi.example.com" 
        end)
        testChange("Valid HTTP URL", function() 
            config.apiUrl = "http://localhost:8080/api" 
        end)
        testChange("Invalid URL (no protocol)", function() 
            config.apiUrl = "api.example.com" 
        end)
        testChange("Invalid URL (FTP protocol)", function() 
            config.apiUrl = "ftp://files.example.com" 
        end)
        
        print("\nTesting timeout validation:")
        testChange("Valid timeout (60s)", function() 
            config.timeout = 60 
        end)
        testChange("Too short (0s)", function() 
            config.timeout = 0 
        end)
        testChange("Too long (301s)", function() 
            config.timeout = 301 
        end)
        testChange("Negative timeout", function() 
            config.timeout = -5 
        end)
        
        print("\nTesting retry count validation:")
        testChange("Valid retry count (5)", function() 
            config.retryCount = 5 
        end)
        testChange("Zero retries", function() 
            config.retryCount = 0 
        end)
        testChange("Too many retries (11)", function() 
            config.retryCount = 11 
        end)
        testChange("Negative retries", function() 
            config.retryCount = -1 
        end)
        
        print("\nFinal config:", config)
    """)
    
    print("\n\nSwift side - Final configuration:")
    print("  API URL: \(config.apiUrl)")
    print("  Timeout: \(config.timeout) seconds")
    print("  Retry Count: \(config.retryCount)")
}