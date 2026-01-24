//
//  LuaDebug.swift
//  LuaKit
//
//  Debug helpers for LuaBridgeable types
//

import Foundation

/// Global debug configuration for LuaKit.
///
/// Thread-safe for Swift 6 concurrency compliance.
public struct LuaDebugConfig: Sendable {
    /// Log level for debug output
    public enum LogLevel: Int, Sendable {
        case verbose = 0
        case info = 1
        case warning = 2
        case error = 3
    }

    /// Thread-safe storage for configuration
    private final class Storage: @unchecked Sendable {
        var isEnabled = false
        var logLevel: LogLevel = .info
        var logger: (@Sendable (String, LogLevel) -> Void)? = { message, level in
            let prefix: String
            switch level {
            case .verbose:
                prefix = "[VERBOSE]"
            case .info:
                prefix = "[INFO]"
            case .warning:
                prefix = "[WARNING]"
            case .error:
                prefix = "[ERROR]"
            }
            print("\(prefix) LuaKit: \(message)")
        }
        let lock = NSLock()

        static let shared = Storage()
    }

    /// Enable debug logging globally
    public static var isEnabled: Bool {
        get {
            Storage.shared.lock.lock()
            defer { Storage.shared.lock.unlock() }
            return Storage.shared.isEnabled
        }
        set {
            Storage.shared.lock.lock()
            defer { Storage.shared.lock.unlock() }
            Storage.shared.isEnabled = newValue
        }
    }

    /// Current log level
    public static var logLevel: LogLevel {
        get {
            Storage.shared.lock.lock()
            defer { Storage.shared.lock.unlock() }
            return Storage.shared.logLevel
        }
        set {
            Storage.shared.lock.lock()
            defer { Storage.shared.lock.unlock() }
            Storage.shared.logLevel = newValue
        }
    }

    /// Custom logger function
    public static var logger: (@Sendable (String, LogLevel) -> Void)? {
        get {
            Storage.shared.lock.lock()
            defer { Storage.shared.lock.unlock() }
            return Storage.shared.logger
        }
        set {
            Storage.shared.lock.lock()
            defer { Storage.shared.lock.unlock() }
            Storage.shared.logger = newValue
        }
    }

    /// Log a message if debugging is enabled
    public static func log(_ message: String, level: LogLevel = .info) {
        Storage.shared.lock.lock()
        let enabled = Storage.shared.isEnabled
        let currentLevel = Storage.shared.logLevel
        let loggerFn = Storage.shared.logger
        Storage.shared.lock.unlock()

        guard enabled && level.rawValue >= currentLevel.rawValue else { return }
        loggerFn?(message, level)
    }
}

/// Protocol for types that support debug mode
public protocol LuaDebuggable {
    /// Whether debug mode is enabled for this instance
    var luaDebugEnabled: Bool { get set }

    /// Log a debug message for this instance
    func luaDebugLog(_ message: String, level: LuaDebugConfig.LogLevel)
}

/// Default implementation for LuaDebuggable
public extension LuaDebuggable {
    func luaDebugLog(_ message: String, level: LuaDebugConfig.LogLevel = .info) {
        guard luaDebugEnabled else { return }
        let typeName = String(describing: type(of: self))
        LuaDebugConfig.log("[\(typeName)] \(message)", level: level)
    }
}

/// Debug context for method calls
public struct LuaMethodDebugContext: Sendable {
    public let className: String
    public let methodName: String
    public let parameters: [(name: String, value: String)]
    public let startTime: Date

    public init(className: String, methodName: String, parameters: [(name: String, value: String)] = []) {
        self.className = className
        self.methodName = methodName
        self.parameters = parameters
        self.startTime = Date()
    }

    /// Log method entry
    public func logEntry() {
        let paramString = parameters.isEmpty ? "()" : "(\(parameters.map { "\($0.name): \($0.value)" }.joined(separator: ", ")))"
        LuaDebugConfig.log("\(className).\(methodName)\(paramString) - Started", level: .verbose)
    }

    /// Log method exit with result
    public func logExit(result: String? = nil) {
        let duration = Date().timeIntervalSince(startTime) * 1_000 // Convert to milliseconds
        let durationStr = String(format: "%.2fms", duration)

        if let result = result {
            LuaDebugConfig.log("\(className).\(methodName) - Completed in \(durationStr), returned: \(result)", level: .verbose)
        } else {
            LuaDebugConfig.log("\(className).\(methodName) - Completed in \(durationStr)", level: .verbose)
        }
    }

    /// Log method error
    public func logError(_ error: String) {
        LuaDebugConfig.log("\(className).\(methodName) - ERROR: \(error)", level: .error)
    }
}

/// Debug helpers for property access
public struct LuaPropertyDebugContext: Sendable {
    public let className: String
    public let propertyName: String
    public let isGetter: Bool

    public init(className: String, propertyName: String, isGetter: Bool) {
        self.className = className
        self.propertyName = propertyName
        self.isGetter = isGetter
    }

