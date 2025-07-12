//
//  LuaAsyncSupport.swift
//  LuaKit
//
//  Async/await support for Lua
//

import Foundation
import Lua

/// Async operation handle for Lua
public class LuaAsyncHandle {
    private let id: UUID
    private var callback: ((Any?, Error?) -> Void)?
    private var isCompleted = false
    
    public init() {
        self.id = UUID()
    }
    
    public func complete(result: Any?, error: Error?) {
        guard !isCompleted else { return }
        isCompleted = true
        callback?(result, error)
        callback = nil
    }
    
    public func onComplete(_ callback: @escaping (Any?, Error?) -> Void) {
        if isCompleted {
            // Already completed, call immediately
            callback(nil, nil)
        } else {
            self.callback = callback
        }
    }
}

/// Registry for active async operations
public class LuaAsyncRegistry {
    private static var activeHandles: [UUID: LuaAsyncHandle] = [:]
    
    public static func register(_ handle: LuaAsyncHandle) -> UUID {
        let id = UUID()
        activeHandles[id] = handle
        return id
    }
    
    public static func get(_ id: UUID) -> LuaAsyncHandle? {
        return activeHandles[id]
    }
    
    public static func remove(_ id: UUID) {
        activeHandles.removeValue(forKey: id)
    }
}

/// Extension to support async operations in Lua
extension LuaState {
    /// Register async support functions
    public func registerAsyncSupport() {
        // Register helper functions for async operations
        registerFunction("createAsyncHandle") { () -> String in
            let handle = LuaAsyncHandle()
            let id = LuaAsyncRegistry.register(handle)
            return id.uuidString
        }
        
        registerFunction("completeAsync") { (handleId: String, result: String?, error: String?) in
            guard let uuid = UUID(uuidString: handleId),
                  let handle = LuaAsyncRegistry.get(uuid) else {
                return
            }
            
            let err = error.map { NSError(domain: "LuaAsync", code: 0, userInfo: [NSLocalizedDescriptionKey: $0]) }
            handle.complete(result: result, error: err)
            LuaAsyncRegistry.remove(uuid)
        }
    }
}

/// Wrapper for async methods to work with Lua
public struct LuaAsyncWrapper {
    /// Wrap an async function for Lua consumption
    public static func wrap<T>(
        _ asyncFunction: @escaping () async throws -> T
    ) -> () -> Void {
        return {
            Task {
                do {
                    let result = try await asyncFunction()
                    print("Async result: \(result)")
                } catch {
                    print("Async error: \(error)")
                }
            }
        }
    }
}