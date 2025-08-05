// PublisherInjectMacro.swift - Combine Publisher dependency injection implementation

import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the @PublisherInject macro for Combine Publisher dependency injection
///
/// Generates Combine Publishers that reactively resolve dependencies with optional resolution patterns.
public struct PublisherInjectMacro: AccessorMacro {

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {

        // Validate that this is applied to a property
        guard let variableDecl = declaration.as(VariableDeclSyntax.self),
              let binding = variableDecl.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
              let typeAnnotation = binding.typeAnnotation?.type
        else {

            context.diagnose(Diagnostic(
                node: declaration,
                message: PublisherInjectMacroError(message: """
                @PublisherInject can only be applied to properties with explicit type annotations.

                Example:
                @PublisherInject var service: AnyPublisher<ServiceProtocol?, Never>
                """)
            ))
            return []
        }

        // Extract macro arguments
        let arguments = extractArguments(from: node)
        let propertyName = identifier.text
        let typeName = typeAnnotation.description.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate that the type is AnyPublisher
        guard typeName.contains("AnyPublisher") else {
            context.diagnose(Diagnostic(
                node: typeAnnotation,
                message: PublisherInjectMacroError(message: """
                @PublisherInject requires AnyPublisher type annotation.

                Example:
                @PublisherInject var service: AnyPublisher<ServiceProtocol?, Never>
                """)
            ))
            return []
        }

        // Extract the inner type from AnyPublisher<T?, Never>
        _ = extractInnerType(from: typeName)

        // Generate backing storage property name
        let backingStorageName = "_\(propertyName)Publisher"

        // Create the Publisher property getter
        let getter = AccessorDeclSyntax(
            accessorSpecifier: .keyword(.get)
        ) {
            CodeBlockItemListSyntax([
                CodeBlockItemSyntax(item: .expr(ExprSyntax(stringLiteral: """
                if \(backingStorageName) == nil {
                    let container = \(arguments.containerAccess)
                    \(backingStorageName) = \(arguments.publisherFactory)
                }
                return \(backingStorageName)!
                """)))
            ])
        }

        return [getter]
    }
}

// MARK: - Argument Extraction

extension PublisherInjectMacro {

    fileprivate struct MacroArguments {
        let name: String?
        let isReactive: Bool
        let debounceInterval: TimeInterval
        let containerName: String?
        let resolverName: String

        var containerAccess: String {
            if let containerName = containerName {
                "Container.named(\"\(containerName)\")"
            } else {
                "Container.publisherShared ?? Container()"
            }
        }

        var publisherFactory: String {
            let nameParam = name.map { ", name: \"\($0)\"" } ?? ""

            if isReactive {
                if debounceInterval > 0 {
                    return "container.reactivePublisherFor(\(resolverName).self\(nameParam), debounceInterval: \(debounceInterval))"
                } else {
                    return "container.reactivePublisherFor(\(resolverName).self\(nameParam))"
                }
            } else {
                return "container.publisherFor(\(resolverName).self\(nameParam))"
            }
        }
    }

    fileprivate static func extractArguments(from node: AttributeSyntax) -> MacroArguments {
        var name: String? = nil
        var isReactive = false
        var debounceInterval: TimeInterval = 0.0
        var containerName: String? = nil
        var resolverName = "resolver"

        if let arguments = node.arguments?.as(LabeledExprListSyntax.self) {
            for argument in arguments {
                if argument.label == nil {
                    // First unlabeled argument is the name
                    if let stringValue = argument.expression.as(StringLiteralExprSyntax.self) {
                        name = stringValue.segments.first?.description
                    }
                } else if argument.label?.text == "reactive" {
                    if let boolValue = argument.expression.as(BooleanLiteralExprSyntax.self) {
                        isReactive = boolValue.literal.text == "true"
                    }
                } else if argument.label?.text == "debounce" {
                    if let floatValue = argument.expression.as(FloatLiteralExprSyntax.self) {
                        debounceInterval = Double(floatValue.literal.text) ?? 0.0
                    }
                } else if argument.label?.text == "container" {
                    if let stringValue = argument.expression.as(StringLiteralExprSyntax.self) {
                        containerName = stringValue.segments.first?.description
                    }
                } else if argument.label?.text == "resolver" {
                    if let stringValue = argument.expression.as(StringLiteralExprSyntax.self) {
                        resolverName = stringValue.segments.first?.description ?? "resolver"
                    }
                }
            }
        }

        return MacroArguments(
            name: name,
            isReactive: isReactive,
            debounceInterval: debounceInterval,
            containerName: containerName,
            resolverName: resolverName
        )
    }

    fileprivate static func extractInnerType(from publisherType: String) -> String {
        // Extract T from AnyPublisher<T?, Never>
        if let startIndex = publisherType.firstIndex(of: "<"),
           let endIndex = publisherType.firstIndex(of: "?")
        {
            let innerType = String(publisherType[publisherType.index(after: startIndex)..<endIndex])
            return innerType.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Any" // Fallback
    }
}

// MARK: - Error Types

private struct PublisherInjectMacroError: DiagnosticMessage, Error {
    let message: String
    let diagnosticID = MessageID(domain: "SwinjectUtilityMacros", id: "PublisherInjectMacro")
    let severity = DiagnosticSeverity.error
}
