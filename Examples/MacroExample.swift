//
//  MacroExample.swift
//  LuaKit
//
//  Example showing proper usage of the @LuaBridgeable macro
//

import Foundation
import CLua  // Required for the generated code
import LuaKit

// MARK: - Example 1: Basic Usage with @LuaBridgeable

@LuaBridgeable
public class Person: LuaBridgeable {  // Must explicitly conform to LuaBridgeable
    public var name: String
    public var age: Int
    private var id: UUID  // Private properties are not bridged
    
    public init(name: String, age: Int) {
        self.name = name
        self.age = age
        self.id = UUID()
    }
    
    public func greet() -> String {
        return "Hello, I'm \(name) and I'm \(age) years old"
    }
    
    public func haveBirthday() {
        age += 1
    }
    
    // Required for __tostring metamethod
    public var description: String {
        return "Person(name: \(name), age: \(age))"
    }
}

// MARK: - Example 2: Using @LuaIgnore to exclude members

@LuaBridgeable
public class BankAccount: LuaBridgeable {
    public var accountHolder: String
    public var balance: Double
    
    @LuaIgnore
    public var accountNumber: String  // Sensitive data - not exposed to Lua
    
    @LuaIgnore
    public var pinCode: String  // Sensitive data - not exposed to Lua
    
    public init(holder: String, number: String, pin: String) {
        self.accountHolder = holder
        self.accountNumber = number
        self.pinCode = pin
        self.balance = 0.0
    }
    
    public func deposit(_ amount: Double) {
        balance += amount
    }
    
    public func withdraw(_ amount: Double) -> Bool {
        if amount <= balance {
            balance -= amount
            return true
        }
        return false
    }
    
    @LuaIgnore
    public func transferToAccount(_ accountNumber: String, amount: Double) {
        // This sensitive operation is not exposed to Lua
    }
    
    public var description: String {
        return "BankAccount(holder: \(accountHolder), balance: \(balance))"
    }
}

// MARK: - Example 3: Explicit mode with @LuaOnly

@LuaBridgeable(mode: .explicit)
public class SecureService: LuaBridgeable {
    private var data: [String: Any] = [:]
    
    @LuaOnly
    public var serviceName: String  // Only this property is exposed
    
    public var internalVersion: String  // Not exposed in explicit mode
    
    public init(name: String, version: String) {
        self.serviceName = name
        self.internalVersion = version
    }
    
    @LuaOnly
    public func getPublicInfo() -> String {
        return "Service: \(serviceName)"
    }
    
    public func getInternalInfo() -> String {
        // Not exposed in explicit mode
        return "Internal: \(internalVersion)"
    }
    
    public func performInternalOperation() {
        // Not exposed in explicit mode
    }
    
    public var description: String {
        return "SecureService(name: \(serviceName))"
    }
}

// MARK: - Usage Example

public func demonstrateMacroUsage() throws {
    let lua = try LuaState()
    
    // Register our classes
    lua.register(Person.self, as: "Person")
    lua.register(BankAccount.self, as: "BankAccount")
    lua.register(SecureService.self, as: "SecureService")
    
    // Set up print handler
    lua.setPrintHandler { print("Lua: \($0)", terminator: "") }
    
    // Example 1: Basic usage
    print("=== Example 1: Basic Person class ===")
    _ = try lua.execute("""
        local person = Person.new("Alice", 30)
        print(person)  -- Uses __tostring
        print("Name:", person.name)
        print("Age:", person.age)
        print(person:greet())
        
        person:haveBirthday()
        print("After birthday:", person.age)
        
        person.name = "Alicia"
        print("After name change:", person:greet())
    """)
    
    // Example 2: @LuaIgnore demonstration
    print("\n=== Example 2: BankAccount with @LuaIgnore ===")
    _ = try lua.execute("""
        local account = BankAccount.new("John Doe", "12345", "9999")
        print(account)
        print("Holder:", account.accountHolder)
        print("Balance:", account.balance)
        
        account:deposit(1000)
        print("After deposit:", account.balance)
        
        local success = account:withdraw(500)
        print("Withdrawal success:", success)
        print("New balance:", account.balance)
        
        -- Try to access ignored properties (will fail)
        local ok, err = pcall(function() return account.accountNumber end)
        if not ok then
            print("Cannot access accountNumber (as expected)")
        end
        
        -- Try to call ignored method (will fail)
        ok, err = pcall(function() account:transferToAccount("67890", 100) end)
        if not ok then
            print("Cannot call transferToAccount (as expected)")
        end
    """)
    
    // Example 3: Explicit mode with @LuaOnly
    print("\n=== Example 3: SecureService with explicit mode ===")
    _ = try lua.execute("""
        local service = SecureService.new("API Gateway", "v2.0")
        print(service)
        print("Service name:", service.serviceName)
        print("Public info:", service:getPublicInfo())
        
        -- Try to access non-exposed property (will fail)
        local ok, err = pcall(function() return service.internalVersion end)
        if not ok then
            print("Cannot access internalVersion (as expected in explicit mode)")
        end
        
        -- Try to call non-exposed method (will fail)
        ok, err = pcall(function() return service:getInternalInfo() end)
        if not ok then
            print("Cannot call getInternalInfo (as expected in explicit mode)")
        end
    """)
}