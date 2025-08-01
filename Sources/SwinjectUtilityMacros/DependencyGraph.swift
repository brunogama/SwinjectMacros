// DependencyGraph.swift - Dependency graph generation and circular dependency detection macro declarations

import Foundation
import Swinject

// MARK: - @DependencyGraph Macro

/// Generates comprehensive dependency graph visualization and performs compile-time circular dependency detection.
///
/// This macro analyzes dependency relationships between services and generates visual representations
/// while detecting circular dependencies at both compile-time and runtime for robust dependency management.
///
/// ## Basic Usage
///
/// ```swift
/// @DependencyGraph
/// class ServiceRegistry {
///     static func registerServices(in container: Container) {
///         container.register(UserService.self) { resolver in
///             UserService(
///                 database: resolver.resolve(DatabaseProtocol.self)!,
///                 logger: resolver.resolve(LoggerProtocol.self)!
///             )
///         }
///         
///         container.register(DatabaseProtocol.self) { _ in
///             PostgreSQLDatabase()
///         }
///     }
/// }
///
/// // Generated dependency graph visualization available:
/// ServiceRegistry.generateDependencyGraph() // Returns GraphViz DOT format
/// ServiceRegistry.detectCircularDependencies() // Returns circular dependency report
/// ```
///
/// ## Advanced Graph Configuration
///
/// ```swift
/// @DependencyGraph(
///     format: .graphviz,
///     includeOptional: true,
///     detectCycles: true,
///     exportPath: "docs/dependencies.dot",
///     realTimeUpdates: true
/// )
/// class ProductionRegistry {
///     // Enhanced dependency analysis with real-time updates
/// }
/// ```
///
/// ## Circular Dependency Detection
///
/// ```swift
/// @DependencyGraph(
///     strictCycleDetection: true,
///     breakCyclesAutomatically: false
/// )
/// class StrictRegistry {
///     // Compile-time error if circular dependencies detected
/// }
///
/// // Runtime circular dependency detection:
/// if let cycles = ServiceRegistry.findCircularDependencies() {
///     for cycle in cycles {
///         print("⚠️ Circular dependency: \(cycle.description)")
///         print("💡 Suggestion: \(cycle.resolutionSuggestion)")
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Graph Generation**: Methods to create dependency graph representations
/// 2. **Cycle Detection**: Compile-time and runtime circular dependency detection
/// 3. **Visualization Export**: GraphViz DOT format and other visualization formats
/// 4. **Dependency Analysis**: Detailed dependency relationship analysis
/// 5. **Health Monitoring**: Real-time dependency health checking
///
/// ## Graph Formats
///
/// ### GraphViz DOT Format
/// ```swift
/// let dotGraph = ServiceRegistry.generateDependencyGraph()
/// print(dotGraph)
/// // Output:
/// // digraph Dependencies {
/// //     "UserService" -> "DatabaseProtocol";
/// //     "UserService" -> "LoggerProtocol";
/// // }
/// ```
///
/// ### JSON Format
/// ```swift
/// let jsonGraph = ServiceRegistry.generateDependencyGraphJSON()
/// // Returns structured JSON with nodes and edges
/// ```
///
/// ### Mermaid Format
/// ```swift
/// let mermaidGraph = ServiceRegistry.generateMermaidGraph()
/// // Returns Mermaid.js compatible graph syntax
/// ```
@attached(member, names: named(generateDependencyGraph), named(detectCircularDependencies), named(exportDependencyGraph))
@attached(extension, conformances: DependencyGraphProvider)
public macro DependencyGraph(
    format: GraphFormat = .graphviz,
    includeOptional: Bool = true,
    detectCycles: Bool = true,
    exportPath: String? = nil,
    realTimeUpdates: Bool = false,
    strictCycleDetection: Bool = true,
    breakCyclesAutomatically: Bool = false
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "DependencyGraphMacro")

// MARK: - Dependency Graph Support Types

/// Supported graph output formats
public enum GraphFormat: String, CaseIterable {
    case graphviz = "dot"
    case json = "json"
    case mermaid = "mermaid"
    case xml = "xml"
    case yaml = "yaml"
}

/// Configuration for dependency graph generation
public struct DependencyGraphConfiguration {
    public let format: GraphFormat
    public let includeOptional: Bool
    public let detectCycles: Bool
    public let exportPath: String?
    public let realTimeUpdates: Bool
    public let strictCycleDetection: Bool
    public let breakCyclesAutomatically: Bool
    
    public init(
        format: GraphFormat = .graphviz,
        includeOptional: Bool = true,  
        detectCycles: Bool = true,
        exportPath: String? = nil,
        realTimeUpdates: Bool = false,
        strictCycleDetection: Bool = true,
        breakCyclesAutomatically: Bool = false
    ) {
        self.format = format
        self.includeOptional = includeOptional
        self.detectCycles = detectCycles
        self.exportPath = exportPath
        self.realTimeUpdates = realTimeUpdates
        self.strictCycleDetection = strictCycleDetection
        self.breakCyclesAutomatically = breakCyclesAutomatically
    }
}

