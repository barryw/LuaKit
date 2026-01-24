//
//  LuaAsyncSupport.swift
//  LuaKit
//
//  Async/await support for Lua
//

import Foundation
import Lua

/// Async operation handle for Lua.
///
/// Thread-safe via internal locking for Swift 6 concurrency compliance.
public final class LuaAsyncHandle: @unchecked Sendable {
    private let id: UUID
    private var callback: (@Sendable (Any?, Error?) -> Void)?
    private var isCompleted = false
    private let lock = NSLock()

    public init() {
        self.id = UUID()
    }

    public func complete(result: Any?, error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        guard !isCompleted else { return }
        isCompleted = true
        let cb = callback
        callback = nil
        // Call callback outside lock to avoid deadlocks
        lock.unlock()
        cb?(result, error)
        lock.lock()
    }

    public func onComplete(_ callback: @escaping @Sendable (Any?, Error?) -> Void) {
        lock.lock()
        let completed = isCompleted
        if !completed {
            self.callback = callback
        }
        lock.unlock()

        if completed {
            // Already completed, call immediately
            callback(nil, nil)
        }
    }
}

/// Registry for active async operations.
///
/// Thread-safe for Swift 6 concurrency compliance.
public final class LuaAsyncRegistry: @unchecked Sendable {
    /// Thread-safe storage for async handles
    private final class Storage: @unchecked Sendable {
        private var activeHandles: [UUID: LuaAsyncHandle] = [:]
        private let lock = NSLock()

        static let shared = Storage()

        func register(_ handle: LuaAsyncHandle) -> UUID {
            lock.lock()
            defer { lock.unlock() }
            let id = UUID()
            activeHandles[id] = handle
            return id
        }

        func get(_ id: UUID) -> LuaAsyncHandle? {
            lock.lock()
            defer { lock.unlock() }
            return activeHandles[id]
        }

        func remove(_ id: UUID) {
            lock.lock()
            defer { lock.unlock() }
            activeHandles.removeValue(forKey: id)
        }
    }

    public static func register(_ handle: LuaAsyncHandle) -> UUID {
        return Storage.shared.register(handle)
    }

    public static func get(_ id: UUID) -> LuaAsyncHandle? {
        return Storage.shared.get(id)
    }

    public static func remove(_ id: UUID) {
        Storage.shared.remove(id)
    }
}

/// Extension to support async operations in Lua
extension LuaState {
    /// Register async support functions
    public func registerAsyncSupport() {
        // Register helper functions for async operations
        register(function: "createAsyncHandle") { () -> String in
            let handle = LuaAsyncHandle()
            let id = LuaAsyncRegistry.register(handle)
            return id.uuidString
        }

        register(function: "completeAsync") { (handleId: String, result: String?, error: String?) in
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
public struct LuaAsyncWrapper: Sendable {
    /// Wrap an async function for Lua consumption
    public static func wrap<T: Sendable>(
        _ asyncFunction: @escaping @Sendable () async throws -> T
    ) -> @Sendable () -> Void {
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
