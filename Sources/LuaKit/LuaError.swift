//
//  LuaError.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//

import Foundation

public enum LuaError: LocalizedError {
    case memoryAllocation
    case syntax(String)
    case runtime(String)
    case typeMismatch(expected: String, actual: String, context: String?)
    case invalidArgument(String)
    case functionNotFound(String)
    case stateInvalid
    case coroutineError(String)
    case custom(String)

    /// Convenience initializer for typeMismatch without context
    public static func typeMismatch(expected: String, got: String) -> LuaError {
        return .typeMismatch(expected: expected, actual: got, context: nil)
    }

    public var errorDescription: String? {
        switch self {
        case .memoryAllocation:
            return "Failed to allocate memory for Lua state"
        case .syntax(let error):
            return "Lua syntax error: \(error)"
        case .runtime(let error):
            return "Lua runtime error: \(error)"
        case let .typeMismatch(expected, actual, context):
            if let context = context {
                return "Type mismatch in \(context): expected \(expected), got \(actual)"
            }
            return "Type mismatch: expected \(expected), got \(actual)"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        case .functionNotFound(let message):
            return "Function not found: \(message)"
        case .stateInvalid:
            return "Lua state is no longer valid"
        case .coroutineError(let message):
            return "Coroutine error: \(message)"
        case .custom(let message):
            return message
        }
    }
}