/// Protocol for types that can provide dependency graphs
public protocol DependencyGraphProvider {
    /// Generate dependency graph in the specified format
    func generateDependencyGraph(format: GraphFormat) -> String
    
    /// Detect circular dependencies in the service graph
    func detectCircularDependencies() -> [CircularDependencyInfo]
    
    /// Export dependency graph to file
    func exportDependencyGraph(to path: String, format: GraphFormat) throws
    
    /// Get dependency analysis report
    func getDependencyAnalysis() -> DependencyAnalysisReport
}

/// Information about a circular dependency
public struct CircularDependencyInfo {
    public let cycle: [String]
    public let severity: CycleSeverity
    public let detectedAt: Date
    public let resolutionSuggestion: String
    
    public enum CycleSeverity {
        case warning   // Optional dependency cycle
        case error     // Required dependency cycle
        case critical  // Unresolvable cycle
    }
    
    public init(cycle: [String], severity: CycleSeverity, detectedAt: Date = Date(), resolutionSuggestion: String) {
        self.cycle = cycle
        self.severity = severity
        self.detectedAt = detectedAt
        self.resolutionSuggestion = resolutionSuggestion
    }
    
    public var description: String {
        return cycle.joined(separator: " → ") + " → " + (cycle.first ?? "")
    }
}

/// Comprehensive dependency analysis report
public struct DependencyAnalysisReport {
    public let totalServices: Int
    public let totalDependencies: Int
    public let circularDependencies: [CircularDependencyInfo]
    public let orphanedServices: [String]
    public let highlyDependentServices: [String]
    public let dependencyDepth: [String: Int]
    public let analysisTimestamp: Date
    
    public init(
        totalServices: Int,
        totalDependencies: Int,
        circularDependencies: [CircularDependencyInfo] = [],
        orphanedServices: [String] = [],
        highlyDependentServices: [String] = [],
        dependencyDepth: [String: Int] = [:],
        analysisTimestamp: Date = Date()
    ) {
        self.totalServices = totalServices
        self.totalDependencies = totalDependencies
        self.circularDependencies = circularDependencies
        self.orphanedServices = orphanedServices
        self.highlyDependentServices = highlyDependentServices
        self.dependencyDepth = dependencyDepth
        self.analysisTimestamp = analysisTimestamp
    }
    
    /// Check if the dependency graph is healthy
    public var isHealthy: Bool {
        return circularDependencies.isEmpty && orphanedServices.isEmpty
    }
    
    /// Get health score (0.0 - 1.0)
    public var healthScore: Double {
        let circularPenalty = Double(circularDependencies.count) * 0.3
        let orphanPenalty = Double(orphanedServices.count) * 0.1
        let totalPenalty = circularPenalty + orphanPenalty
        return max(0.0, 1.0 - (totalPenalty / Double(totalServices)))
    }
}

// MARK: - Graph Generators

/// Utility for generating dependency graphs in various formats
public struct DependencyGraphGenerator {
    
    /// Generate GraphViz DOT format graph
    public static func generateDotGraph(
        nodes: [DependencyNode],
        edges: [DependencyEdge],
        title: String = "Dependency Graph"
    ) -> String {
        var dot = "digraph \"\(title)\" {\n"
        dot += "    rankdir=TB;\n"
        dot += "    node [shape=box, style=\"rounded,filled\", fontname=\"Arial\"];\n"
        dot += "    edge [fontname=\"Arial\", fontsize=10];\n\n"
        
        // Add nodes with styling
        for node in nodes {
            let fillColor = getNodeColor(for: node)
            let shape = getNodeShape(for: node)
            dot += "    \"\(node.id)\" [label=\"\(node.label)\", fillcolor=\(fillColor), shape=\(shape)];\n"
        }
        
        dot += "\n"
        
        // Add edges with styling
        for edge in edges {
            let style = edge.isOptional ? "dashed" : "solid"
            let color = edge.isOptional ? "gray" : "black"
            var edgeLabel = ""
            if let paramName = edge.parameterName {
                edgeLabel = " [label=\"\(paramName)\"]"
            }
            dot += "    \"\(edge.from)\" -> \"\(edge.to)\" [style=\(style), color=\(color)\(edgeLabel)];\n"
        }
        
        dot += "}\n"
        return dot
    }
    
