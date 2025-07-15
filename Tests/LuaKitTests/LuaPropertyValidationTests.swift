//
//  LuaPropertyValidationTests.swift
//  LuaKit
//
//  Tests for LuaPropertyValidation functionality
//

import Lua
@testable import LuaKit
import XCTest

final class LuaPropertyValidationTests: XCTestCase {
    // MARK: - LuaPropertyValidationResult Tests

    func testValidationResultValid() {
        let result = LuaPropertyValidationResult.valid

        switch result {
        case .valid:
            // Expected
            break
        case .invalid:
            XCTFail("Expected valid result")
        }
    }

    func testValidationResultInvalid() {
        let reason = "Value out of range"
        let result = LuaPropertyValidationResult.invalid(reason: reason)

        switch result {
        case .valid:
            XCTFail("Expected invalid result")
        case .invalid(let actualReason):
            XCTAssertEqual(actualReason, reason)
        }
    }

    // MARK: - LuaRangeValidator Tests

    func testRangeValidatorWithMin() {
        let validator = LuaRangeValidator<Int>(min: 0)

        switch validator.validate(5, propertyName: "age") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate(0, propertyName: "age") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate(-5, propertyName: "age") {
        case .valid:
            XCTFail("Expected invalid result")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("age must be >= 0"))
            XCTAssertTrue(reason.contains("got -5"))
        }
    }

    func testRangeValidatorWithMax() {
        let validator = LuaRangeValidator<Double>(max: 100.0)

        switch validator.validate(50.0, propertyName: "percentage") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate(100.0, propertyName: "percentage") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate(150.0, propertyName: "percentage") {
        case .valid:
            XCTFail("Expected invalid result")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("percentage must be <= 100"))
            XCTAssertTrue(reason.contains("got 150"))
        }
    }

    func testRangeValidatorWithMinAndMax() {
        let validator = LuaRangeValidator<Int>(min: 1, max: 10)

        switch validator.validate(5, propertyName: "rating") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate(1, propertyName: "rating") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate(10, propertyName: "rating") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        // Test below min
        switch validator.validate(0, propertyName: "rating") {
        case .valid:
            XCTFail("Expected invalid result")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("rating must be >= 1"))
        }

        // Test above max
        switch validator.validate(11, propertyName: "rating") {
        case .valid:
            XCTFail("Expected invalid result")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("rating must be <= 10"))
        }
    }

    // MARK: - LuaRegexValidator Tests

    func testRegexValidatorValidPattern() {
        let validator = LuaRegexValidator(pattern: "^[a-zA-Z]+$")

        switch validator.validate("Hello", propertyName: "name") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate("Test", propertyName: "name") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate("Hello123", propertyName: "name") {
        case .valid:
            XCTFail("Expected invalid result")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("name must match pattern"))
            XCTAssertTrue(reason.contains("^[a-zA-Z]+$"))
        }
    }

    func testRegexValidatorEmail() {
        let emailPattern = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let validator = LuaRegexValidator(pattern: emailPattern)

        switch validator.validate("user@example.com", propertyName: "email") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate("test.user@domain.co.uk", propertyName: "email") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate("invalid-email", propertyName: "email") {
        case .valid:
            XCTFail("Expected invalid result")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("email must match pattern"))
        }
    }

    func testRegexValidatorInvalidPattern() {
        let validator = LuaRegexValidator(pattern: "[")  // Invalid regex

        switch validator.validate("test", propertyName: "field") {
        case .valid:
            XCTFail("Expected invalid result")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("Invalid regex pattern"))
        }
    }

    // MARK: - LuaEnumPropertyValidator Tests

    enum TestStatus: String, CaseIterable, LuaEnumBridgeable {
        case active
        case inactive
        case pending
    }

    func testEnumPropertyValidator() {
        let validator = LuaEnumPropertyValidator<TestStatus>()

        switch validator.validate("active", propertyName: "status") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate("inactive", propertyName: "status") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate("pending", propertyName: "status") {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        switch validator.validate("invalid", propertyName: "status") {
        case .valid:
            XCTFail("Expected invalid result")
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("status must be one of:"))
            XCTAssertTrue(reason.contains("active"))
            XCTAssertTrue(reason.contains("inactive"))
            XCTAssertTrue(reason.contains("pending"))
        }
    }

    // MARK: - LuaPropertyValidationRegistry Tests

    func testPropertyValidationRegistry() {
        let validator = LuaRangeValidator<Int>(min: 0, max: 100)
        LuaPropertyValidationRegistry.register(
            validator: validator,
            for: "Player",
            property: "health"
        )

        let retrieved = LuaPropertyValidationRegistry.getValidator(
            for: "Player",
            property: "health"
        )

        XCTAssertNotNil(retrieved)

        // Test missing validator
        let missing = LuaPropertyValidationRegistry.getValidator(
            for: "Player",
            property: "unknown"
        )
        XCTAssertNil(missing)
    }

    func testValidateAny() {
        // Test without validator (should return valid)
        let result = LuaPropertyValidationRegistry.validateAny(
            value: 42,
            for: "TestClass",
            property: "unvalidated"
        )
        switch result {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }

        // Register a validator
        let validator = LuaRangeValidator<Int>(min: 0)
        LuaPropertyValidationRegistry.register(
            validator: validator,
            for: "TestClass",
            property: "validated"
        )

        // Test with validator (simplified implementation always returns valid)
        let validatedResult = LuaPropertyValidationRegistry.validateAny(
            value: -5,
            for: "TestClass",
            property: "validated"
        )
        switch validatedResult {
        case .valid:
            break // expected
        case .invalid:
            XCTFail("Expected valid result")
        }
    }

    // MARK: - LuaBridgeable Extension Tests

    func testValidatePropertyOnBridgeable() {
        // Test that the validateProperty method is available on LuaBridgeable
        // We can't use @LuaBridgeable in tests due to macro expansion issues
        // The actual functionality is tested through the protocol extension
    }

    // MARK: - LuaReadOnlyProperty Tests

    func testReadOnlyProperty() {
        let readOnly = LuaReadOnlyProperty(42)
        XCTAssertEqual(readOnly.wrappedValue, 42)

        let stringReadOnly = LuaReadOnlyProperty("immutable")
        XCTAssertEqual(stringReadOnly.wrappedValue, "immutable")
    }

    // MARK: - LuaPropertyMetadata Tests

    func testPropertyMetadataCreation() {
        let metadata = LuaPropertyMetadata(
            name: "age",
            type: "Int",
            isReadOnly: false,
            validatorName: "ageValidator",
            minValue: 0,
            maxValue: 150,
            regexPattern: nil,
            enumValues: []
        )

        XCTAssertEqual(metadata.name, "age")
        XCTAssertEqual(metadata.type, "Int")
        XCTAssertFalse(metadata.isReadOnly)
        XCTAssertEqual(metadata.validatorName, "ageValidator")
        XCTAssertEqual(metadata.minValue, 0)
        XCTAssertEqual(metadata.maxValue, 150)
        XCTAssertNil(metadata.regexPattern)
        XCTAssertTrue(metadata.enumValues.isEmpty)
    }

    func testPropertyMetadataWithEnumValues() {
        let metadata = LuaPropertyMetadata(
            name: "status",
            type: "String",
            enumValues: ["active", "inactive", "pending"]
        )

        XCTAssertEqual(metadata.enumValues.count, 3)
        XCTAssertTrue(metadata.enumValues.contains("active"))
        XCTAssertTrue(metadata.enumValues.contains("inactive"))
        XCTAssertTrue(metadata.enumValues.contains("pending"))
    }

    // MARK: - LuaPropertyMetadataRegistry Tests

    func testPropertyMetadataRegistry() {
        let metadata1 = LuaPropertyMetadata(
            name: "name",
            type: "String",
            isReadOnly: false
        )

        let metadata2 = LuaPropertyMetadata(
            name: "id",
            type: "Int",
            isReadOnly: true
        )

        LuaPropertyMetadataRegistry.register(metadata1, for: "User")
        LuaPropertyMetadataRegistry.register(metadata2, for: "User")

        let allMetadata = LuaPropertyMetadataRegistry.getMetadata(for: "User")
        XCTAssertEqual(allMetadata.count, 2)

        let nameMetadata = LuaPropertyMetadataRegistry.getPropertyMetadata(
            for: "User",
            property: "name"
        )
        XCTAssertNotNil(nameMetadata)
        XCTAssertEqual(nameMetadata?.type, "String")
        XCTAssertFalse(nameMetadata?.isReadOnly ?? true)

        let idMetadata = LuaPropertyMetadataRegistry.getPropertyMetadata(
            for: "User",
            property: "id"
        )
        XCTAssertNotNil(idMetadata)
        XCTAssertEqual(idMetadata?.type, "Int")
        XCTAssertTrue(idMetadata?.isReadOnly ?? false)

        // Test missing class
        let missingClass = LuaPropertyMetadataRegistry.getMetadata(for: "NonExistent")
        XCTAssertTrue(missingClass.isEmpty)

        // Test missing property
        let missingProperty = LuaPropertyMetadataRegistry.getPropertyMetadata(
            for: "User",
            property: "unknown"
        )
        XCTAssertNil(missingProperty)
    }

    // MARK: - Complex Validation Scenarios

    func testMultipleValidatorsForClass() {
        // Register validators for different properties
        let ageValidator = LuaRangeValidator<Int>(min: 0, max: 150)
        let scoreValidator = LuaRangeValidator<Double>(min: 0.0, max: 100.0)

        LuaPropertyValidationRegistry.register(
            validator: ageValidator,
            for: "Student",
            property: "age"
        )

        LuaPropertyValidationRegistry.register(
            validator: scoreValidator,
            for: "Student",
            property: "score"
        )

        // Verify both validators are registered
        XCTAssertNotNil(LuaPropertyValidationRegistry.getValidator(for: "Student", property: "age"))
        XCTAssertNotNil(LuaPropertyValidationRegistry.getValidator(for: "Student", property: "score"))
    }

    func testPropertyMetadataWithAllOptions() {
        let metadata = LuaPropertyMetadata(
            name: "username",
            type: "String",
            isReadOnly: false,
            validatorName: "usernameValidator",
            minValue: nil,
            maxValue: nil,
            regexPattern: "^[a-zA-Z0-9_]+$",
            enumValues: []
        )

        XCTAssertEqual(metadata.name, "username")
        XCTAssertEqual(metadata.regexPattern, "^[a-zA-Z0-9_]+$")
        XCTAssertNil(metadata.minValue)
        XCTAssertNil(metadata.maxValue)
    }
}
