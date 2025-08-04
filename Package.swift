// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SwinjectUtilityMacros",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Main library product
        .library(
            name: "SwinjectUtilityMacros",
            targets: ["SwinjectUtilityMacros"]
        ),
        // Build plugin for service discovery
        .plugin(
            name: "SwinjectUtilityBuildPlugin",
            targets: ["SwinjectUtilityBuildPlugin"]
        )
    ],
    dependencies: [
        // SwiftSyntax for macro implementation
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "509.0.0"
        ),
        // Swinject for dependency injection integration
        .package(
            url: "https://github.com/Swinject/Swinject.git",
            exact: "2.9.1"
        )
    ],
    targets: [
        // MARK: - Public API Target
        .target(
            name: "SwinjectUtilityMacros",
            dependencies: [
                "SwinjectUtilityMacrosImplementation",
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Sources/SwinjectUtilityMacros"
        ),

        // MARK: - Macro Implementation Target
        .macro(
            name: "SwinjectUtilityMacrosImplementation",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/SwinjectUtilityMacrosImplementation"
        ),

        // MARK: - Build Plugin Target
        .plugin(
            name: "SwinjectUtilityBuildPlugin",
            capability: .buildTool(),
            dependencies: [
                "ServiceDiscoveryTool"
            ],
            path: "Plugins/SwinjectUtilityBuildPlugin"
        ),

        // MARK: - Build Tool Target
        .executableTarget(
            name: "ServiceDiscoveryTool",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/ServiceDiscoveryTool"
        ),

        // MARK: - Test Targets
        .testTarget(
            name: "SwinjectUtilityMacrosTests",
            dependencies: [
                "SwinjectUtilityMacros",
                "SwinjectUtilityMacrosImplementation",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Tests/SwinjectUtilityMacrosTests"
        ),

        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "SwinjectUtilityMacros",
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Tests/IntegrationTests"
        )
    ]
)
