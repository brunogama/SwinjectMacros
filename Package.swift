// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwinJectMacros",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        // Main library product
        .library(
            name: "SwinJectMacros",
            targets: ["SwinJectMacros"]
        ),
        // Build plugin for service discovery
        .plugin(
            name: "SwinJectBuildPlugin", 
            targets: ["SwinJectBuildPlugin"]
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
            name: "SwinJectMacros",
            dependencies: [
                "SwinJectMacrosImplementation",
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Sources/SwinJectMacros"
        ),
        
        // MARK: - Macro Implementation Target
        .macro(
            name: "SwinJectMacrosImplementation",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/SwinJectMacrosImplementation"
        ),
        
        // MARK: - Build Plugin Target
        .plugin(
            name: "SwinJectBuildPlugin",
            capability: .buildTool(),
            dependencies: [
                "ServiceDiscoveryTool"
            ],
            path: "Plugins/SwinJectBuildPlugin"
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
            name: "SwinJectMacrosTests",
            dependencies: [
                "SwinJectMacros",
                "SwinJectMacrosImplementation",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Tests/SwinJectMacrosTests"
        ),
        
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "SwinJectMacros",
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Tests/IntegrationTests"
        )
    ]
)
