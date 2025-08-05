// ModuleDependencyGraph.swift - Module dependency graph analysis and visualization
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject

/// Analyzes and visualizes module dependencies
public final class ModuleDependencyGraphAnalyzer {

    // MARK: - Types

    /// Represents a module node in the dependency graph
    public struct ModuleNode {
        public let name: String
        public let priority: Int
        public let dependencies: Set<String>
        public let exports: Set<String>
        public let isInitialized: Bool
        public let container: Container?

        var hasCircularDependency = false
        var depth = 0
    }

    /// Represents an edge between modules
    public struct ModuleEdge {
        public let from: String
        public let to: String
        public let type: EdgeType

        public enum EdgeType {
            case dependency
            case export
            case runtime
        }
    }

    /// Module dependency analysis result
    public struct AnalysisResult {
        public let nodes: [String: ModuleNode]
        public let edges: [ModuleEdge]
        public let initializationOrder: [String]
        public let circularDependencies: Set<String>
        public let missingDependencies: [String: Set<String>]
        public let unusedExports: [String: Set<String>]
        public let moduleDepths: [String: Int]

        public var hasIssues: Bool {
            !circularDependencies.isEmpty || !missingDependencies.isEmpty
        }
    }

    // MARK: - Properties

    private let moduleSystem: ModuleSystem
    private var nodes: [String: ModuleNode] = [:]
    private var edges: [ModuleEdge] = []

    // MARK: - Initialization

    public init(moduleSystem: ModuleSystem = .shared) {
        self.moduleSystem = moduleSystem
    }

    // MARK: - Analysis

    /// Analyzes the module dependency graph
    public func analyze() -> AnalysisResult {
        buildGraph()

        let circularDeps = detectCircularDependencies()
        let missingDeps = detectMissingDependencies()
        let unusedExports = detectUnusedExports()
        let depths = calculateModuleDepths()
        let order = calculateInitializationOrder()

        return AnalysisResult(
            nodes: nodes,
            edges: edges,
            initializationOrder: order,
            circularDependencies: circularDeps,
            missingDependencies: missingDeps,
            unusedExports: unusedExports,
            moduleDepths: depths
        )
    }

    private func buildGraph() {
        nodes.removeAll()
        edges.removeAll()

        for moduleName in moduleSystem.moduleNames {
            if let info = moduleSystem.info(for: moduleName) {
                let node = ModuleNode(
                    name: moduleName,
                    priority: info.priority,
                    dependencies: Set(info.dependencies),
                    exports: Set(info.exports),
                    isInitialized: info.isInitialized,
                    container: moduleSystem.container(for: moduleName)
                )
                nodes[moduleName] = node

                // Add dependency edges
                for dep in info.dependencies {
                    edges.append(ModuleEdge(
                        from: moduleName,
                        to: dep,
                        type: .dependency
                    ))
                }

                // Add export edges
                for export in info.exports {
                    edges.append(ModuleEdge(
                        from: moduleName,
                        to: export,
                        type: .export
                    ))
                }
            }
        }
    }

    // MARK: - Circular Dependencies

    private func detectCircularDependencies() -> Set<String> {
        var circular = Set<String>()
        var visited = Set<String>()
        var visiting = Set<String>()

        for moduleName in nodes.keys {
            if !visited.contains(moduleName) {
                detectCycles(
                    module: moduleName,
                    visited: &visited,
                    visiting: &visiting,
                    circular: &circular
                )
            }
        }

        return circular
    }

    private func detectCycles(
        module: String,
        visited: inout Set<String>,
        visiting: inout Set<String>,
        circular: inout Set<String>
    ) {
        visiting.insert(module)

        if let node = nodes[module] {
            for dependency in node.dependencies {
                if visiting.contains(dependency) {
                    // Found a cycle
                    circular.insert(module)
                    circular.insert(dependency)
                } else if !visited.contains(dependency) {
                    detectCycles(
                        module: dependency,
                        visited: &visited,
                        visiting: &visiting,
                        circular: &circular
                    )
                }
            }
        }

        visiting.remove(module)
        visited.insert(module)
    }

    // MARK: - Missing Dependencies

    private func detectMissingDependencies() -> [String: Set<String>] {
        var missing: [String: Set<String>] = [:]

        for (moduleName, node) in nodes {
            let missingDeps = node.dependencies.filter { dep in
                !self.nodes.keys.contains(dep)
            }

            if !missingDeps.isEmpty {
                missing[moduleName] = Set(missingDeps)
            }
        }

        return missing
    }

    // MARK: - Unused Exports

