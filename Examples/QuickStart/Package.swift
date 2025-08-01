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
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Swinject/Swinject.git", from: "2.9.1"),
        // In a real project, you'd reference SwinJectMacros here:
        // .package(path: "../..") // or from GitHub
    ],
    targets: [
        .executableTarget(
            name: "QuickStartExample",
            dependencies: [
                "Swinject",
                // "SwinJectMacros" // Uncomment when using the real package
            ]
        ),
    ]
)