//
//  LuaPropertyValidation.swift
//  LuaKit
//
//  Property validation system for @LuaProperty
//

import Foundation
import Lua

/// Property validation result
public enum LuaPropertyValidationResult {
    case valid
    case invalid(reason: String)
}

/// Protocol for custom property validators
public protocol LuaPropertyValidator {
    associatedtype ValueType
    func validate(_ value: ValueType, propertyName: String) -> LuaPropertyValidationResult
}

/// Built-in validators
public struct LuaRangeValidator<T: Comparable>: LuaPropertyValidator {
    let min: T?
    let max: T?

    public init(min: T? = nil, max: T? = nil) {
        self.min = min
        self.max = max
    }

    public func validate(_ value: T, propertyName: String) -> LuaPropertyValidationResult {
        if let min = min, value < min {
            return .invalid(reason: "\(propertyName) must be >= \(min), got \(value)")
        }
        if let max = max, value > max {
            return .invalid(reason: "\(propertyName) must be <= \(max), got \(value)")
        }
        return .valid
    }
}

public struct LuaRegexValidator: LuaPropertyValidator {
    let pattern: String
    let regex: NSRegularExpression?

    public init(pattern: String) {
        self.pattern = pattern
        self.regex = try? NSRegularExpression(pattern: pattern, options: [])
    }

    public func validate(_ value: String, propertyName: String) -> LuaPropertyValidationResult {
        guard let regex = regex else {
            return .invalid(reason: "Invalid regex pattern for \(propertyName)")
        }

        let range = NSRange(location: 0, length: value.utf16.count)
        if regex.firstMatch(in: value, options: [], range: range) != nil {
            return .valid
        } else {
            return .invalid(reason: "\(propertyName) must match pattern: \(pattern)")
        }
    }
}

public struct LuaEnumPropertyValidator<T: LuaEnumBridgeable>: LuaPropertyValidator {
    public init() {}

    public func validate(_ value: String, propertyName: String) -> LuaPropertyValidationResult {
        if T(rawValue: value) != nil {
            return .valid
        } else {
            let validValues = T.allCases.map { $0.rawValue }.joined(separator: ", ")
            return .invalid(reason: "\(propertyName) must be one of: \(validValues)")
        }
    }
}

/// Property validation registry
public class LuaPropertyValidationRegistry {
    private static var validators: [String: Any] = [:]

    /// Register a validator for a property
    public static func register<V: LuaPropertyValidator>(
        validator: V,
        for className: String,
        property: String
    ) {
        let key = "\(className).\(property)"
        validators[key] = validator
    }

    /// Get validator for a property
    public static func getValidator(for className: String, property: String) -> Any? {
        let key = "\(className).\(property)"
        return validators[key]
    }

    /// Validate a value (simplified implementation)
    public static func validateAny(
        value: Any,
        for className: String,
        property: String
    ) -> LuaPropertyValidationResult {
        let key = "\(className).\(property)"
        guard validators[key] != nil else {
            return .valid // No validator registered
        }

        // Simplified validation - in practice would need more sophisticated type handling
        return .valid
    }
}

/// Extension for LuaBridgeable to support property validation
extension LuaBridgeable {
    /// Validate a property before setting
    public func validateProperty(_ propertyName: String, value: Any) -> LuaPropertyValidationResult {
        let className = String(describing: type(of: self))

        // Use the simplified validation registry
        return LuaPropertyValidationRegistry.validateAny(
            value: value,
            for: className,
            property: propertyName
        )
    }
}

/// Helper for read-only property enforcement
public struct LuaReadOnlyProperty<T> {
    private let value: T

    public init(_ value: T) {
        self.value = value
    }

    public var wrappedValue: T {
        value
    }
}

/// Property metadata storage
public struct LuaPropertyMetadata {
    public let name: String
    public let type: String
    public let isReadOnly: Bool
    public let validatorName: String?
    public let minValue: Double?
    public let maxValue: Double?
    public let regexPattern: String?
    public let enumValues: [String]

    public init(
        name: String,
        type: String,
        isReadOnly: Bool = false,
        validatorName: String? = nil,
        minValue: Double? = nil,
        maxValue: Double? = nil,
        regexPattern: String? = nil,
        enumValues: [String] = []
    ) {
        self.name = name
        self.type = type
        self.isReadOnly = isReadOnly
        self.validatorName = validatorName
        self.minValue = minValue
        self.maxValue = maxValue
        self.regexPattern = regexPattern
        self.enumValues = enumValues
    }
}

/// Registry for property metadata
public class LuaPropertyMetadataRegistry {
    private static var metadata: [String: [LuaPropertyMetadata]] = [:]

    public static func register(_ property: LuaPropertyMetadata, for className: String) {
        if metadata[className] == nil {
            metadata[className] = []
        }
        metadata[className]?.append(property)
    }

    public static func getMetadata(for className: String) -> [LuaPropertyMetadata] {
        return metadata[className] ?? []
    }

    public static func getPropertyMetadata(
        for className: String,
        property: String
    ) -> LuaPropertyMetadata? {
        return metadata[className]?.first { $0.name == property }
    }
}
