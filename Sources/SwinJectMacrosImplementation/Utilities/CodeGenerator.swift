// CodeGenerator.swift - Swift code generation utilities for macro implementations
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Generates Swift code for dependency injection patterns
public struct CodeGenerator {
    
    // MARK: - Service Registration Generation
    
    /// Generates a static registration method for a service
    public static func generateRegistrationMethod(
        serviceName: String,
        dependencies: [DependencyInfo],
        scope: String = ".graph",
        name: String? = nil
    ) throws -> DeclSyntax {
        let parameters = generateParameterList(dependencies: dependencies)
        let nameParameter = name.map { ", name: \"\($0)\"" } ?? ""
        
        let functionDecl = try FunctionDeclSyntax("static func register(in container: Container)") {
            CodeBlockItemListSyntax {
                ExprSyntax("""
                container.register(\(raw: serviceName).self\(raw: nameParameter)) { resolver in
                    \(raw: serviceName)(\(raw: parameters))
                }.inObjectScope(\(raw: scope))
                """)
            }
        }
        
        return DeclSyntax(functionDecl)
    }
    
    /// Generates parameter list for service initialization
    private static func generateParameterList(dependencies: [DependencyInfo]) -> String {
        return dependencies.map { dependency in
            let resolverCall = generateResolverCall(for: dependency)
            return "\(dependency.name): \(resolverCall)"
        }.joined(separator: ",\n                ")
    }
    
    /// Generates resolver call for a dependency
    private static func generateResolverCall(for dependency: DependencyInfo) -> String {
        switch dependency.classification {
        case .serviceDependency, .protocolDependency:
            if dependency.isOptional {
                return "resolver.resolve(\(dependency.type).self)"
            } else {
                return "resolver.resolve(\(dependency.type).self)!"
            }
        case .configurationParameter:
            if let defaultValue = dependency.defaultValue {
                return defaultValue
            } else {
                return "resolver.resolve(\(dependency.type).self)!"
            }
        default:
            // Runtime parameters should not appear in registration
            return "/* Runtime parameter: \(dependency.name) */"
        }
    }
    
    // MARK: - Factory Generation
    
    /// Generates a factory protocol for a service
    public static func generateFactoryProtocol(
        serviceName: String,
        runtimeParameters: [DependencyInfo],
        isAsync: Bool = false,
        canThrow: Bool = false
    ) throws -> DeclSyntax {
        let factoryName = "\(serviceName)Factory"
        let methodName = generateFactoryMethodName(serviceName: serviceName)
        let parameterList = generateFactoryParameterList(runtimeParameters)
        
        var effectSpecifiers = ""
        if isAsync {
            effectSpecifiers += " async"
        }
        if canThrow {
            effectSpecifiers += " throws"
        }
        
        let protocolDecl = try ProtocolDeclSyntax("protocol \(raw: factoryName)") {
            DeclSyntax("func \(raw: methodName)(\(raw: parameterList))\(raw: effectSpecifiers) -> \(raw: serviceName)")
        }
        
        return DeclSyntax(protocolDecl)
    }
    
    /// Generates factory implementation
    public static func generateFactoryImplementation(
        serviceName: String,
        dependencies: [DependencyInfo],
        runtimeParameters: [DependencyInfo],
        isAsync: Bool = false,
        canThrow: Bool = false
    ) -> DeclSyntax {
        let factoryName = "\(serviceName)Factory"
        let implName = "\(serviceName)FactoryImpl"
        let methodName = generateFactoryMethodName(serviceName: serviceName)
        let parameterList = generateFactoryParameterList(runtimeParameters)
        let initParameterList = generateFactoryInitParameterList(dependencies, runtimeParameters)
        
        var methodSignature = "func \(methodName)(\(parameterList))"
        
        if isAsync {
            methodSignature += " async"
        }
        
        if canThrow {
            methodSignature += " throws"
        }
        
        methodSignature += " -> \(serviceName)"
        
        let implCode = """
        class \(implName): \(factoryName) {
            private let resolver: Resolver
            
            init(resolver: Resolver) {
                self.resolver = resolver
            }
            
            \(methodSignature) {
                \(canThrow ? "try " : "")\(isAsync ? "await " : "")\(serviceName)(\(initParameterList))
            }
        }
        """
        
        return DeclSyntax.fromString(implCode)
    }
    
    /// Generates factory method name from service name
    private static func generateFactoryMethodName(serviceName: String) -> String {
        return "make\(serviceName)"
    }
    
    /// Generates parameter list for factory method
    private static func generateFactoryParameterList(_ parameters: [DependencyInfo]) -> String {
        return parameters.map { param in
            "\(param.name): \(param.type)"
        }.joined(separator: ", ")
    }
    
    /// Generates parameter list for factory initialization call
    private static func generateFactoryInitParameterList(
        _ dependencies: [DependencyInfo],
        _ runtimeParameters: [DependencyInfo]
    ) -> String {
        let dependencyParams = dependencies.compactMap { dep -> String? in
            guard dep.classification == .serviceDependency || dep.classification == .protocolDependency else {
                return nil
            }
            let resolverCall = generateResolverCall(for: dep)
            return "\(dep.name): \(resolverCall)"
        }
        
        let runtimeParams = runtimeParameters.map { param in
            "\(param.name): \(param.name)"
        }
        
        return (dependencyParams + runtimeParams).joined(separator: ",\n                ")
    }
    
    // MARK: - Extension Generation
    
