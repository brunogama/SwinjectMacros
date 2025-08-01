// swift-tools-version: 5.9
// Package.swift for SwinJectMacros iOS SwiftUI Demo
// Demonstrates all macro capabilities in a real iOS application

import PackageDescription

let package = Package(
    name: "SwinJectMacrosiOSDemo",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "SwinJectMacrosiOSDemo",
            targets: ["SwinJectMacrosiOSDemo"]
        )
    ],
    dependencies: [
        // Local dependency on SwinJectMacros
        .package(path: "../.."),
        
        // Additional dependencies for demo features
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.9.1")
    ],
    targets: [
        .executableTarget(
            name: "SwinJectMacrosiOSDemo",
            dependencies: [
                "SwinJectUtilityMacros",
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Sources"
        ),
        // .testTarget(
        //     name: "SwinJectMacrosiOSDemoTests",
        //     dependencies: [
        //         "SwinJectMacrosiOSDemo",
        //         .product(name: "SwinJectMacros", package: "SwinJectMacros")
        //     ],
        //     path: "Tests"
        // )
    ]
)
