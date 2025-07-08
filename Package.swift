// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "LuaKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LuaKit",
            targets: ["LuaKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Lua",
            dependencies: [],
            cSettings: [
                .define("LUA_USE_MACOSX", .when(platforms: [.macOS])),
                .define("LUA_USE_IOS", .when(platforms: [.iOS, .tvOS, .watchOS]))
            ]
        ),
        .macro(
            name: "LuaMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]),
        .target(
            name: "LuaKit",
            dependencies: [
                "Lua",
                "LuaMacros"
            ]),
        .testTarget(
            name: "LuaKitTests",
            dependencies: ["LuaKit"]),
    ]
)
