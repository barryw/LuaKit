//
//  LuaSandboxTests.swift
//  LuaKit
//
//  Tests for sandbox resource controls.
//

@testable import LuaKit
import XCTest

private final class LockedErrors: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Error] = []

    func append(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(error)
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage.isEmpty
    }
}

final class LuaSandboxTests: XCTestCase {
    func testSandboxRemovesUnsafeGlobals() throws {
        let lua = try LuaState(sandbox: LuaSandboxConfiguration(instructionLimit: nil))

        let unsafeGlobalsAreRemoved: Bool = try lua.execute("""
            return io == nil
               and os == nil
               and debug == nil
               and package == nil
               and require == nil
               and dofile == nil
               and loadfile == nil
               and collectgarbage == nil
        """, returning: Bool.self)

        XCTAssertTrue(unsafeGlobalsAreRemoved)
    }

    func testInstructionLimitStopsInfiniteLoop() throws {
        let lua = try LuaState(sandbox: LuaSandboxConfiguration(
            instructionLimit: 2_000,
            hookInterval: 100
        ))

        XCTAssertThrowsError(try lua.execute("""
            local value = 0
            while true do
                value = value + 1
            end
        """)) { error in
            guard case LuaError.runtime(let message) = error else {
                XCTFail("Expected LuaError.runtime")
                return
            }
            XCTAssertTrue(message.contains("instruction limit exceeded"))
        }
    }

    func testInstructionLimitAppliesToCoroutines() throws {
        let lua = try LuaState(sandbox: LuaSandboxConfiguration(
            instructionLimit: 2_000,
            hookInterval: 100
        ))
        let coroutine = try lua.createCoroutine("""
            local value = 0
            while true do
                value = value + 1
            end
        """)

        XCTAssertThrowsError(try coroutine.resumeVoid()) { error in
            guard case LuaError.coroutineError(let message) = error else {
                XCTFail("Expected LuaError.coroutineError")
                return
            }
            XCTAssertTrue(message.contains("instruction limit exceeded"))
        }
    }

    func testWallTimeLimitStopsExecution() throws {
        let lua = try LuaState(sandbox: LuaSandboxConfiguration(
            instructionLimit: nil,
            wallTimeLimit: 0,
            hookInterval: 1
        ))

        XCTAssertThrowsError(try lua.execute("""
            local value = 0
            for i = 1, 100000 do
                value = value + i
            end
        """)) { error in
            guard case LuaError.runtime(let message) = error else {
                XCTFail("Expected LuaError.runtime")
                return
            }
            XCTAssertTrue(message.contains("wall-time limit exceeded"))
        }
    }

    func testMemoryQuotaRejectsTooSmallState() {
        XCTAssertThrowsError(try LuaState(sandbox: LuaSandboxConfiguration(
            instructionLimit: nil,
            memoryLimitBytes: 1
        ))) { error in
            guard case LuaError.memoryAllocation = error else {
                XCTFail("Expected LuaError.memoryAllocation")
                return
            }
        }
    }

    func testMemoryQuotaTracksUsage() throws {
        let lua = try LuaState(sandbox: LuaSandboxConfiguration(
            instructionLimit: nil,
            memoryLimitBytes: 2_000_000
        ))

        try lua.execute("""
            local values = {}
            for i = 1, 100 do
                values[i] = "value-" .. i
            end
        """)

        XCTAssertNotNil(lua.currentMemoryUsage)
        XCTAssertNotNil(lua.peakMemoryUsage)
        XCTAssertLessThanOrEqual(lua.peakMemoryUsage ?? 0, 2_000_000)
    }

    func testLuaStateSerializesConcurrentExecuteCalls() throws {
        let lua = try LuaState()
        try lua.execute("counter = 0")

        let queue = DispatchQueue(label: "LuaSandboxTests.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let errors = LockedErrors()

        for _ in 0..<100 {
            group.enter()
            queue.async {
                do {
                    try lua.execute("counter = counter + 1")
                } catch {
                    errors.append(error)
                }
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        XCTAssertTrue(errors.isEmpty)

        let counter: Int = try lua.execute("return counter", returning: Int.self)
        XCTAssertEqual(counter, 100)
    }
}