    private func detectUnusedExports() -> [String: Set<String>] {
        var allImports = Set<String>()
        var moduleExports: [String: Set<String>] = [:]

        // Collect all exports and imports
        for (moduleName, node) in nodes {
            moduleExports[moduleName] = node.exports

            // Check what each module actually uses from others
            if node.container != nil {
                // This would require runtime inspection of container registrations
                // For now, we'll mark all exports as potentially used
                allImports.formUnion(node.exports)
            }
        }

        // Find unused exports
        var unused: [String: Set<String>] = [:]
        for (moduleName, exports) in moduleExports {
            let unusedInModule = exports.subtracting(allImports)
            if !unusedInModule.isEmpty {
                unused[moduleName] = unusedInModule
            }
        }

        return unused
    }

    // MARK: - Module Depths

    private func calculateModuleDepths() -> [String: Int] {
        var depths: [String: Int] = [:]
        var visited = Set<String>()

        // Find root modules (no dependencies)
        let roots = nodes.filter { $0.value.dependencies.isEmpty }.map { $0.key }

        for root in roots {
            calculateDepth(module: root, depth: 0, depths: &depths, visited: &visited)
        }

        // Handle modules not reachable from roots
        for module in nodes.keys where !visited.contains(module) {
            calculateDepth(module: module, depth: 0, depths: &depths, visited: &visited)
        }

        return depths
    }

    private func calculateDepth(
        module: String,
        depth: Int,
        depths: inout [String: Int],
        visited: inout Set<String>
    ) {
        if visited.contains(module) {
            depths[module] = max(depths[module] ?? 0, depth)
            return
        }

        visited.insert(module)
        depths[module] = depth

        // Find modules that depend on this one
        let dependents = nodes.filter { $0.value.dependencies.contains(module) }.map { $0.key }
        for dependent in dependents {
            calculateDepth(module: dependent, depth: depth + 1, depths: &depths, visited: &visited)
        }
    }

    // MARK: - Initialization Order

    private func calculateInitializationOrder() -> [String] {
        var order: [String] = []
        var visited = Set<String>()
        var visiting = Set<String>()

        for module in nodes.keys {
            if !visited.contains(module) {
                visitForOrder(
                    module: module,
                    visited: &visited,
                    visiting: &visiting,
                    order: &order
                )
            }
        }

        return order
    }

    private func visitForOrder(
        module: String,
        visited: inout Set<String>,
        visiting: inout Set<String>,
        order: inout [String]
    ) {
        if visited.contains(module) || visiting.contains(module) {
            return
        }

        visiting.insert(module)

        if let node = nodes[module] {
            for dependency in node.dependencies {
                visitForOrder(
                    module: dependency,
                    visited: &visited,
                    visiting: &visiting,
                    order: &order
                )
            }
        }

        visiting.remove(module)
        visited.insert(module)
        order.append(module)
    }

    // MARK: - Visualization

    /// Generates a GraphViz DOT representation of the module graph
    public func generateDOT() -> String {
        let result = analyze()

        var dot = "digraph ModuleDependencyGraph {\n"
        dot += "    rankdir=TB;\n"
        dot += "    node [shape=box, style=rounded];\n"
        dot += "    \n"

        // Add nodes with styling
        for (name, node) in result.nodes {
            var attributes: [String] = []

            // Color based on state
            if result.circularDependencies.contains(name) {
                attributes.append("fillcolor=\"#ffcccc\"")
                attributes.append("style=\"filled,rounded\"")
            } else if node.isInitialized {
                attributes.append("fillcolor=\"#ccffcc\"")
                attributes.append("style=\"filled,rounded\"")
            } else {
                attributes.append("fillcolor=\"#ffffcc\"")
                attributes.append("style=\"filled,rounded\"")
            }

            // Add priority to label
            let label = "\(name)\\n[Priority: \(node.priority)]"
            attributes.append("label=\"\(label)\"")

            dot += "    \"\(name)\" [\(attributes.joined(separator: ", "))];\n"
        }

        dot += "    \n"

        // Add edges
        for edge in result.edges {
            switch edge.type {
            case .dependency:
                dot += "    \"\(edge.from)\" -> \"\(edge.to)\" [color=blue];\n"
            case .export:
                dot += "    \"\(edge.from)\" -> \"\(edge.to)\" [color=green, style=dashed];\n"
            case .runtime:
                dot += "    \"\(edge.from)\" -> \"\(edge.to)\" [color=gray, style=dotted];\n"
            }
        }

        // Add legend
        dot += "    \n"
        dot += "    subgraph cluster_legend {\n"
        dot += "        label=\"Legend\";\n"
        dot += "        style=rounded;\n"
        dot += "        \"Initialized\" [fillcolor=\"#ccffcc\", style=filled];\n"
        dot += "        \"Not Initialized\" [fillcolor=\"#ffffcc\", style=filled];\n"
        dot += "        \"Circular Dependency\" [fillcolor=\"#ffcccc\", style=filled];\n"
        dot += "        \"Initialized\" -> \"Not Initialized\" [label=\"Dependency\", color=blue];\n"
        dot += "        \"Not Initialized\" -> \"Circular Dependency\" [label=\"Export\", color=green, style=dashed];\n"
        dot += "    }\n"

        dot += "}\n"

        return dot
    }

