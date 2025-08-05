// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "QuickStartExample",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "QuickStartExample",
            targets: ["QuickStartExample"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.9.1"),
        .package(path: "../..") // Reference to SwinjectMacros
    ],
    targets: [
        .executableTarget(
            name: "QuickStartExample",
            dependencies: [
                "Swinject",
                .product(name: "SwinjectMacros", package: "SwinjectUtilityMacros")
            ]
        )
    ]
)