    /// Generates protocol conformance extension
    public static func generateProtocolConformance(
        typeName: String,
        protocolName: String,
        members: [DeclSyntax] = []
    ) -> DeclSyntax {
        let membersCode = members.map { $0.description }.joined(separator: "\n    ")
        
        let extensionCode = """
        extension \(typeName): \(protocolName) {
        \(membersCode.isEmpty ? "" : "    \(membersCode)")
        }
        """
        
        return DeclSyntax.fromString(extensionCode)
    }
    
    // MARK: - Interceptor Generation
    
    /// Generates intercepted function with AOP chain
    public static func generateInterceptedFunction(
        originalFunction: FunctionDeclSyntax,
        beforeInterceptors: [String],
        afterInterceptors: [String],
        errorHandler: String?
    ) -> DeclSyntax {
        let originalName = originalFunction.name.text
        let interceptedName = "\(originalName)Intercepted"
        let parameters = originalFunction.signature.parameterClause.description
        let returnType = originalFunction.signature.returnClause?.type.description ?? "Void"
        
        // Build interceptor chain
        var chainCode = "try "
        
        // Add before interceptors
        for interceptor in beforeInterceptors.reversed() {
            chainCode += "\(interceptor)Interceptor().intercept { "
        }
        
        // Add original function call
        let paramNames = extractParameterNames(from: originalFunction)
        chainCode += "\(originalName)(\(paramNames.joined(separator: ", ")))"
        
        // Close before interceptors
        for _ in beforeInterceptors {
            chainCode += " }"
        }
        
        // Add after interceptors if needed
        if !afterInterceptors.isEmpty {
            // After interceptors would need a different pattern
            // This is a simplified implementation
        }
        
        let functionCode = """
        func \(interceptedName)\(parameters) -> \(returnType) {
            \(chainCode)
        }
        """
        
        return DeclSyntax.fromString(functionCode)
    }
    
    /// Extracts parameter names from function declaration
    private static func extractParameterNames(from function: FunctionDeclSyntax) -> [String] {
        return function.signature.parameterClause.parameters.map { param in
            param.firstName.text
        }
    }
    
    // MARK: - Test Generation
    
    /// Generates test container setup
    public static func generateTestContainer(services: [ServiceInfo]) -> DeclSyntax {
        let registrations = services.map { service in
            generateMockRegistration(for: service)
        }.joined(separator: "\n        ")
        
        let containerCode = """
        static func testContainer() -> Container {
            let container = Container()
            
        \(registrations)
            
            return container
        }
        """
        
        return DeclSyntax.fromString(containerCode)
    }
    
    /// Generates mock registration for testing
    private static func generateMockRegistration(for service: ServiceInfo) -> String {
        let mockName = "Mock\(service.name)"
        return "container.register(\(service.name).self) { _ in \(mockName)() }"
    }
    
    // MARK: - Spy Generation
    
    /// Generates spy wrapper for method tracking
    public static func generateSpyWrapper(
        originalFunction: FunctionDeclSyntax
    ) -> DeclSyntax {
        let functionName = originalFunction.name.text
        let spyPropertyName = "\(functionName)Calls"
        let parameters = originalFunction.signature.parameterClause.description
        let returnType = originalFunction.signature.returnClause?.type.description ?? "Void"
        
        let spyCode = """
        private(set) var \(spyPropertyName): [(\(extractParameterTypes(from: originalFunction).joined(separator: ", ")))] = []
        
        func \(functionName)Spy\(parameters) -> \(returnType) {
            \(spyPropertyName).append((\(extractParameterNames(from: originalFunction).joined(separator: ", "))))
            return \(functionName)(\(extractParameterNames(from: originalFunction).joined(separator: ", ")))
        }
        """
        
        return DeclSyntax.fromString(spyCode)
    }
    
    /// Extracts parameter types from function declaration
    private static func extractParameterTypes(from function: FunctionDeclSyntax) -> [String] {
        return function.signature.parameterClause.parameters.map { param in
            param.type.description
        }
    }
    
    // MARK: - Performance Tracking Generation
    
    /// Generates performance tracked function wrapper
    public static func generatePerformanceTrackedFunction(
        originalFunction: FunctionDeclSyntax,
        metricName: String? = nil
    ) -> DeclSyntax {
        let functionName = originalFunction.name.text
        let trackedName = "\(functionName)Tracked"
        let parameters = originalFunction.signature.parameterClause.description
        let returnType = originalFunction.signature.returnClause?.type.description ?? "Void"
        let actualMetricName = metricName ?? functionName
        let paramNames = extractParameterNames(from: originalFunction)
        
        let trackedCode = """
        func \(trackedName)\(parameters) -> \(returnType) {
            let startTime = CFAbsoluteTimeGetCurrent()
            defer {
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                PerformanceTracker.shared.record(metric: "\(actualMetricName)", duration: duration)
            }
            
            return \(functionName)(\(paramNames.joined(separator: ", ")))
        }
        """
        
        return DeclSyntax.fromString(trackedCode)
    }
    
    // MARK: - Import Generation
    
    /// Generates import statements for dependencies
    public static func generateImports(for dependencies: [DependencyInfo]) -> [String] {
        var imports = Set<String>()
        
        // Always include Foundation and Swinject
        imports.insert("import Foundation")
        imports.insert("import Swinject")
        
        // Add imports based on dependency types
        for dependency in dependencies {
            if dependency.type.contains("URL") || dependency.type.contains("Date") {
                imports.insert("import Foundation")
            }
        }
        
        return Array(imports).sorted()
    }
}

// MARK: - Helper Extensions

// MARK: - Code Generation Helpers
// Note: In actual implementation, use proper SwiftSyntaxBuilder APIs instead of string literals

// Note: The above extension is illustrative. In actual SwiftSyntax usage,
// you would construct syntax trees using the proper SwiftSyntax APIs.