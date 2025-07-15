//
//  LuaTypeConversionTests.swift
//  LuaKit
//
//  Tests for LuaTypeConversion functionality
//

import Lua
@testable import LuaKit
import XCTest

final class LuaTypeConversionTests: XCTestCase {
    var L: OpaquePointer!

    override func setUp() {
        super.setUp()
        L = luaL_newstate()
        luaL_openlibs(L)
    }

    override func tearDown() {
        lua_close(L)
        L = nil
        super.tearDown()
    }

    // MARK: - LuaTypeConverterRegistry Tests

    func testTypeConverterRegistry() {
        // Register a converter
        LuaTypeConverterRegistry.register(StringToUUIDConverter.self, name: "uuid")

        let converter = LuaTypeConverterRegistry.getConverter(named: "uuid")
        XCTAssertNotNil(converter)

        // Test missing converter
        let missing = LuaTypeConverterRegistry.getConverter(named: "nonexistent")
        XCTAssertNil(missing)
    }

    // MARK: - StringToUUIDConverter Tests

    func testStringToUUIDConverter() throws {
        let validUUID = "550e8400-e29b-41d4-a716-446655440000"
        let uuid = try StringToUUIDConverter.convert(validUUID)
        XCTAssertEqual(uuid.uuidString.lowercased(), validUUID.lowercased())
    }

    func testStringToUUIDConverterInvalidFormat() {
        XCTAssertThrowsError(try StringToUUIDConverter.convert("not-a-uuid")) { error in
            guard let luaKitError = error as? LuaKitError,
                  case .invalidArgument(let context) = luaKitError else {
                XCTFail("Expected LuaKitError.invalidArgument")
                return
            }

            XCTAssertTrue(context.generateMessage().contains("Invalid UUID format"))
        }
    }

    // MARK: - StringToDateConverter Tests

