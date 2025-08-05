// DependencyGraphTypes.swift - Supporting types for dependency graph functionality

import Foundation

// MARK: - Core Graph Types

/// Represents a node in the dependency graph
public struct DependencyNode {
    public let id: String
    public let label: String
    public let serviceType: String
    public let objectScope: String
    public let isResolved: Bool

    public init(id: String, label: String, serviceType: String, objectScope: String, isResolved: Bool) {
        self.id = id
        self.label = label
        self.serviceType = serviceType
        self.objectScope = objectScope
        self.isResolved = isResolved
    }
}

/// Represents an edge in the dependency graph
public struct DependencyEdge {
    public let from: String
    public let to: String
    public let isOptional: Bool
    public let parameterName: String?

    public init(from: String, to: String, isOptional: Bool, parameterName: String? = nil) {
        self.from = from
        self.to = to
        self.isOptional = isOptional
        self.parameterName = parameterName
    }
}

/// Represents a complete dependency graph
public struct DependencyGraph {
    public let nodes: [DependencyNode]
    public let edges: [DependencyEdge]
    public let circularDependencies: [CircularDependencyInfo]

    public init(nodes: [DependencyNode], edges: [DependencyEdge], circularDependencies: [CircularDependencyInfo] = []) {
        self.nodes = nodes
        self.edges = edges
        self.circularDependencies = circularDependencies
    }
}

// MARK: - Container Debug Support

/// Protocol for containers that support debugging
public protocol DebuggableContainer {
    func performHealthCheck() -> ContainerHealth
}

/// Container health information
public struct ContainerHealth {
    public let isHealthy: Bool
    public let issues: [String]

    public init(isHealthy: Bool, issues: [String]) {
        self.isHealthy = isHealthy
        self.issues = issues
    }
}
