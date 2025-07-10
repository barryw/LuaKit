//
//  PropertyChangeExample.swift
//  LuaKit
//
//  Example demonstrating property change notifications
//

import Foundation
import Lua
import LuaKit

// MARK: - Example 1: Basic Change Tracking

@LuaBridgeable
public class AuditedModel: LuaBridgeable {
    public var name: String
    public var value: Int
    private var changeLog: [(timestamp: Date, property: String, oldValue: Any?, newValue: Any?)] = []
    
    public init(name: String, value: Int) {
        self.name = name
        self.value = value
    }
    
    public func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
        changeLog.append((
            timestamp: Date(),
            property: propertyName,
            oldValue: oldValue,
            newValue: newValue
        ))
    }
    
    public func printChangeLog() {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        
        print("Change Log for \(name):")
        for change in changeLog {
            let time = formatter.string(from: change.timestamp)
            print("  [\(time)] \(change.property): \(change.oldValue ?? "nil") → \(change.newValue ?? "nil")")
        }
    }
    
    public var description: String {
        return "AuditedModel(name: \(name), value: \(value))"
    }
}

// MARK: - Example 2: Validation and Business Rules

@LuaBridgeable
public class Product: LuaBridgeable {
    public var name: String
    public var price: Double
    public var stock: Int
    
    public init(name: String, price: Double, stock: Int) {
        self.name = name
        self.price = price
        self.stock = stock
    }
    
    public func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        switch propertyName {
        case "price":
            // Don't allow negative prices
            guard let newPrice = newValue as? Double, newPrice >= 0 else {
                return .failure(PropertyValidationError("Price cannot be negative"))
            }
            // Don't allow price increases over 50%
            if let oldPrice = oldValue as? Double, newPrice > oldPrice * 1.5 {
                return .failure(PropertyValidationError("Price increase too high (max 50% allowed)"))
            }
        case "stock":
            // Don't allow negative stock
            guard let newStock = newValue as? Int, newStock >= 0 else {
                return .failure(PropertyValidationError("Stock cannot be negative"))
            }
        case "name":
            // Don't allow empty names
            guard let newName = newValue as? String, !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
                return .failure(PropertyValidationError("Product name cannot be empty"))
            }
        default:
            break
        }
        return .success(())
    }
    
    public var description: String {
        return "Product(name: \(name), price: $\(price), stock: \(stock))"
    }
}

// MARK: - Example 3: Persistence and Dirty Tracking

@LuaBridgeable
public class UserProfile: LuaBridgeable {
    public var username: String
    public var email: String
    public var preferences: String
    
    private var isDirty = false
    private var originalValues: [String: Any] = [:]
    
    public init(username: String, email: String, preferences: String = "{}") {
        self.username = username
        self.email = email
        self.preferences = preferences
        
        // Store original values
        originalValues["username"] = username
        originalValues["email"] = email
        originalValues["preferences"] = preferences
    }
    
    public func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        // Validate email format
        if propertyName == "email", let newEmail = newValue as? String {
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegex)
            if !emailTest.evaluate(with: newEmail) {
                return .failure(PropertyValidationError("Invalid email format"))
            }
        }
        return .success(())
    }
    
    public func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
        isDirty = true
        print("UserProfile modified: \(propertyName) changed")
    }
    
    public func save() {
        guard isDirty else {
            print("No changes to save")
            return
        }
        
        // In a real app, this would persist to a database
        print("Saving UserProfile to database...")
        print("  Username: \(username)")
        print("  Email: \(email)")
        print("  Preferences: \(preferences)")
        
        // Update original values
        originalValues["username"] = username
        originalValues["email"] = email
        originalValues["preferences"] = preferences
        
        isDirty = false
        print("Save complete!")
    }
    
    public func revert() {
        guard isDirty else {
            print("No changes to revert")
            return
        }
        
        // Restore original values
        username = originalValues["username"] as? String ?? ""
        email = originalValues["email"] as? String ?? ""
        preferences = originalValues["preferences"] as? String ?? "{}"
        
        isDirty = false
        print("Reverted to original values")
    }
    
    public var hasChanges: Bool {
        return isDirty
    }
    
    public var description: String {
        return "UserProfile(username: \(username), email: \(email)\(isDirty ? " *modified*" : ""))"
    }
}

// MARK: - Demo Function

public func demonstratePropertyChangeNotifications() throws {
    let lua = try LuaState()
    lua.setPrintHandler { print("Lua: \($0)", terminator: "") }
    
    // Example 1: Change Tracking
    print("=== Example 1: Change Tracking ===")
    let audited = AuditedModel(name: "TestModel", value: 100)
    lua.register(AuditedModel.self, as: "AuditedModel")
    lua.globals["model"] = audited
    
    _ = try lua.execute("""
        print("Initial:", model)
        model.value = 200
        model.name = "UpdatedModel"
        model.value = 300
    """)
    
    print("\nSwift side:")
    audited.printChangeLog()
    
    // Example 2: Validation
    print("\n\n=== Example 2: Validation ===")
    let product = Product(name: "Widget", price: 19.99, stock: 50)
    lua.register(Product.self, as: "Product")
    lua.globals["product"] = product
    
    _ = try lua.execute("""
        print("Initial product:", product)
        
        -- Valid changes
        product.price = 25.00  -- OK: reasonable increase
        print("After price change:", product)
        
        -- Invalid changes (will raise errors)
        local function trySet(func, description)
            local success, err = pcall(func)
            if not success then
                print("  ❌", description, "->", err)
            else
                print("  ✅", description)
            end
        end
        
        trySet(function() product.price = -10 end, "Set negative price")
        trySet(function() product.price = 100 end, "Set price > 50% increase")
        trySet(function() product.stock = -5 end, "Set negative stock")
        trySet(function() product.name = "" end, "Set empty name")
        
        print("After rejected changes:", product)
    """)
    
    // Example 3: Persistence
    print("\n\n=== Example 3: Persistence ===")
    let profile = UserProfile(username: "johndoe", email: "john@example.com")
    lua.register(UserProfile.self, as: "UserProfile")
    lua.globals["profile"] = profile
    
    _ = try lua.execute("""
        print("Initial profile:", profile)
        
        -- Make some changes
        profile.email = "john.doe@example.com"
        profile.preferences = '{"theme": "dark", "notifications": true}'
        
        print("After changes:", profile)
    """)
    
    print("\nSwift side:")
    print("Has changes:", profile.hasChanges)
    profile.save()
    
    // Try invalid email
    _ = try lua.execute("""
        local success, err = pcall(function()
            profile.email = "invalid-email"  -- Will be rejected
        end)
        if not success then
            print("Email validation error:", err)
        end
    """)
    
    // Make more changes and revert
    _ = try lua.execute("""
        profile.username = "janedoe"
        print("Changed username:", profile)
    """)
    
    print("\nReverting changes...")
    profile.revert()
    print("After revert:", profile)
}