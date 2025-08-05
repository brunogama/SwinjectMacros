// main.swift - Service discovery build tool
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import os.log
import SwiftParser
import SwiftSyntax

/// Command-line tool for discovering and generating service registrations
enum ServiceDiscoveryTool {
    private static let logger = Logger(subsystem: "com.swinjectmacros", category: "service-discovery")

    static func main() throws {
        let arguments = CommandLine.arguments

        guard arguments.count >= 3 else {
            logger.error("Usage: ServiceDiscoveryTool --input <input-path> --output <output-path>")
            exit(1)
        }

        var inputPath: String?
        var outputPath: String?

        // Parse command line arguments
        var i = 1
        while i < arguments.count {
            switch arguments[i] {
            case "--input":
                if i + 1 < arguments.count {
                    inputPath = arguments[i + 1]
                    i += 2
                } else {
                    logger.error("Error: --input requires a path argument")
                    exit(1)
                }
            case "--output":
                if i + 1 < arguments.count {
                    outputPath = arguments[i + 1]
                    i += 2
                } else {
                    logger.error("Error: --output requires a path argument")
                    exit(1)
                }
            default:
                logger.error("Unknown argument: \(arguments[i])")
                exit(1)
            }
        }

        guard let input = inputPath, let output = outputPath else {
            logger.error("Error: Both --input and --output are required")
            exit(1)
        }

        logger.info("Discovering services in: \(input)")
        logger.info("Generating registration code to: \(output)")

        do {
            try discoverAndGenerateServices(inputPath: input, outputPath: output)
            logger.info("✅ Service discovery completed successfully")
        } catch {
            logger.error("❌ Error: \(error.localizedDescription)")
            exit(1)
        }
    }

    /// Discovers services in the input path and generates registration code
    static func discoverAndGenerateServices(inputPath: String, outputPath: String) throws {
        let fileManager = FileManager.default

        // Ensure input path exists
        guard fileManager.fileExists(atPath: inputPath) else {
            throw ServiceDiscoveryError.inputPathNotFound(inputPath)
        }

        // Find all Swift files recursively
        let swiftFiles = try findSwiftFiles(in: inputPath)
        logger.debug("Found \(swiftFiles.count) Swift files")

        // Analyze each file for @Injectable services
        var services: [ServiceInfo] = []

        for filePath in swiftFiles {
            do {
                let content = try String(contentsOfFile: filePath)
                let syntax = Parser.parse(source: content)
                let discoveredServices = analyzeFile(syntax: syntax, filePath: filePath)
                services.append(contentsOf: discoveredServices)
            } catch {
                logger.warning("Failed to analyze \(filePath): \(error)")
            }
        }

        logger.info("Discovered \(services.count) services with @Injectable")

        // Generate registration code
        let registrationCode = generateRegistrationCode(services: services)

        // Write to output file
        try registrationCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
        logger.info("Generated registration code written to: \(outputPath)")
    }

    /// Finds all Swift files recursively in a directory
    static func findSwiftFiles(in path: String) throws -> [String] {
        let fileManager = FileManager.default
        var swiftFiles: [String] = []

        if let enumerator = fileManager.enumerator(atPath: path) {
            for case let file as String in enumerator {
                if file.hasSuffix(".swift") {
                    let fullPath = (path as NSString).appendingPathComponent(file)
                    swiftFiles.append(fullPath)
                }
            }
        }

        return swiftFiles
    }

    /// Analyzes a Swift syntax tree for @Injectable services
    static func analyzeFile(syntax: SourceFileSyntax, filePath: String) -> [ServiceInfo] {
        // Simple visitor to find @Injectable classes/structs
        class ServiceVisitor: SyntaxVisitor {
            var services: [ServiceInfo] = []

            override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
                if hasInjectableAttribute(node.attributes) {
                    services.append(ServiceInfo(
                        name: node.name.text,
                        type: .class,
                        filePath: ""
                    ))
                }
                return .visitChildren
            }

            override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
                if hasInjectableAttribute(node.attributes) {
                    services.append(ServiceInfo(
                        name: node.name.text,
                        type: .struct,
                        filePath: ""
                    ))
                }
                return .visitChildren
            }

            private func hasInjectableAttribute(_ attributes: AttributeListSyntax) -> Bool {
                for attribute in attributes {
                    if let identifierType = attribute.as(AttributeSyntax.self)?.attributeName
                        .as(IdentifierTypeSyntax.self),
                        identifierType.name.text == "Injectable"
                    {
                        return true
                    }
                }
                return false
            }
        }

        let visitor = ServiceVisitor(viewMode: .sourceAccurate)
        visitor.walk(syntax)

        // Update file paths
        for i in 0..<visitor.services.count {
            visitor.services[i].filePath = filePath
        }

        return visitor.services
    }

    /// Generates registration code for discovered services
    static func generateRegistrationCode(services: [ServiceInfo]) -> String {
        var code = """
        // Generated by ServiceDiscoveryTool
        // Do not edit manually

        import Foundation
        import Swinject

        extension Container {
            /// Registers all discovered @Injectable services
            func registerDiscoveredServices() {
        """

        for service in services {
            code += """

                // Register \(service.name) from \(service.filePath)
                \(service.name).register(in: self)
            """
        }

        code += """

            }
        }
        """

        return code
    }
}

// MARK: - Supporting Types

struct ServiceInfo {
    let name: String
    let type: ServiceType
    var filePath: String

    enum ServiceType {
        case `class`
        case `struct`
    }
}

enum ServiceDiscoveryError: Error, LocalizedError {
    case inputPathNotFound(String)
    case outputPathNotWritable(String)
    case fileParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case let .inputPathNotFound(path):
            "Input path not found: \(path)"
        case let .outputPathNotWritable(path):
            "Output path not writable: \(path)"
        case let .fileParsingFailed(file):
            "Failed to parse file: \(file)"
        }
    }
}

do {
    try ServiceDiscoveryTool.main()
} catch {
    let logger = Logger(subsystem: "com.swinjectmacros", category: "service-discovery")
    logger.critical("Fatal error: \(error.localizedDescription)")
    exit(1)
}
