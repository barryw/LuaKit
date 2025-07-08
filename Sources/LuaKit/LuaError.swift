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
    case typeMismatch(expected: String, got: String)
    case invalidArgument(String)
    case custom(String)
    
    public var errorDescription: String? {
        switch self {
            case .memoryAllocation:
                return "Failed to allocate memory for Lua state"
            case .syntax(let error):
                return "Lua syntax error: \(error)"
            case .runtime(let error):
                return "Lua runtime error: \(error)"
            case .typeMismatch(let expected, let got):
                return "Type mismatch: expected \(expected), got \(got)"
            case .invalidArgument(let message):
                return "Invalid argument: \(message)"
            case .custom(let message):
                return message
        }
    }
}
