// swift-tools-version: 5.9
// Package.swift for SwinjectMacros iOS SwiftUI Demo
// Demonstrates all macro capabilities in a real iOS application

import PackageDescription

let package = Package(
    name: "SwinjectMacrosiOSDemo",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "SwinjectMacrosiOSDemo",
            targets: ["SwinjectMacrosiOSDemo"]
        )
    ],
    dependencies: [
        // Local dependency on SwinjectMacros
        .package(path: "../.."),

        // Additional dependencies for demo features
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.9.1")
    ],
    targets: [
        .executableTarget(
            name: "SwinjectMacrosiOSDemo",
            dependencies: [
                "SwinjectMacros",
                .product(name: "Swinject", package: "Swinject")
            ],
            path: "Sources"
        )
        // .testTarget(
        //     name: "SwinjectMacrosiOSDemoTests",
        //     dependencies: [
        //         "SwinjectMacrosiOSDemo",
        //         .product(name: "SwinjectMacros", package: "SwinjectMacros")
        //     ],
        //     path: "Tests"
        // )
    ]
)
