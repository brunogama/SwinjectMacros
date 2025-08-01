// plugin.swift - Build plugin for automatic service discovery
// Copyright © 2025 SwinJectMacros. All rights reserved.

import PackagePlugin
import Foundation

/// Build plugin that automatically discovers @Injectable services and generates registration code
@main
struct SwinJectBuildPlugin: BuildToolPlugin {
    
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else {
            return []
        }
        
        // Only run on targets that depend on SwinJectMacros
        let hasSwinJectDependency = target.dependencies.contains { dependency in
            if case .target(let targetDependency) = dependency,
               targetDependency.name == "SwinJectMacros" {
                return true
            }
            return false
        }
        
        guard hasSwinJectDependency else {
            return []
        }
        
        // Get the service discovery tool
        let serviceDiscoveryTool = try context.tool(named: "ServiceDiscoveryTool")
        
        // Input: all Swift source files in the target
        let inputFiles = target.sourceFiles.filter { $0.path.string.hasSuffix(".swift") }
        
        // Output: generated registration file
        let outputDirectory = context.pluginWorkDirectory.appending("Generated")
        let outputFile = outputDirectory.appending("GeneratedServiceRegistration.swift")
        
        // Create output directory if it doesn't exist
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDirectory.string),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        // Create build command
        return [
            .prebuildCommand(
                displayName: "Generate Service Registration for \(target.name)",
                executable: serviceDiscoveryTool.path,
                arguments: [
                    "--input", target.directory.string,
                    "--output", outputFile.string
                ],
                environment: [:],
                outputFilesDirectory: outputDirectory
            )
        ]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwinJectBuildPlugin: XcodeBuildToolPlugin {
    
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        // Get the service discovery tool path
        // In Xcode, we need to use the tool from the package
        let serviceDiscoveryTool = try context.tool(named: "ServiceDiscoveryTool")
        
        // Input: target's source files (simplified for Xcode integration)
        let inputDirectory = context.xcodeProject.directory
        
        // Output: generated file in derived data
        let outputDirectory = context.pluginWorkDirectory.appending("Generated")
        let outputFile = outputDirectory.appending("GeneratedServiceRegistration.swift")
        
        // Create output directory if needed
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDirectory.string),
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        return [
            .prebuildCommand(
                displayName: "Generate Service Registration",
                executable: serviceDiscoveryTool.path,
                arguments: [
                    "--input", inputDirectory.string,
                    "--output", outputFile.string
                ],
                outputFilesDirectory: outputDirectory
            )
        ]
    }
}
#endif

// MARK: - Helper Extensions

extension Target {
    /// Check if target has a specific dependency
    func hasDependency(named name: String) -> Bool {
        return dependencies.contains { dependency in
            if case .target(let targetDependency) = dependency {
                return targetDependency.name == name
            }
            return false
        }
    }
}

