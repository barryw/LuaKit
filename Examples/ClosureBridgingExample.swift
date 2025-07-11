//
//  ClosureBridgingExample.swift
//  LuaKit
//
//  Demonstrates closure bridging functionality
//

import Foundation
import LuaKit
import Lua

public func demonstrateClosureBridging() throws {
    print("=== Closure Bridging Example ===\n")
    
    let lua = try LuaState()
    lua.setPrintHandler { output in
        print("Lua: \(output)", terminator: "")
    }
    
    // Example 1: Simple closure returning a value
    print("1. Simple Closure:")
    lua.globals["getCurrentTime"] = LuaFunction {
        return Date().timeIntervalSince1970
    }
    
    _ = try lua.execute("""
        local time = getCurrentTime()
        print("Current time:", time)
    """)
    
    // Example 2: Closure with parameters
    print("\n2. Closure with Parameters:")
    lua.globals["formatMessage"] = LuaFunction { (name: String, age: Int) in
        return "\(name) is \(age) years old"
    }
    
    _ = try lua.execute("""
        local msg = formatMessage("Alice", 30)
        print(msg)
    """)
    
    // Example 3: Closure returning LuaBridgeable object
    print("\n3. Closure Returning Swift Object:")
    
    @LuaBridgeable
    class User: LuaBridgeable {
        public var name: String
        public var email: String
        
        public init(name: String, email: String) {
            self.name = name
            self.email = email
        }
    }
    
    lua.register(User.self, as: "User")
    
    lua.globals["createUser"] = LuaFunction { (name: String) -> User in
        return User(name: name, email: "\(name.lowercased())@example.com")
    }
    
    _ = try lua.execute("""
        local user = createUser("Bob")
        print("User:", user.name, "Email:", user.email)
    """)
    
    // Example 4: Using registerFunction convenience methods
    print("\n4. Register Function Convenience:")
    
    lua.registerFunction("calculateArea") { (width: Double, height: Double) in
        return width * height
    }
    
    lua.registerFunction("greet") {
        return "Hello from Swift!"
    }
    
    _ = try lua.execute("""
        print(greet())
        print("Area of 5x3 rectangle:", calculateArea(5, 3))
    """)
    
    // Example 5: Closure properties in bridged classes
    print("\n5. Closure Properties:")
    
    @LuaBridgeable
    class EventHandler: LuaBridgeable {
        public var onEvent: ((String) -> Void)?
        public var transformer: ((Int) -> Int)?
        
        public init() {
            // Set default handlers
            self.onEvent = { event in
                print("Swift: Event received: \(event)")
            }
            self.transformer = { value in
                return value * 2
            }
        }
        
        public func triggerEvent(_ name: String) {
            onEvent?(name)
        }
        
        public func transform(_ value: Int) -> Int {
            return transformer?(value) ?? value
        }
    }
    
    lua.register(EventHandler.self, as: "EventHandler")
    
    _ = try lua.execute("""
        local handler = EventHandler.new()
        
        -- Call the closure property directly
        handler.onEvent("test_event")
        
        -- Use the transformer
        local result = handler.transformer(21)
        print("Transformed value:", result)
        
        -- Call methods that use the closures
        handler:triggerEvent("button_clicked")
        print("Transform 10:", handler:transform(10))
    """)
    
    // Example 6: Error handling in closures
    print("\n6. Error Handling:")
    
    lua.globals["riskyOperation"] = LuaFunction { (shouldFail: Bool) -> String? in
        if shouldFail {
            return nil
        }
        return "Success!"
    }
    
    _ = try lua.execute("""
        local result1 = riskyOperation(false)
        print("Result 1:", result1)
        
        local result2 = riskyOperation(true)
        if result2 == nil then
            print("Result 2: Operation failed (nil)")
        end
    """)
    
    print("\n=== Closure Bridging Example Complete ===")
}

// Example of a more complex use case
public func demonstrateAdvancedClosureBridging() throws {
    print("\n=== Advanced Closure Bridging ===\n")
    
    let lua = try LuaState()
    lua.setPrintHandler { output in
        print("Lua: \(output)", terminator: "")
    }
    
    // Create a callback-based API
    @LuaBridgeable
    class NetworkManager: LuaBridgeable {
        public var onSuccess: ((String) -> Void)?
        public var onError: ((String) -> Void)?
        
        public init() {}
        
        public func makeRequest(_ url: String) {
            // Simulate async operation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if url.starts(with: "http") {
                    self?.onSuccess?("Response from \(url)")
                } else {
                    self?.onError?("Invalid URL: \(url)")
                }
            }
        }
    }
    
    lua.register(NetworkManager.self, as: "NetworkManager")
    
    // Create a data processor with transformation closures
    lua.globals["createProcessor"] = LuaFunction {
        return [
            "double": { (n: Int) in n * 2 },
            "square": { (n: Int) in n * n },
            "negate": { (n: Int) in -n }
        ]
    }
    
    _ = try lua.execute("""
        -- Network example
        local net = NetworkManager.new()
        net.onSuccess = function(response)
            print("Success:", response)
        end
        net.onError = function(error)
            print("Error:", error)
        end
        
        net:makeRequest("https://api.example.com")
        net:makeRequest("invalid-url")
        
        -- Processor example
        local processor = createProcessor()
        print("Double 5:", processor.double(5))
        print("Square 4:", processor.square(4))
        print("Negate 10:", processor.negate(10))
    """)
    
    // Wait for async operations
    Thread.sleep(forTimeInterval: 0.2)
    
    print("\n=== Advanced Example Complete ===")
}