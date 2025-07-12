//
//  LuaDebug.swift
//  LuaKit
//
//  Debug helpers for LuaBridgeable types
//

import Foundation

/// Global debug configuration for LuaKit
public struct LuaDebugConfig {
    /// Enable debug logging globally
    public static var isEnabled = false

    /// Log level for debug output
    public enum LogLevel: Int {
        case verbose = 0
        case info = 1
        case warning = 2
        case error = 3
    }

    /// Current log level
    public static var logLevel: LogLevel = .info

    /// Custom logger function
    public static var logger: ((String, LogLevel) -> Void)? = { message, level in
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

    /// Log a message if debugging is enabled
    public static func log(_ message: String, level: LogLevel = .info) {
        guard isEnabled && level.rawValue >= logLevel.rawValue else { return }
        logger?(message, level)
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
public struct LuaMethodDebugContext {
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
public struct LuaPropertyDebugContext {
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

/// Performance tracking for debug mode
public class LuaPerformanceTracker {
    private static var metrics: [String: (count: Int, totalTime: TimeInterval)] = [:]
    private static let lock = NSLock()

    /// Track a method execution
    public static func track(className: String, methodName: String, duration: TimeInterval) {
        guard LuaDebugConfig.isEnabled else { return }

        lock.lock()
        defer { lock.unlock() }

        let key = "\(className).\(methodName)"
        if let existing = metrics[key] {
            metrics[key] = (count: existing.count + 1, totalTime: existing.totalTime + duration)
        } else {
            metrics[key] = (count: 1, totalTime: duration)
        }
    }

    /// Get performance report
    public static func report() -> String {
        lock.lock()
        defer { lock.unlock() }

        var report = "=== LuaKit Performance Report ===\n"

        let sortedMetrics = metrics.sorted { $0.value.totalTime > $1.value.totalTime }

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
        lock.lock()
        defer { lock.unlock() }
        metrics.removeAll()
    }
}

/// Memory tracking for debug mode
public class LuaMemoryTracker {
    private static var allocations: [String: Int] = [:]
    private static let lock = NSLock()

    /// Track object allocation
    public static func trackAllocation(_ className: String) {
        guard LuaDebugConfig.isEnabled else { return }

        lock.lock()
        defer { lock.unlock() }

        allocations[className, default: 0] += 1
        LuaDebugConfig.log("\(className) - Instance allocated (total: \(allocations[className]!))", level: .verbose)
    }

    /// Track object deallocation
    public static func trackDeallocation(_ className: String) {
        guard LuaDebugConfig.isEnabled else { return }

        lock.lock()
        defer { lock.unlock() }

        allocations[className, default: 0] -= 1
        LuaDebugConfig.log("\(className) - Instance deallocated (remaining: \(allocations[className]!))", level: .verbose)
    }

    /// Get memory report
    public static func report() -> String {
        lock.lock()
        defer { lock.unlock() }

        var report = "=== LuaKit Memory Report ===\n"

        let sortedAllocations = allocations.filter { $0.value > 0 }.sorted { $0.value > $1.value }

        for (className, count) in sortedAllocations {
            report += "\(className): \(count) instances\n"
        }

        return report
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