    /// Generate JSON format graph
    public static func generateJSONGraph(
        nodes: [DependencyNode],
        edges: [DependencyEdge]
    ) -> String {
        let graph: [String: Any] = [
            "nodes": nodes.map { node in
                [
                    "id": node.id,
                    "label": node.label,
                    "serviceType": node.serviceType,
                    "objectScope": node.objectScope,
                    "isResolved": node.isResolved
                ]
            },
            "edges": edges.map { edge in
                [
                    "from": edge.from,
                    "to": edge.to,
                    "isOptional": edge.isOptional,
                    "parameterName": edge.parameterName as Any
                ]
            }
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: graph, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to serialize graph to JSON\"}"
        }
    }
    
    /// Generate Mermaid.js format graph
    public static func generateMermaidGraph(
        nodes: [DependencyNode],
        edges: [DependencyEdge]
    ) -> String {
        var mermaid = "graph TD\n"
        
        // Add nodes
        for node in nodes {
            let shape = node.isResolved ? "[]" : "()"
            mermaid += "    \(node.id)[\(node.label)]\n"
        }
        
        mermaid += "\n"
        
        // Add edges
        for edge in edges {
            let arrow = edge.isOptional ? "-.->" : "-->"
            mermaid += "    \(edge.from) \(arrow) \(edge.to)\n"
        }
        
        return mermaid
    }
    
    private static func getNodeColor(for node: DependencyNode) -> String {
        switch node.objectScope.lowercased() {
        case "container": return "lightblue"
        case "graph": return "lightgreen"
        case "transient": return "lightyellow"
        default: return node.isResolved ? "lightgreen" : "lightgray"
        }
    }
    
    private static func getNodeShape(for node: DependencyNode) -> String {
        return node.isResolved ? "box" : "ellipse"
    }
}

// MARK: - Circular Dependency Detection

/// Advanced circular dependency detector
public class CircularDependencyDetector {
    
    /// Detect all circular dependencies in a dependency graph
    public static func detectCircularDependencies(
        in graph: DependencyGraph
    ) -> [CircularDependencyInfo] {
        var cycles: [CircularDependencyInfo] = []
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        var currentPath: [String] = []
        
        for node in graph.nodes {
            if !visited.contains(node.id) {
                detectCyclesRecursive(
                    nodeId: node.id,
                    graph: graph,
                    visited: &visited,
                    recursionStack: &recursionStack,
                    currentPath: &currentPath,
                    cycles: &cycles
                )
            }
        }
        
        return cycles
    }
    
    private static func detectCyclesRecursive(
        nodeId: String,
        graph: DependencyGraph,
        visited: inout Set<String>,
        recursionStack: inout Set<String>,
        currentPath: inout [String],
        cycles: inout [CircularDependencyInfo]
    ) {
        visited.insert(nodeId)
        recursionStack.insert(nodeId)
        currentPath.append(nodeId)
        
        // Find all edges from this node
        let outgoingEdges = graph.edges.filter { $0.from == nodeId }
        
        for edge in outgoingEdges {
            let targetId = edge.to
            
            if !visited.contains(targetId) {
                // Continue DFS
                detectCyclesRecursive(
                    nodeId: targetId,
                    graph: graph,
                    visited: &visited,
                    recursionStack: &recursionStack,
                    currentPath: &currentPath,
                    cycles: &cycles
                )
            } else if recursionStack.contains(targetId) {
                // Found a cycle
                if let cycleStartIndex = currentPath.firstIndex(of: targetId) {
                    let cycle = Array(currentPath[cycleStartIndex...])
                    let severity: CircularDependencyInfo.CycleSeverity = edge.isOptional ? .warning : .error
                    let suggestion = generateResolutionSuggestion(for: cycle)
                    
                    cycles.append(CircularDependencyInfo(
                        cycle: cycle,
                        severity: severity,
                        resolutionSuggestion: suggestion
                    ))
                }
            }
        }
        
        recursionStack.remove(nodeId)
        currentPath.removeLast()
    }
    
    private static func generateResolutionSuggestion(for cycle: [String]) -> String {
        if cycle.count == 2 {
            return "Consider using lazy injection or breaking the dependency with an interface"
        } else if cycle.count <= 4 {
            return "Consider introducing a mediator service or using event-driven architecture"
        } else {
            return "Complex circular dependency detected. Consider refactoring to reduce coupling"
        }
    }
}

// MARK: - Graph Visualization Tools

/// Tools for visualizing and analyzing dependency graphs
public struct GraphVisualizationTools {
    
    /// Export graph to various formats
    public static func exportGraph(
        _ graph: DependencyGraph,
        to path: String,
        format: GraphFormat
    ) throws {
        let content: String
        
        switch format {
        case .graphviz:
            content = DependencyGraphGenerator.generateDotGraph(
                nodes: graph.nodes,
                edges: graph.edges
            )
        case .json:
            content = DependencyGraphGenerator.generateJSONGraph(
                nodes: graph.nodes,
                edges: graph.edges
            )
        case .mermaid:
            content = DependencyGraphGenerator.generateMermaidGraph(
                nodes: graph.nodes,
                edges: graph.edges
            )
        case .xml:
            content = generateXMLGraph(graph)
        case .yaml:
            content = generateYAMLGraph(graph)
        }
        
        try content.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }
    