    /// Log property access
    public func logAccess(value: String? = nil) {
        if isGetter {
            if let value = value {
                LuaDebugConfig.log("\(className).\(propertyName) - Read value: \(value)", level: .verbose)
            } else {
                LuaDebugConfig.log("\(className).\(propertyName) - Read", level: .verbose)
            }
        } else {
            if let value = value {
                LuaDebugConfig.log("\(className).\(propertyName) - Set value: \(value)", level: .verbose)
            } else {
                LuaDebugConfig.log("\(className).\(propertyName) - Set", level: .verbose)
            }
        }
    }

    /// Log property validation failure
    public func logValidationFailure(value: String, reason: String) {
        LuaDebugConfig.log("\(className).\(propertyName) - Validation failed for value '\(value)': \(reason)", level: .warning)
    }
}

/// Performance tracking for debug mode.
///
/// Thread-safe via internal locking for Swift 6 concurrency compliance.
public final class LuaPerformanceTracker: @unchecked Sendable {
    private final class Storage: @unchecked Sendable {
        var metrics: [String: (count: Int, totalTime: TimeInterval)] = [:]
        let lock = NSLock()
        static let shared = Storage()
    }

    /// Track a method execution
    public static func track(className: String, methodName: String, duration: TimeInterval) {
        guard LuaDebugConfig.isEnabled else { return }

        Storage.shared.lock.lock()
        defer { Storage.shared.lock.unlock() }

        let key = "\(className).\(methodName)"
        if let existing = Storage.shared.metrics[key] {
            Storage.shared.metrics[key] = (count: existing.count + 1, totalTime: existing.totalTime + duration)
        } else {
            Storage.shared.metrics[key] = (count: 1, totalTime: duration)
        }
    }

    /// Get performance report
    public static func report() -> String {
        Storage.shared.lock.lock()
        defer { Storage.shared.lock.unlock() }

        var report = "=== LuaKit Performance Report ===\n"

        let sortedMetrics = Storage.shared.metrics.sorted { $0.value.totalTime > $1.value.totalTime }

        for (method, data) in sortedMetrics {
            let avgTime = data.totalTime / Double(data.count) * 1_000 // Convert to ms
            let totalTime = data.totalTime * 1_000 // Convert to ms
            report += String(format: "%@: %d calls, %.2fms avg, %.2fms total\n",
                             method, data.count, avgTime, totalTime)
        }

        return report
    }

    /// Reset all metrics
    public static func reset() {
        Storage.shared.lock.lock()
        defer { Storage.shared.lock.unlock() }
        Storage.shared.metrics.removeAll()
    }
}

/// Memory tracking for debug mode.
///
/// Thread-safe via internal locking for Swift 6 concurrency compliance.
public final class LuaMemoryTracker: @unchecked Sendable {
    private final class Storage: @unchecked Sendable {
        var allocations: [String: Int] = [:]
        let lock = NSLock()
        static let shared = Storage()
    }

    /// Track object allocation
    public static func trackAllocation(_ className: String) {
        guard LuaDebugConfig.isEnabled else { return }

        Storage.shared.lock.lock()
        defer { Storage.shared.lock.unlock() }

        Storage.shared.allocations[className, default: 0] += 1
        let count = Storage.shared.allocations[className]!
        Storage.shared.lock.unlock()
        LuaDebugConfig.log("\(className) - Instance allocated (total: \(count))", level: .verbose)
        Storage.shared.lock.lock()
    }

    /// Track object deallocation
    public static func trackDeallocation(_ className: String) {
        guard LuaDebugConfig.isEnabled else { return }

        Storage.shared.lock.lock()
        defer { Storage.shared.lock.unlock() }

        Storage.shared.allocations[className, default: 0] -= 1
        let count = Storage.shared.allocations[className]!
        Storage.shared.lock.unlock()
        LuaDebugConfig.log("\(className) - Instance deallocated (remaining: \(count))", level: .verbose)
        Storage.shared.lock.lock()
    }

    /// Get memory report
    public static func report() -> String {
        Storage.shared.lock.lock()
        defer { Storage.shared.lock.unlock() }

        var report = "=== LuaKit Memory Report ===\n"

        let sortedAllocations = Storage.shared.allocations.filter { $0.value > 0 }.sorted { $0.value > $1.value }

        for (className, count) in sortedAllocations {
            report += "\(className): \(count) instances\n"
        }

        return report
    }

    /// Reset all allocations
    public static func reset() {
        Storage.shared.lock.lock()
        defer { Storage.shared.lock.unlock() }
        Storage.shared.allocations.removeAll()
    }
}

/// Extension to make debugging easier from Lua
public extension LuaState {
    /// Enable/disable debug mode
    func setDebugMode(_ enabled: Bool) {
        LuaDebugConfig.isEnabled = enabled
    }

    /// Set debug log level
    func setDebugLogLevel(_ level: LuaDebugConfig.LogLevel) {
        LuaDebugConfig.logLevel = level
    }

    /// Get performance report
    func getPerformanceReport() -> String {
        return LuaPerformanceTracker.report()
    }

    /// Get memory report
    func getMemoryReport() -> String {
        return LuaMemoryTracker.report()
    }

    /// Reset debug metrics
    func resetDebugMetrics() {
        LuaPerformanceTracker.reset()
    }
}
