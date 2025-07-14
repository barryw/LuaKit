//
//  BasicBridgingExample.swift
//  LuaKit Examples
//
//  Demonstrates basic Swift-Lua bridging with @LuaBridgeable
//

import Foundation
import Lua
import LuaKit

@LuaBridgeable
public class Person: LuaBridgeable {
    public var name: String
    public var age: Int
    
    public init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    
    public func greet() -> String {
        return "Hello, I'm \(name) and I'm \(age) years old."
    }
    
    public func haveBirthday() {
        age += 1
        print("\(name) is now \(age) years old!")
    }
}

public func runBasicBridgingExample() throws {
    let lua = try LuaState()
    
    // Register the Person class
    lua.register(Person.self, as: "Person")
    
    // Create and use Person from Lua
    try lua.execute("""
        -- Create a new person
        local person = Person("Alice", 30)
        
        -- Access properties
        print("Name: " .. person.name)
        print("Age: " .. person.age)
        
        -- Call methods
        print(person:greet())
        
        -- Modify properties
        person.name = "Alice Smith"
        person:haveBirthday()
        
        -- Store in global for Swift access
        myPerson = person
    """)
    
    // Access the Person instance from Swift
    if let person: Person = lua.globals["myPerson"] {
        print("\nAccessing from Swift:")
        print("Person: \(person.name), age \(person.age)")
    }
}

// Run the example:
// try runBasicBridgingExample()