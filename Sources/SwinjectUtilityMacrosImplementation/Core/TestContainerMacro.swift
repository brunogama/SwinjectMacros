// TestContainerMacro.swift - @TestContainer macro implementation
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @TestContainer macro for generating test mocks and container setup
public struct TestContainerMacro: MemberMacro {

    // MARK: - MemberMacro Implementation

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {

        // Validate that this is applied to a class or struct (typically test classes)
        guard declaration.is(ClassDeclSyntax.self) || declaration.is(StructDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration.root,
                message: TestContainerMacroError(message: "@TestContainer can only be applied to classes or structs")
            )
            context.diagnose(diagnostic)
            return []
        }

        // Parse macro configuration
        let config = try parseTestContainerConfig(from: node)

        // Find services that need mocking by scanning existing members
        let serviceTypes = extractServiceTypes(from: declaration)

        // Generate test container setup method
        let containerSetupMethod = try generateTestContainerSetup(
            serviceTypes: serviceTypes,
            config: config,
            context: context
        )

        // Generate mock registration helpers
        let mockHelpers = serviceTypes.map { serviceType in
            generateMockRegistrationHelper(for: serviceType, config: config)
        }

        return [containerSetupMethod] + mockHelpers
    }

    // MARK: - Configuration Parsing

    private static func parseTestContainerConfig(from node: AttributeSyntax) throws -> TestContainerConfig {
        var autoMock = true
        var scope = ".graph"
        var mockPrefix = "Mock"
        var generateSpies = false

        // Parse attribute arguments
        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                switch argument.label?.text {
                case "autoMock":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        autoMock = boolLiteral.literal.text == "true"
                    }
                case "scope":
                    if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
                        scope = ".\(memberAccess.declName.baseName.text)"
                    }
                case "mockPrefix":
                    if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
                       let segment = stringLiteral.segments.first?.as(StringSegmentSyntax.self)
                    {
                        mockPrefix = segment.content.text
                    }
                case "generateSpies":
                    if let boolLiteral = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        generateSpies = boolLiteral.literal.text == "true"
                    }
                default:
                    break
                }
            }
        }

        return TestContainerConfig(
            autoMock: autoMock,
            scope: scope,
            mockPrefix: mockPrefix,
            generateSpies: generateSpies
        )
    }

    // MARK: - Service Type Extraction

    private static func extractServiceTypes(from declaration: some DeclGroupSyntax) -> [String] {
        var serviceTypes: Set<String> = []

        // Look for properties that might be services (ending in Service, Repository, Client, etc.)
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            for member in classDecl.memberBlock.members {
                if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                    for binding in varDecl.bindings {
                        if let typeAnnotation = binding.typeAnnotation {
                            let typeName = typeAnnotation.type.trimmedDescription
                            if isServiceType(typeName) {
                                serviceTypes.insert(typeName)
                            }
                        }
                    }
                }
            }
        } else if let structDecl = declaration.as(StructDeclSyntax.self) {
            for member in structDecl.memberBlock.members {
                if let varDecl = member.decl.as(VariableDeclSyntax.self) {
                    for binding in varDecl.bindings {
                        if let typeAnnotation = binding.typeAnnotation {
                            let typeName = typeAnnotation.type.trimmedDescription
                            if isServiceType(typeName) {
                                serviceTypes.insert(typeName)
                            }
                        }
                    }
                }
            }
        }

        return Array(serviceTypes).sorted()
    }

    private static func isServiceType(_ typeName: String) -> Bool {
        let serviceSuffixes = ["Service", "Repository", "Client", "Manager", "Provider", "Handler"]
        return serviceSuffixes.contains { typeName.hasSuffix($0) }
    }

    // MARK: - Code Generation

    private static func generateTestContainerSetup(
        serviceTypes: [String],
        config: TestContainerConfig,
        context: some MacroExpansionContext
    ) throws -> DeclSyntax {

        // Generate mock registrations
        let mockRegistrations = serviceTypes.map { serviceType in
            let mockName = "\(config.mockPrefix)\(serviceType)"
            return "        register\(serviceType)(mock: \(mockName)())"
        }.joined(separator: "\n")

        let setupCode = """
        func setupTestContainer() -> Container {
            let container = Container()

        \(mockRegistrations)

            return container
        }
        """

        return DeclSyntax.fromString(setupCode)
    }

    private static func generateMockRegistrationHelper(
        for serviceType: String,
        config: TestContainerConfig
    ) -> DeclSyntax {

        let helperCode = """
        func register\(serviceType)(mock: \(serviceType)) {
            container.register(\(serviceType).self) { _ in mock }.inObjectScope(\(config.scope))
        }
        """

        return DeclSyntax.fromString(helperCode)
    }
}

// MARK: - Supporting Types

private struct TestContainerConfig {
    let autoMock: Bool
    let scope: String
    let mockPrefix: String
    let generateSpies: Bool
}

// MARK: - Diagnostic Messages

private struct TestContainerMacroError: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "TestContainerError")
    let severity: DiagnosticSeverity = .error
}

private struct TestContainerMacroWarning: DiagnosticMessage {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "TestContainerWarning")
    let severity: DiagnosticSeverity = .warning
}
