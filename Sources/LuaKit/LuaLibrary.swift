//
//  LuaLibrary.swift
//  LuaKit
//
//  Created by Barry Walker on 1/23/26.
//

import Foundation

/// Libraries that can be selectively loaded into a Lua state.
///
/// Use this with `LuaState(libraries:)` to create sandboxed Lua environments
/// that don't have access to potentially dangerous functionality like file I/O
/// or OS commands.
///
/// Example:
/// ```swift
/// // Full access (default)
/// let lua = try LuaState()
///
/// // Sandboxed - no io, os, debug, package
/// let sandbox = try LuaState(libraries: .sandboxed)
///
/// // Custom selection
/// let custom = try LuaState(libraries: [.base, .string, .math])
/// ```
public struct LuaLibrary: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Basic functions: print, tonumber, tostring, type, etc.
    /// Matches LUA_GLIBK
    public static let base = LuaLibrary(rawValue: 1)

    /// Package/module loading (potentially dangerous)
    /// Matches LUA_LOADLIBK
    public static let package = LuaLibrary(rawValue: 2)

    /// Coroutine manipulation functions
    /// Matches LUA_COLIBK
    public static let coroutine = LuaLibrary(rawValue: 4)

    /// Debug facilities (potentially dangerous)
    /// Matches LUA_DBLIBK
    public static let debug = LuaLibrary(rawValue: 8)

    /// File I/O functions (potentially dangerous)
    /// Matches LUA_IOLIBK
    public static let io = LuaLibrary(rawValue: 16)

    /// Mathematical functions
    /// Matches LUA_MATHLIBK
    public static let math = LuaLibrary(rawValue: 32)

    /// Operating system facilities (potentially dangerous)
    /// Matches LUA_OSLIBK
    public static let os = LuaLibrary(rawValue: 64)

    /// String manipulation functions
    /// Matches LUA_STRLIBK
    public static let string = LuaLibrary(rawValue: 128)

    /// Table manipulation functions
    /// Matches LUA_TABLIBK
    public static let table = LuaLibrary(rawValue: 256)

    /// UTF-8 support functions
    /// Matches LUA_UTF8LIBK
    public static let utf8 = LuaLibrary(rawValue: 512)

    /// All standard libraries
    public static let all: LuaLibrary = [
        .base, .coroutine, .table, .io, .os,
        .string, .math, .utf8, .debug, .package
    ]

    /// Safe subset for sandboxed execution.
    /// Excludes: io, os, debug, package
    public static let sandboxed: LuaLibrary = [
        .base, .coroutine, .table, .string, .math, .utf8
    ]
}
