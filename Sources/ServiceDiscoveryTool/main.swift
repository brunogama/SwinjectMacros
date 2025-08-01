// main.swift - Service discovery build tool
// Copyright © 2025 SwinJectMacros. All rights reserved.

import Foundation
import SwiftSyntax
import SwiftParser

/// Command-line tool for discovering and generating service registrations
struct ServiceDiscoveryTool {
    static func main() throws {
        let arguments = CommandLine.arguments
        
        guard arguments.count >= 3 else {
            print("Usage: ServiceDiscoveryTool --input <input-path> --output <output-path>")
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
                    print("Error: --input requires a path argument")
                    exit(1)
                }
            case "--output":
                if i + 1 < arguments.count {
                    outputPath = arguments[i + 1]
                    i += 2
                } else {
                    print("Error: --output requires a path argument")
                    exit(1)
                }
            default:
                print("Unknown argument: \(arguments[i])")
                exit(1)
            }
        }
        
        guard let input = inputPath, let output = outputPath else {
            print("Error: Both --input and --output are required")
            exit(1)
        }
        
        print("Discovering services in: \(input)")
        print("Generating registration code to: \(output)")
        
        do {
            try discoverAndGenerateServices(inputPath: input, outputPath: output)
            print("Service discovery completed successfully")
        } catch {
            print("Error: \(error.localizedDescription)")
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
        print("Found \(swiftFiles.count) Swift files")
        
        // Analyze each file for @Injectable services
        var services: [ServiceInfo] = []
        
        for filePath in swiftFiles {
            do {
                let content = try String(contentsOfFile: filePath)
                let syntax = Parser.parse(source: content)
                let discoveredServices = analyzeFile(syntax: syntax, filePath: filePath)
                services.append(contentsOf: discoveredServices)
            } catch {
                print("Warning: Failed to analyze \(filePath): \(error)")
            }
        }
        
        print("Discovered \(services.count) services with @Injectable")
        
        // Generate registration code
        let registrationCode = generateRegistrationCode(services: services)
        
        // Write to output file
        try registrationCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
        print("Generated registration code written to: \(outputPath)")
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
                    if let identifierType = attribute.as(AttributeSyntax.self)?.attributeName.as(IdentifierTypeSyntax.self),
                       identifierType.name.text == "Injectable" {
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
        case .inputPathNotFound(let path):
            return "Input path not found: \(path)"
        case .outputPathNotWritable(let path):
            return "Output path not writable: \(path)"
        case .fileParsingFailed(let file):
            return "Failed to parse file: \(file)"
        }
    }
}

do {
    try ServiceDiscoveryTool.main()
} catch {
    print("Fatal error: \(error.localizedDescription)")
    exit(1)
}
