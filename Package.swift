// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SwinjectMacros",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Main library product
        .library(
            name: "SwinjectMacros",
            targets: ["SwinjectMacros"]
        ),
        // Build plugin for service discovery
        .plugin(
            name: "SwinjectBuildPlugin",
            targets: ["SwinjectBuildPlugin"]
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
            name: "SwinjectMacros",
            dependencies: [
                "SwinjectMacrosImplementation",
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Sources/SwinjectMacros"
        ),

        // MARK: - Macro Implementation Target
        .macro(
            name: "SwinjectMacrosImplementation",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/SwinjectMacrosImplementation"
        ),

        // MARK: - Build Plugin Target
        .plugin(
            name: "SwinjectBuildPlugin",
            capability: .buildTool(),
            dependencies: [
                "ServiceDiscoveryTool"
            ],
            path: "Plugins/SwinjectBuildPlugin"
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
            name: "SwinjectMacrosTests",
            dependencies: [
                "SwinjectMacros",
                "SwinjectMacrosImplementation",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Tests/SwinjectMacrosTests"
        ),

        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "SwinjectMacros",
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Tests/IntegrationTests"
        )
    ]
)