    func testStringToDateConverter() throws {
        let dateString = "2023-12-25T10:30:00.000Z"
        let date = try StringToDateConverter.convert(dateString)

        // Verify it's a valid date
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
        XCTAssertEqual(components.year, 2_023)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 25)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 30)
    }

    func testStringToDateConverterInvalidFormat() {
        XCTAssertThrowsError(try StringToDateConverter.convert("2023/12/25")) { error in
            guard let luaKitError = error as? LuaKitError,
                  case .invalidArgument(let context) = luaKitError else {
                XCTFail("Expected LuaKitError.invalidArgument")
                return
            }

            XCTAssertTrue(context.generateMessage().contains("Invalid date format"))
            XCTAssertTrue(context.generateMessage().contains("YYYY-MM-DDTHH:MM:SS.sssZ"))
        }
    }

    // MARK: - StringToURLConverter Tests

    func testStringToURLConverter() throws {
        let urlString = "https://example.com/path?query=value"
        let url = try StringToURLConverter.convert(urlString)
        XCTAssertEqual(url.absoluteString, urlString)
    }

    func testStringToURLConverterInvalidFormat() {
        XCTAssertThrowsError(try StringToURLConverter.convert("")) { error in
            guard let luaKitError = error as? LuaKitError,
                  case .invalidArgument(let context) = luaKitError else {
                XCTFail("Expected LuaKitError.invalidArgument")
                return
            }

            XCTAssertTrue(context.generateMessage().contains("Invalid URL format"))
        }
    }

    // MARK: - NumberToTimeIntervalConverter Tests

    func testNumberToTimeIntervalConverter() throws {
        let interval = try NumberToTimeIntervalConverter.convert(123.45)
        XCTAssertEqual(interval, 123.45)

        let zero = try NumberToTimeIntervalConverter.convert(0.0)
        XCTAssertEqual(zero, 0.0)
    }

    func testNumberToTimeIntervalConverterNegative() {
        XCTAssertThrowsError(try NumberToTimeIntervalConverter.convert(-1.0)) { error in
            guard let luaKitError = error as? LuaKitError,
                  case .invalidArgument(let context) = luaKitError else {
                XCTFail("Expected LuaKitError.invalidArgument")
                return
            }

            XCTAssertTrue(context.generateMessage().contains("TimeInterval cannot be negative"))
        }
    }

    // MARK: - Date LuaConvertible Tests

    func testDateLuaConvertible() {
        let date = Date(timeIntervalSince1970: 1_640_429_400) // 2021-12-25 10:30:00 UTC

        // Push to Lua
        Date.push(date, to: L)

        // Should be pushed as ISO8601 string
        let pushedString = String(cString: lua_tostring(L, -1)!)
        XCTAssertTrue(pushedString.contains("2021-12-25"))

        // Pull from Lua
        let pulled = Date.pull(from: L, at: -1)
        XCTAssertNotNil(pulled)

        lua_pop(L, 1)
    }

    func testDatePullInvalidString() {
        lua_pushstring(L, "invalid date")
        let pulled = Date.pull(from: L, at: -1)
        XCTAssertNil(pulled)
        lua_pop(L, 1)
    }

    // MARK: - URL LuaConvertible Tests

    func testURLLuaConvertible() {
        let url = URL(string: "https://example.com")!

        // Push to Lua
        URL.push(url, to: L)

        let pushedString = String(cString: lua_tostring(L, -1)!)
        XCTAssertEqual(pushedString, "https://example.com")

        // Pull from Lua
        let pulled = URL.pull(from: L, at: -1)
        XCTAssertNotNil(pulled)
        XCTAssertEqual(pulled?.absoluteString, "https://example.com")

        lua_pop(L, 1)
    }

    // MARK: - UUID LuaConvertible Tests

    func testUUIDLuaConvertible() {
        let uuid = UUID()

        // Push to Lua
        UUID.push(uuid, to: L)

        let pushedString = String(cString: lua_tostring(L, -1)!)
        XCTAssertEqual(pushedString.lowercased(), uuid.uuidString.lowercased())

        // Pull from Lua
        let pulled = UUID.pull(from: L, at: -1)
        XCTAssertNotNil(pulled)
        XCTAssertEqual(pulled?.uuidString.lowercased(), uuid.uuidString.lowercased())

        lua_pop(L, 1)
    }

    // MARK: - Data LuaConvertible Tests

    func testDataLuaConvertible() {
        let data = Data("Hello, World!".utf8)

        // Push to Lua
        Data.push(data, to: L)

        let pushedString = String(cString: lua_tostring(L, -1)!)
        XCTAssertEqual(pushedString, data.base64EncodedString())

        // Pull from Lua
        let pulled = Data.pull(from: L, at: -1)
        XCTAssertNotNil(pulled)
        XCTAssertEqual(pulled, data)

        lua_pop(L, 1)
    }

    func testDataPullInvalidBase64() {
        lua_pushstring(L, "not base64!")
        let pulled = Data.pull(from: L, at: -1)
        XCTAssertNil(pulled)
        lua_pop(L, 1)
    }

    // MARK: - Optional LuaConvertible Tests

    func testOptionalLuaConvertibleSome() {
        let optional: Int? = 42
        Int?.push(optional, to: L)

        XCTAssertEqual(lua_tointeger(L, -1), 42)

        // Pull from Lua
        let pulled = Int?.pull(from: L, at: -1)
        XCTAssertNotNil(pulled as Any?) // This is Optional<Optional<Int>>
        XCTAssertEqual(pulled, 42)

        lua_pop(L, 1)
    }

    func testOptionalLuaConvertibleNil() {
        let optional: Int? = nil
        Int?.push(optional, to: L)

        XCTAssertEqual(lua_type(L, -1), LUA_TNIL)

        // Pull from Lua
        let pulled = Int?.pull(from: L, at: -1)
        XCTAssertNotNil(pulled as Any?) // This is Optional<Optional<Int>> with value .some(nil)
        XCTAssertNil(pulled!)

        lua_pop(L, 1)
    }

    // MARK: - Dictionary LuaConvertible Tests

    func testDictionaryLuaConvertible() {
        let dict: [String: Int] = ["one": 1, "two": 2, "three": 3]
        [String: Int].push(dict, to: L)

        XCTAssertEqual(lua_type(L, -1), LUA_TTABLE)

        // Pull from Lua
        let pulled = [String: Int].pull(from: L, at: -1)
        XCTAssertNotNil(pulled)
        XCTAssertEqual(pulled?.count, 3)
        XCTAssertEqual(pulled?["one"], 1)
        XCTAssertEqual(pulled?["two"], 2)
        XCTAssertEqual(pulled?["three"], 3)

        lua_pop(L, 1)
    }

    func testDictionaryPullFromNonTable() {
        lua_pushstring(L, "not a table")
        let pulled = [String: Int].pull(from: L, at: -1)
        XCTAssertNil(pulled)
        lua_pop(L, 1)
    }

    // MARK: - LuaConvert Tests

    func testLuaConvertMissingConverter() {
        XCTAssertThrowsError(try LuaConvert.convert("test", using: "nonexistent") as String) { error in
            guard let luaKitError = error as? LuaKitError,
                  case .invalidArgument(let context) = luaKitError else {
                XCTFail("Expected LuaKitError.invalidArgument")
                return
            }

            XCTAssertTrue(context.generateMessage().contains("No converter registered"))
        }
    }

    func testAutoConvertDirectCast() {
        let value: Any = 42
        let result = LuaConvert.autoConvert(value, to: Int.self)
        XCTAssertEqual(result, 42)
    }

    func testAutoConvertStringToNumber() {
        XCTAssertEqual(LuaConvert.autoConvert("42", to: Int.self), 42)
        XCTAssertEqual(LuaConvert.autoConvert("3.14", to: Double.self), 3.14)
        XCTAssertEqual(LuaConvert.autoConvert("true", to: Bool.self), true)
        XCTAssertEqual(LuaConvert.autoConvert("false", to: Bool.self), false)
    }

    func testAutoConvertStringToUUID() {
        let uuidString = "550e8400-e29b-41d4-a716-446655440000"
        let result = LuaConvert.autoConvert(uuidString, to: UUID.self)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.uuidString.lowercased(), uuidString.lowercased())
    }

    func testAutoConvertStringToURL() {
        let urlString = "https://example.com"
        let result = LuaConvert.autoConvert(urlString, to: URL.self)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.absoluteString, urlString)
    }

    func testAutoConvertNSNumber() {
        let number = NSNumber(value: 42.5)

        XCTAssertEqual(LuaConvert.autoConvert(number, to: Int.self), 42)
        XCTAssertEqual(LuaConvert.autoConvert(number, to: Double.self), 42.5)
        XCTAssertEqual(LuaConvert.autoConvert(number, to: Float.self), 42.5)

        let boolNumber = NSNumber(value: true)
        XCTAssertEqual(LuaConvert.autoConvert(boolNumber, to: Bool.self), true)
    }

    func testAutoConvertFailure() {
        let result = LuaConvert.autoConvert("not a number", to: Int.self)
        XCTAssertNil(result)

        let dictResult = LuaConvert.autoConvert(["key": "value"], to: String.self)
        XCTAssertNil(dictResult)
    }

    // MARK: - Integration Tests

    func testComplexDictionaryConversion() {
        let dict: [String: String] = [
            "uuid": "550e8400-e29b-41d4-a716-446655440000",
            "url": "https://example.com",
            "date": "2023-12-25T10:30:00.000Z"
        ]
        [String: String].push(dict, to: L)

        // Pull and verify
        let pulled = [String: String].pull(from: L, at: -1)
        XCTAssertNotNil(pulled)
        XCTAssertEqual(pulled?.count, 3)
        XCTAssertEqual(pulled?["uuid"], dict["uuid"])
        XCTAssertEqual(pulled?["url"], dict["url"])
        XCTAssertEqual(pulled?["date"], dict["date"])

        lua_pop(L, 1)
    }

    func testOptionalProtocol() {
        let optional: Int? = 42
        let wrapped = optional.optional
        XCTAssertEqual(wrapped, 42)

        let nilOptional: Int? = nil
        let nilWrapped = nilOptional.optional
        XCTAssertNil(nilWrapped)
    }
}