    /// Generates a Mermaid diagram of the module graph
    public func generateMermaid() -> String {
        let result = analyze()

        var mermaid = "graph TB\n"

        // Group modules by depth
        let depthGroups = Dictionary(grouping: result.moduleDepths) { $0.value }

        for depth in depthGroups.keys.sorted() {
            let modules = depthGroups[depth]?.map { $0.key } ?? []

            if !modules.isEmpty {
                mermaid += "    subgraph Level\(depth)[\"Level \(depth)\"]\n"
                for module in modules {
                    let node = result.nodes[module]!
                    let style = result.circularDependencies.contains(module) ? ":::error" :
                        node.isInitialized ? ":::success" : ":::warning"
                    mermaid += "        \(module)[\"\(module)<br/>Priority: \(node.priority)\"]\(style)\n"
                }
                mermaid += "    end\n"
            }
        }

        // Add edges
        for edge in result.edges {
            if edge.type == .dependency {
                let style = result.circularDependencies.contains(edge.from) &&
                    result.circularDependencies.contains(edge.to) ? "-.->|circular|" : "-->"
                mermaid += "    \(edge.from) \(style) \(edge.to)\n"
            }
        }

        // Add styles
        mermaid += "    classDef success fill:#ccffcc,stroke:#333,stroke-width:2px\n"
        mermaid += "    classDef warning fill:#ffffcc,stroke:#333,stroke-width:2px\n"
        mermaid += "    classDef error fill:#ffcccc,stroke:#333,stroke-width:2px\n"

        return mermaid
    }

    /// Generates a text report of the module analysis
    public func generateReport() -> String {
        let result = analyze()

        var report = "Module Dependency Analysis Report\n"
        report += "=" * 50 + "\n\n"

        // Summary
        report += "Summary:\n"
        report += "  Total Modules: \(result.nodes.count)\n"
        report += "  Total Dependencies: \(result.edges.filter { $0.type == .dependency }.count)\n"
        report += "  Circular Dependencies: \(!result.circularDependencies.isEmpty ? "YES ⚠️" : "None ✅")\n"
        report +=
            "  Missing Dependencies: \(result.missingDependencies.isEmpty ? "None ✅" : "\(result.missingDependencies.count) ⚠️")\n"
        report += "\n"

        // Initialization Order
        report += "Initialization Order:\n"
        for (index, module) in result.initializationOrder.enumerated() {
            let node = result.nodes[module]!
            let status = node.isInitialized ? "✅" : "⏳"
            report += "  \(index + 1). \(module) \(status) (Priority: \(node.priority))\n"
        }
        report += "\n"

        // Module Details
        report += "Module Details:\n"
        for module in result.nodes.keys.sorted() {
            let node = result.nodes[module]!
            report += "  \(module):\n"
            report += "    Priority: \(node.priority)\n"
            report += "    Status: \(node.isInitialized ? "Initialized" : "Not Initialized")\n"
            report += "    Depth: \(result.moduleDepths[module] ?? 0)\n"

            if !node.dependencies.isEmpty {
                report += "    Dependencies: \(node.dependencies.sorted().joined(separator: ", "))\n"
            }

            if !node.exports.isEmpty {
                report += "    Exports: \(node.exports.sorted().joined(separator: ", "))\n"
            }

            if result.circularDependencies.contains(module) {
                report += "    ⚠️ Part of circular dependency\n"
            }

            if let missing = result.missingDependencies[module] {
                report += "    ⚠️ Missing: \(missing.sorted().joined(separator: ", "))\n"
            }

            report += "\n"
        }

        // Issues
        if result.hasIssues {
            report += "Issues Found:\n"

            if !result.circularDependencies.isEmpty {
                report += "  Circular Dependencies:\n"
                for module in result.circularDependencies.sorted() {
                    report += "    - \(module)\n"
                }
            }

            if !result.missingDependencies.isEmpty {
                report += "  Missing Dependencies:\n"
                for (module, missing) in result.missingDependencies.sorted(by: { $0.key < $1.key }) {
                    report += "    - \(module): \(missing.sorted().joined(separator: ", "))\n"
                }
            }
        }

        return report
    }
}

// String * operator moved to StringExtensions.swift