    /// Generate graph statistics
    public static func generateStatistics(for graph: DependencyGraph) -> GraphStatistics {
        let nodeCount = graph.nodes.count
        let edgeCount = graph.edges.count
        let optionalEdgeCount = graph.edges.filter { $0.isOptional }.count
        let circularDependencyCount = graph.circularDependencies.count
        
        // Calculate node degrees
        var inDegree: [String: Int] = [:]
        var outDegree: [String: Int] = [:]
        
        for node in graph.nodes {
            inDegree[node.id] = 0
            outDegree[node.id] = 0
        }
        
        for edge in graph.edges {
            outDegree[edge.from, default: 0] += 1
            inDegree[edge.to, default: 0] += 1
        }
        
        let maxInDegree = inDegree.values.max() ?? 0
        let maxOutDegree = outDegree.values.max() ?? 0
        let avgInDegree = Double(edgeCount) / Double(nodeCount)
        let avgOutDegree = avgInDegree // Same for directed graphs
        
        return GraphStatistics(
            nodeCount: nodeCount,
            edgeCount: edgeCount,
            optionalEdgeCount: optionalEdgeCount,
            circularDependencyCount: circularDependencyCount,
            maxInDegree: maxInDegree,
            maxOutDegree: maxOutDegree,
            averageInDegree: avgInDegree,
            averageOutDegree: avgOutDegree,
            inDegree: inDegree,
            outDegree: outDegree
        )
    }
    
    private static func generateXMLGraph(_ graph: DependencyGraph) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<dependencyGraph>\n"
        
        xml += "  <nodes>\n"
        for node in graph.nodes {
            xml += "    <node id=\"\(node.id)\" label=\"\(node.label)\" serviceType=\"\(node.serviceType)\" scope=\"\(node.objectScope)\" resolved=\"\(node.isResolved)\"/>\n"
        }
        xml += "  </nodes>\n"
        
        xml += "  <edges>\n"
        for edge in graph.edges {
            xml += "    <edge from=\"\(edge.from)\" to=\"\(edge.to)\" optional=\"\(edge.isOptional)\"/>\n"
        }
        xml += "  </edges>\n"
        
        xml += "</dependencyGraph>\n"
        return xml
    }
    
    private static func generateYAMLGraph(_ graph: DependencyGraph) -> String {
        var yaml = "dependencyGraph:\n"
        
        yaml += "  nodes:\n"
        for node in graph.nodes {
            yaml += "    - id: \(node.id)\n"
            yaml += "      label: \(node.label)\n"
            yaml += "      serviceType: \(node.serviceType)\n"
            yaml += "      scope: \(node.objectScope)\n"
            yaml += "      resolved: \(node.isResolved)\n"
        }
        
        yaml += "  edges:\n"
        for edge in graph.edges {
            yaml += "    - from: \(edge.from)\n"
            yaml += "      to: \(edge.to)\n"
            yaml += "      optional: \(edge.isOptional)\n"
        }
        
        return yaml
    }
}

/// Statistical information about a dependency graph
public struct GraphStatistics {
    public let nodeCount: Int
    public let edgeCount: Int
    public let optionalEdgeCount: Int
    public let circularDependencyCount: Int
    public let maxInDegree: Int
    public let maxOutDegree: Int
    public let averageInDegree: Double
    public let averageOutDegree: Double
    public let inDegree: [String: Int]
    public let outDegree: [String: Int]
    
    public init(
        nodeCount: Int,
        edgeCount: Int,
        optionalEdgeCount: Int,
        circularDependencyCount: Int,
        maxInDegree: Int,
        maxOutDegree: Int,
        averageInDegree: Double,
        averageOutDegree: Double,
        inDegree: [String: Int],
        outDegree: [String: Int]
    ) {
        self.nodeCount = nodeCount
        self.edgeCount = edgeCount
        self.optionalEdgeCount = optionalEdgeCount
        self.circularDependencyCount = circularDependencyCount
        self.maxInDegree = maxInDegree
        self.maxOutDegree = maxOutDegree
        self.averageInDegree = averageInDegree
        self.averageOutDegree = averageOutDegree
        self.inDegree = inDegree
        self.outDegree = outDegree
    }
    
    /// Get the most depended-upon services
    public var mostDependedUpon: [String] {
        return inDegree.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }
    
    /// Get the services with the most dependencies
    public var mostDependencies: [String] {
        return outDegree.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
    }
}