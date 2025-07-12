//
//  PropertyChangeTests.swift
//  LuaKitTests
//
//  Created by Barry Walker on 7/8/25.
//

import Lua
@testable import LuaKit
import XCTest

// Test class that tracks property changes
@LuaBridgeable
class TrackingModel: LuaBridgeable {
    var name: String
    var value: Int

    // Track changes for testing
    var changeHistory: [(property: String, oldValue: Any?, newValue: Any?)] = []
    var rejectedChanges: [(property: String, attemptedValue: Any?)] = []

    init(name: String, value: Int) {
        self.name = name
        self.value = value
    }

    // Implement to track changes
    func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        // Reject negative values for the "value" property
        if propertyName == "value", let newInt = newValue as? Int, newInt < 0 {
            rejectedChanges.append((property: propertyName, attemptedValue: newValue))
            return .failure(PropertyValidationError("Value cannot be negative. Attempted to set \(propertyName) to \(newInt)"))
        }
        return .success(())
    }

    func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
        changeHistory.append((property: propertyName, oldValue: oldValue, newValue: newValue))
    }

    var description: String {
        return "TrackingModel(name: \(name), value: \(value))"
    }
}

// Test class that simulates persistence
@LuaBridgeable
class PersistentModel: LuaBridgeable {
    var data: String
    var isDirty: Bool = false

    // Simulated persistence store
    static var persistedData: [String: Any] = [:]

    init(data: String) {
        self.data = data
    }

    func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
        isDirty = true
        // Simulate saving to persistent store
        PersistentModel.persistedData[propertyName] = newValue
    }

    func save() {
        isDirty = false
        // In a real implementation, this would persist to disk/database
    }

    var description: String {
        return "PersistentModel(data: \(data), isDirty: \(isDirty))"
    }
}

// Test the default behavior (no custom implementation)
@LuaBridgeable
class DefaultBehaviorModel: LuaBridgeable {
    var text: String

    init(text: String) {
        self.text = text
    }

    var description: String {
        return "DefaultBehaviorModel(text: \(text))"
    }
}

class PropertyChangeTests: XCTestCase {
    override func setUp() {
        // Skip these tests for now due to macro issues
        continueAfterFailure = false
    }

    func testDefaultBehavior() throws {
        let lua = try LuaState()
        lua.register(DefaultBehaviorModel.self, as: "DefaultModel")

        // Create instance and modify property
        let result = try lua.executeReturning("""
            model = DefaultModel.new("initial")
            model.text = "changed"
            return model.text
        """, as: String.self)

        XCTAssertEqual(result, "changed", "Property should be changed with default implementation")
    }

    func testPropertyChangeTracking() throws {
        let lua = try LuaState()
        lua.register(TrackingModel.self, as: "TrackingModel")

        // Create a model instance from Swift first
        let model = TrackingModel(name: "Test", value: 10)
        lua.globals["testModel"] = model

        // Modify properties from Lua
        _ = try lua.execute("""
            testModel.name = "Modified"
            testModel.value = 20
        """)

        // Verify changes were tracked
        XCTAssertEqual(model.changeHistory.count, 2, "Should have tracked 2 changes")

        // Check first change (name)
        XCTAssertEqual(model.changeHistory[0].property, "name")
        XCTAssertEqual(model.changeHistory[0].oldValue as? String, "Test")
        XCTAssertEqual(model.changeHistory[0].newValue as? String, "Modified")

        // Check second change (value)
        XCTAssertEqual(model.changeHistory[1].property, "value")
        XCTAssertEqual(model.changeHistory[1].oldValue as? Int, 10)
        XCTAssertEqual(model.changeHistory[1].newValue as? Int, 20)
    }

    func testPropertyChangeRejection() throws {
        let lua = try LuaState()
        lua.register(TrackingModel.self, as: "TrackingModel")

        // Create a model instance
        let model = TrackingModel(name: "Test", value: 10)
        lua.globals["testModel"] = model

        // Try to set a negative value (should be rejected with error)
        XCTAssertThrowsError(try lua.execute("""
            testModel.value = -5
        """)) { error in
            guard case LuaError.runtime(let message) = error else {
                XCTFail("Expected runtime error")
                return
            }
            XCTAssertTrue(message.contains("Value cannot be negative"), "Error message should indicate specific validation failure")
        }

        // Verify the value wasn't changed
        XCTAssertEqual(model.value, 10, "Value should remain unchanged when change is rejected")

        // Verify the rejection was tracked
        XCTAssertEqual(model.rejectedChanges.count, 1, "Should have tracked 1 rejected change")
        XCTAssertEqual(model.rejectedChanges[0].property, "value")
        XCTAssertEqual(model.rejectedChanges[0].attemptedValue as? Int, -5)

        // Verify no changes were recorded in the change history
        XCTAssertEqual(model.changeHistory.count, 0, "No changes should be recorded when rejected")
    }

    func testPersistenceSimulation() throws {
        let lua = try LuaState()
        lua.register(PersistentModel.self, as: "PersistentModel")

        // Clear any previous persisted data
        PersistentModel.persistedData.removeAll()

        // Create and modify a model
        let model = PersistentModel(data: "initial data")
        lua.globals["model"] = model

        _ = try lua.execute("""
            model.data = "modified data"
        """)

        // Verify the model is marked as dirty
        XCTAssertTrue(model.isDirty, "Model should be marked as dirty after property change")

        // Verify data was "persisted"
        XCTAssertEqual(PersistentModel.persistedData["data"] as? String, "modified data")

        // Simulate saving
        model.save()
        XCTAssertFalse(model.isDirty, "Model should not be dirty after save")
    }

    func testMultiplePropertyTypes() throws {
        let lua = try LuaState()

        // Test with the MacroTestPerson class which has different property types
        lua.register(MacroTestPerson.self, as: "Person")

        // Create a custom tracking person
        @LuaBridgeable
        class TrackingPerson: LuaBridgeable {
            var name: String
            var age: Int
            var active: Bool
            var score: Double

            var changes: [String] = []

            init(name: String, age: Int) {
                self.name = name
                self.age = age
                self.active = true
                self.score = 0.0
            }

            func luaPropertyDidChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) {
                changes.append("\(propertyName): \(String(describing: oldValue)) -> \(String(describing: newValue))")
            }

            var description: String {
                return "TrackingPerson(name: \(name), age: \(age))"
            }
        }

        lua.register(TrackingPerson.self, as: "TrackingPerson")

        let person = TrackingPerson(name: "John", age: 30)
        lua.globals["person"] = person

        // Test different property types
        _ = try lua.execute("""
            person.name = "Jane"
            person.age = 31
            person.active = false
            person.score = 95.5
        """)

        // Verify all changes were tracked with correct types
        XCTAssertEqual(person.changes.count, 4)
        XCTAssertTrue(person.changes[0].contains("name: Optional(\"John\") -> Optional(\"Jane\")"))
        XCTAssertTrue(person.changes[1].contains("age: Optional(30) -> Optional(31)"))
        XCTAssertTrue(person.changes[2].contains("active: Optional(true) -> Optional(false)"))
        XCTAssertTrue(person.changes[3].contains("score: Optional(0.0) -> Optional(95.5)"))
    }
}
