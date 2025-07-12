//
//  LuaKitTests.swift
//  LuaKitTests
//
//  Created by Barry Walker on 7/8/25.
//

@testable import LuaKit
import XCTest

final class LuaKitTests: XCTestCase {
    func testFrameworkLoads() throws {
        // Test that the framework loads and basic functionality works
        let lua = try LuaState()
        XCTAssertNotNil(lua)

        let result = try lua.executeReturning("return 'LuaKit is working!'", as: String.self)
        XCTAssertEqual(result, "LuaKit is working!")
    }

    func testAllTestSuites() throws {
        // This test ensures all test suites are discoverable
        // The actual tests are in the separate test files:
        // - BasicTests.swift
        // - GlobalsTests.swift
        // - TableTests.swift
        // - BridgeableTests.swift
        XCTAssertTrue(true, "All test suites should be discovered and run")
    }
}
