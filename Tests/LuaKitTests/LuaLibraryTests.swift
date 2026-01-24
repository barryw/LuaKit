//
//  LuaLibraryTests.swift
//  LuaKit
//
//  Created by Barry Walker on 1/23/26.
//

@testable import LuaKit
import XCTest

final class LuaLibraryTests: XCTestCase {
    func testAllLibrariesContainsExpectedLibraries() {
        let all = LuaLibrary.all
        XCTAssertTrue(all.contains(.base))
        XCTAssertTrue(all.contains(.coroutine))
        XCTAssertTrue(all.contains(.table))
        XCTAssertTrue(all.contains(.io))
        XCTAssertTrue(all.contains(.os))
        XCTAssertTrue(all.contains(.string))
        XCTAssertTrue(all.contains(.math))
        XCTAssertTrue(all.contains(.utf8))
        XCTAssertTrue(all.contains(.debug))
        XCTAssertTrue(all.contains(.package))
    }

    func testSandboxedExcludesDangerousLibraries() {
        let sandboxed = LuaLibrary.sandboxed
        XCTAssertTrue(sandboxed.contains(.base))
        XCTAssertTrue(sandboxed.contains(.string))
        XCTAssertTrue(sandboxed.contains(.math))
        XCTAssertFalse(sandboxed.contains(.io))
        XCTAssertFalse(sandboxed.contains(.os))
        XCTAssertFalse(sandboxed.contains(.debug))
        XCTAssertFalse(sandboxed.contains(.package))
    }

    func testOptionSetCombinations() {
        let custom: LuaLibrary = [.base, .string]
        XCTAssertTrue(custom.contains(.base))
        XCTAssertTrue(custom.contains(.string))
        XCTAssertFalse(custom.contains(.math))
    }

    func testEmptyLibrarySet() {
        let empty: LuaLibrary = []
        XCTAssertFalse(empty.contains(.base))
        XCTAssertTrue(empty.isEmpty)
    }
}
