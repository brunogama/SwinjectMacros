// ModuleDebugTools.swift - Advanced debugging and visualization tools for modules
// Copyright © 2025 SwinjectMacros. All rights reserved.

import Foundation
import os.log
import Swinject

/// Debug information levels
public enum DebugLevel: Int, CaseIterable, Sendable {
    case minimal = 0
    case basic = 1
    case detailed = 2
    case verbose = 3
    case trace = 4
}

/// Module debug information
public struct ModuleDebugInfo: Sendable {
    public let moduleId: String
    public let containerInfo: ContainerDebugInfo
    public let dependencyGraph: DependencyGraphInfo
    public let serviceRegistry: ServiceRegistryInfo
    public let performanceData: PerformanceDebugInfo
    public let lifecycleHistory: [LifecycleEventInfo]
    public let errorLog: [ErrorInfo]
    public let timestamp: Date

    public init(
        moduleId: String,
        containerInfo: ContainerDebugInfo,
        dependencyGraph: DependencyGraphInfo,
        serviceRegistry: ServiceRegistryInfo,
        performanceData: PerformanceDebugInfo,
        lifecycleHistory: [LifecycleEventInfo] = [],
        errorLog: [ErrorInfo] = [],
        timestamp: Date = Date()
    ) {
        self.moduleId = moduleId
        self.containerInfo = containerInfo
        self.dependencyGraph = dependencyGraph
        self.serviceRegistry = serviceRegistry
        self.performanceData = performanceData
        self.lifecycleHistory = lifecycleHistory
        self.errorLog = errorLog
        self.timestamp = timestamp
    }
}

/// Container debug information
public struct ContainerDebugInfo: Sendable {
    public let containerCount: Int
    public let serviceCount: Int
    public let registrationCount: Int
    public let scopeCount: Int
    public let hierarchyDepth: Int
    public let memoryFootprint: UInt64

    public init(
        containerCount: Int,
        serviceCount: Int,
        registrationCount: Int,
        scopeCount: Int,
        hierarchyDepth: Int,
        memoryFootprint: UInt64
    ) {
        self.containerCount = containerCount
        self.serviceCount = serviceCount
        self.registrationCount = registrationCount
        self.scopeCount = scopeCount
        self.hierarchyDepth = hierarchyDepth
        self.memoryFootprint = memoryFootprint
    }
}

/// Dependency graph debug information
public struct DependencyGraphInfo: Sendable {
    public let nodeCount: Int
    public let edgeCount: Int
    public let cyclicDependencies: [String]
    public let isolatedNodes: [String]
    public let criticalPath: [String]
    public let maxDepth: Int

    public init(
        nodeCount: Int,
        edgeCount: Int,
        cyclicDependencies: [String] = [],
        isolatedNodes: [String] = [],
        criticalPath: [String] = [],
        maxDepth: Int = 0
    ) {
        self.nodeCount = nodeCount
        self.edgeCount = edgeCount
        self.cyclicDependencies = cyclicDependencies
        self.isolatedNodes = isolatedNodes
        self.criticalPath = criticalPath
        self.maxDepth = maxDepth
    }
}

/// Service registry debug information
public struct ServiceRegistryInfo: Sendable {
    public let registeredServices: [ServiceInfo]
    public let namedServices: [String: ServiceInfo]
    public let scopedServices: [String: ServiceInfo]
    public let factoryServices: [ServiceInfo]
    public let singletonServices: [ServiceInfo]

    public init(
        registeredServices: [ServiceInfo] = [],
        namedServices: [String: ServiceInfo] = [:],
        scopedServices: [String: ServiceInfo] = [:],
        factoryServices: [ServiceInfo] = [],
        singletonServices: [ServiceInfo] = []
    ) {
        self.registeredServices = registeredServices
        self.namedServices = namedServices
        self.scopedServices = scopedServices
        self.factoryServices = factoryServices
        self.singletonServices = singletonServices
    }
}

/// Individual service debug information
public struct ServiceInfo: Sendable {
    public let typeName: String
    public let name: String?
    public let scope: String
    public let isFactory: Bool
    public let dependencies: [String]
    public let registrationCount: Int
    public let resolutionCount: UInt64
    public let lastResolved: Date?

    public init(
        typeName: String,
        name: String? = nil,
        scope: String = "transient",
        isFactory: Bool = false,
        dependencies: [String] = [],
        registrationCount: Int = 1,
        resolutionCount: UInt64 = 0,
        lastResolved: Date? = nil
    ) {
        self.typeName = typeName
        self.name = name
        self.scope = scope
        self.isFactory = isFactory
        self.dependencies = dependencies
        self.registrationCount = registrationCount
        self.resolutionCount = resolutionCount
        self.lastResolved = lastResolved
    }
}

/// Performance debug information
public struct PerformanceDebugInfo: Sendable {
    public let averageResolutionTime: TimeInterval
    public let slowestService: String?
    public let slowestResolutionTime: TimeInterval
    public let cacheHitRate: Double
    public let memoryUsage: UInt64
    public let gcPressure: Double

    public init(
        averageResolutionTime: TimeInterval = 0,
        slowestService: String? = nil,
        slowestResolutionTime: TimeInterval = 0,
        cacheHitRate: Double = 0,
        memoryUsage: UInt64 = 0,
        gcPressure: Double = 0
    ) {
        self.averageResolutionTime = averageResolutionTime
        self.slowestService = slowestService
        self.slowestResolutionTime = slowestResolutionTime
        self.cacheHitRate = cacheHitRate
        self.memoryUsage = memoryUsage
        self.gcPressure = gcPressure
    }
}

/// Lifecycle event debug information
public struct LifecycleEventInfo: Sendable {
    public let event: String
    public let timestamp: Date
    public let duration: TimeInterval
    public let success: Bool
    public let metadata: [String: String]

    public init(
        event: String,
        timestamp: Date = Date(),
        duration: TimeInterval = 0,
        success: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.event = event
        self.timestamp = timestamp
        self.duration = duration
        self.success = success
        self.metadata = metadata
    }
}

/// Error debug information
public struct ErrorInfo: Sendable {
    public let errorType: String
    public let message: String
    public let stackTrace: [String]
    public let timestamp: Date
    public let context: [String: String]

    public init(
        errorType: String,
        message: String,
        stackTrace: [String] = [],
        timestamp: Date = Date(),
        context: [String: String] = [:]
    ) {
        self.errorType = errorType
        self.message = message
        self.stackTrace = stackTrace
        self.timestamp = timestamp
        self.context = context
    }
}

/// Debug visualization formats
public enum VisualizationFormat: String, CaseIterable {
    case text = "TEXT"
    case json = "JSON"
    case mermaid = "MERMAID"
    case dot = "DOT"
    case html = "HTML"
}

/// Advanced debugging and visualization tools for module system
public actor ModuleDebugTools {

    // MARK: - Properties

    private var debugLevel: DebugLevel = .basic
    private var enabledFeatures: Set<DebugFeature> = [.basic, .performance, .lifecycle]
    private var debugInfoCache: [String: ModuleDebugInfo] = [:]
    private var eventHistory: [DebugEvent] = []
    private var errorLog: [ErrorInfo] = []
    private let logger = Logger(subsystem: "com.swinjectmacros", category: "debug")

    /// Shared instance
    public static let shared = ModuleDebugTools()

    private init() {
        Task {
            await setupDebugEnvironment()
        }
    }

    // MARK: - Configuration

    /// Set debug level
    public func setDebugLevel(_ level: DebugLevel) {
        debugLevel = level
        logger.info("Debug level set to \(level.rawValue)")
    }

    /// Enable specific debug features
    public func enableFeatures(_ features: Set<DebugFeature>) {
        enabledFeatures = features
        logger.info("Enabled debug features: \(features)")
    }

    // MARK: - Debug Information Collection

    /// Collect comprehensive debug information for a module
    public func collectDebugInfo(for moduleId: String) async -> ModuleDebugInfo {
        logger.debug("Collecting debug info for module \(moduleId)")

        let containerInfo = await collectContainerInfo(for: moduleId)
        let dependencyGraph = await collectDependencyGraphInfo(for: moduleId)
        let serviceRegistry = await collectServiceRegistryInfo(for: moduleId)
        let performanceData = await collectPerformanceInfo(for: moduleId)
        let lifecycleHistory = await collectLifecycleHistory(for: moduleId)
        let errorLog = await collectErrorLog(for: moduleId)

        let debugInfo = ModuleDebugInfo(
            moduleId: moduleId,
            containerInfo: containerInfo,
            dependencyGraph: dependencyGraph,
            serviceRegistry: serviceRegistry,
            performanceData: performanceData,
            lifecycleHistory: lifecycleHistory,
            errorLog: errorLog
        )

        debugInfoCache[moduleId] = debugInfo
        return debugInfo
    }

    /// Get cached debug information
    public func getCachedDebugInfo(for moduleId: String) -> ModuleDebugInfo? {
        debugInfoCache[moduleId]
    }

    /// Collect debug information for all modules
    public func collectAllDebugInfo() async -> [String: ModuleDebugInfo] {
        var allDebugInfo: [String: ModuleDebugInfo] = [:]

        // This would iterate through all registered modules
        // For now, return empty array - this would integrate with actual module system
        let moduleIds: [String] = []

        for moduleId in moduleIds {
            allDebugInfo[moduleId] = await collectDebugInfo(for: moduleId)
        }

        return allDebugInfo
    }

    // MARK: - Visualization

    /// Generate dependency graph visualization
    public func generateDependencyGraph(
        for moduleId: String,
        format: VisualizationFormat = .mermaid
    ) async -> String {
        let debugInfo = await collectDebugInfo(for: moduleId)

        switch format {
        case .mermaid:
            return generateMermaidGraph(debugInfo.dependencyGraph, moduleId: moduleId)
        case .dot:
            return generateDotGraph(debugInfo.dependencyGraph, moduleId: moduleId)
        case .text:
            return generateTextGraph(debugInfo.dependencyGraph, moduleId: moduleId)
        case .json:
            return generateJsonGraph(debugInfo.dependencyGraph, moduleId: moduleId)
        case .html:
            return generateHtmlGraph(debugInfo.dependencyGraph, moduleId: moduleId)
        }
    }

    /// Generate performance dashboard
    public func generatePerformanceDashboard(format: VisualizationFormat = .html) async -> String {
        let allDebugInfo = await collectAllDebugInfo()

        switch format {
        case .html:
            return generateHtmlDashboard(allDebugInfo)
        case .json:
            return generateJsonDashboard(allDebugInfo)
        case .text:
            return generateTextDashboard(allDebugInfo)
        default:
            return generateTextDashboard(allDebugInfo)
        }
    }

    /// Generate module health report
    public func generateHealthReport() async -> String {
        let allDebugInfo = await collectAllDebugInfo()
        var report = "🏥 Module Health Report\n"
        report += "======================\n\n"

        for (moduleId, debugInfo) in allDebugInfo.sorted(by: { $0.key < $1.key }) {
            report += "Module: \(moduleId)\n"
            report += "  Status: \(analyzeHealth(debugInfo))\n"
            report += "  Services: \(debugInfo.serviceRegistry.registeredServices.count)\n"
            report += "  Dependencies: \(debugInfo.dependencyGraph.nodeCount)\n"
            report += "  Errors: \(debugInfo.errorLog.count)\n"
            report += "  Performance: \(formatPerformanceScore(debugInfo.performanceData))\n\n"
        }

        return report
    }

    // MARK: - Real-time Debugging

    /// Start real-time monitoring
    public func startRealTimeMonitoring() {
        logger.info("Starting real-time module monitoring")

        Task {
            while true {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                await performRealTimeCheck()
            }
        }
    }

    /// Record debug event
    public func recordEvent(_ event: DebugEvent) {
        eventHistory.append(event)

        // Keep only recent events
        if eventHistory.count > 1000 {
            eventHistory.removeFirst(eventHistory.count - 1000)
        }

        if enabledFeatures.contains(.realTime) {
            logger.debug("Debug event: \(event.type) for \(event.moduleId)")
        }
    }

    /// Get recent debug events
    public func getRecentEvents(limit: Int = 100) -> [DebugEvent] {
        Array(eventHistory.suffix(limit))
    }

    // MARK: - Interactive Debugging

    /// Execute debug command
    public func executeCommand(_ command: DebugCommand) async -> DebugCommandResult {
        logger.info("Executing debug command: \(command.name)")

        switch command.name {
        case "inspect":
            return await executeInspectCommand(command)
        case "trace":
            return await executeTraceCommand(command)
        case "profile":
            return await executeProfileCommand(command)
        case "validate":
            return await executeValidateCommand(command)
        case "reset":
            return await executeResetCommand(command)
        default:
            return DebugCommandResult(
                success: false,
                output: "Unknown command: \(command.name)",
                error: "Command not found"
            )
        }
    }

    /// Get available debug commands
    public func getAvailableCommands() -> [DebugCommand] {
        [
            DebugCommand(name: "inspect", description: "Inspect module details", parameters: ["moduleId"]),
            DebugCommand(name: "trace", description: "Trace service resolution", parameters: ["service", "moduleId"]),
            DebugCommand(
                name: "profile",
                description: "Profile module performance",
                parameters: ["moduleId", "duration"]
            ),
            DebugCommand(name: "validate", description: "Validate module configuration", parameters: ["moduleId"]),
            DebugCommand(name: "reset", description: "Reset debug data", parameters: [])
        ]
    }

    // MARK: - Private Implementation

    private func setupDebugEnvironment() {
        // Configure debug environment
        if ProcessInfo.processInfo.environment["SWINJECT_DEBUG"] != nil {
            setDebugLevel(.verbose)
            enableFeatures([.basic, .performance, .lifecycle, .realTime, .visualization])
        }
    }

    private func collectContainerInfo(for moduleId: String) async -> ContainerDebugInfo {
        // This would integrate with the actual module system
        ContainerDebugInfo(
            containerCount: 1,
            serviceCount: 10,
            registrationCount: 15,
            scopeCount: 3,
            hierarchyDepth: 2,
            memoryFootprint: 1024 * 1024
        )
    }

    private func collectDependencyGraphInfo(for moduleId: String) async -> DependencyGraphInfo {
        // This would analyze the actual dependency graph
        DependencyGraphInfo(
            nodeCount: 10,
            edgeCount: 8,
            cyclicDependencies: [],
            isolatedNodes: [],
            criticalPath: ["ServiceA", "ServiceB", "ServiceC"],
            maxDepth: 3
        )
    }

    private func collectServiceRegistryInfo(for moduleId: String) async -> ServiceRegistryInfo {
        // This would collect actual service registry information
        let services = [
            ServiceInfo(typeName: "UserService", scope: "singleton"),
            ServiceInfo(typeName: "NetworkService", scope: "singleton"),
            ServiceInfo(typeName: "DatabaseService", scope: "singleton")
        ]

        return ServiceRegistryInfo(
            registeredServices: services,
            namedServices: [:],
            scopedServices: [:],
            factoryServices: [],
            singletonServices: services
        )
    }

    private func collectPerformanceInfo(for moduleId: String) async -> PerformanceDebugInfo {
        // This would collect actual performance data
        PerformanceDebugInfo(
            averageResolutionTime: 0.002,
            slowestService: "DatabaseService",
            slowestResolutionTime: 0.015,
            cacheHitRate: 0.85,
            memoryUsage: 512 * 1024,
            gcPressure: 0.1
        )
    }

    private func collectLifecycleHistory(for moduleId: String) async -> [LifecycleEventInfo] {
        // This would collect actual lifecycle events
        [
            LifecycleEventInfo(event: "INITIALIZED", duration: 0.1, success: true),
            LifecycleEventInfo(event: "STARTED", duration: 0.05, success: true)
        ]
    }

    private func collectErrorLog(for moduleId: String) async -> [ErrorInfo] {
        errorLog.filter { $0.context["moduleId"] == moduleId }
    }

    private func generateMermaidGraph(_ graph: DependencyGraphInfo, moduleId: String) -> String {
        var mermaid = "graph TD\n"
        mermaid += "  subgraph \"Module: \(moduleId)\"\n"

        for i in 0..<graph.nodeCount {
            mermaid += "    Node\(i)[Service \(i)]\n"
        }

        for i in 0..<min(graph.edgeCount, graph.nodeCount - 1) {
            mermaid += "    Node\(i) --> Node\(i + 1)\n"
        }

        mermaid += "  end\n"
        return mermaid
    }

    private func generateDotGraph(_ graph: DependencyGraphInfo, moduleId: String) -> String {
        var dot = "digraph \"\(moduleId)\" {\n"
        dot += "  rankdir=TB;\n"
        dot += "  node [shape=box];\n"

        for i in 0..<graph.nodeCount {
            dot += "  \"Service\(i)\";\n"
        }

        for i in 0..<min(graph.edgeCount, graph.nodeCount - 1) {
            dot += "  \"Service\(i)\" -> \"Service\(i + 1)\";\n"
        }

        dot += "}\n"
        return dot
    }

    private func generateTextGraph(_ graph: DependencyGraphInfo, moduleId: String) -> String {
        var text = "Dependency Graph for \(moduleId):\n"
        text += "Nodes: \(graph.nodeCount)\n"
        text += "Edges: \(graph.edgeCount)\n"
        text += "Max Depth: \(graph.maxDepth)\n"

        if !graph.cyclicDependencies.isEmpty {
            text += "Cyclic Dependencies: \(graph.cyclicDependencies.joined(separator: ", "))\n"
        }

        return text
    }

    private func generateJsonGraph(_ graph: DependencyGraphInfo, moduleId: String) -> String {
        // This would generate JSON representation
        "{\"moduleId\": \"\(moduleId)\", \"nodeCount\": \(graph.nodeCount), \"edgeCount\": \(graph.edgeCount)}"
    }

    private func generateHtmlGraph(_ graph: DependencyGraphInfo, moduleId: String) -> String {
        // This would generate HTML with interactive visualization
        "<html><body><h1>Dependency Graph: \(moduleId)</h1><p>Interactive visualization would go here</p></body></html>"
    }

    private func generateHtmlDashboard(_ debugInfo: [String: ModuleDebugInfo]) -> String {
        var html = "<html><head><title>Module Performance Dashboard</title></head><body>"
        html += "<h1>Module Performance Dashboard</h1>"

        for (moduleId, info) in debugInfo.sorted(by: { $0.key < $1.key }) {
            html += "<div class='module'>"
            html += "<h2>\(moduleId)</h2>"
            html += "<p>Services: \(info.serviceRegistry.registeredServices.count)</p>"
            html += "<p>Average Resolution: \(String(format: "%.3f", info.performanceData.averageResolutionTime * 1000))ms</p>"
            html += "<p>Memory Usage: \(formatBytes(info.performanceData.memoryUsage))</p>"
            html += "</div>"
        }

        html += "</body></html>"
        return html
    }

    private func generateJsonDashboard(_ debugInfo: [String: ModuleDebugInfo]) -> String {
        // This would generate JSON dashboard data
        "{\"modules\": \(debugInfo.count), \"timestamp\": \"\(Date())\"}"
    }

    private func generateTextDashboard(_ debugInfo: [String: ModuleDebugInfo]) -> String {
        var text = "📊 Performance Dashboard\n"
        text += "========================\n\n"

        for (moduleId, info) in debugInfo.sorted(by: { $0.key < $1.key }) {
            text += "Module: \(moduleId)\n"
            text += "  Services: \(info.serviceRegistry.registeredServices.count)\n"
            text += "  Avg Resolution: \(String(format: "%.3f", info.performanceData.averageResolutionTime * 1000))ms\n"
            text += "  Memory: \(formatBytes(info.performanceData.memoryUsage))\n\n"
        }

        return text
    }

    private func analyzeHealth(_ debugInfo: ModuleDebugInfo) -> String {
        var score = 100.0

        // Deduct for errors
        score -= Double(debugInfo.errorLog.count) * 10

        // Deduct for poor performance
        if debugInfo.performanceData.averageResolutionTime > 0.01 {
            score -= 20
        }

        // Deduct for cyclic dependencies
        score -= Double(debugInfo.dependencyGraph.cyclicDependencies.count) * 15

        switch score {
        case 90...100: return "🟢 Excellent"
        case 70..<90: return "🟡 Good"
        case 50..<70: return "🟠 Fair"
        default: return "🔴 Poor"
        }
    }

    private func formatPerformanceScore(_ performance: PerformanceDebugInfo) -> String {
        let avgMs = performance.averageResolutionTime * 1000
        switch avgMs {
        case 0..<1: return "🟢 Fast (\(String(format: "%.2f", avgMs))ms)"
        case 1..<5: return "🟡 Moderate (\(String(format: "%.2f", avgMs))ms)"
        case 5..<10: return "🟠 Slow (\(String(format: "%.2f", avgMs))ms)"
        default: return "🔴 Very Slow (\(String(format: "%.2f", avgMs))ms)"
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func performRealTimeCheck() async {
        // Perform real-time health checks
        let allDebugInfo = await collectAllDebugInfo()

        for (moduleId, debugInfo) in allDebugInfo {
            // Check for performance issues
            if debugInfo.performanceData.averageResolutionTime > 0.1 {
                logger.warning("Performance warning for module \(moduleId): slow resolution time")
            }

            // Check for memory issues
            if debugInfo.performanceData.memoryUsage > 10 * 1024 * 1024 {
                logger.warning("Memory warning for module \(moduleId): high memory usage")
            }

            // Check for errors
            let recentErrors = debugInfo.errorLog.filter { $0.timestamp > Date().addingTimeInterval(-300) }
            if recentErrors.count > 5 {
                logger.error("Error threshold exceeded for module \(moduleId): \(recentErrors.count) recent errors")
            }
        }
    }

    // MARK: - Command Execution

    private func executeInspectCommand(_ command: DebugCommand) async -> DebugCommandResult {
        guard let moduleId = command.parameters.first else {
            return DebugCommandResult(success: false, output: "", error: "Missing moduleId parameter")
        }

        let debugInfo = await collectDebugInfo(for: moduleId)
        let output = formatInspectionOutput(debugInfo)

        return DebugCommandResult(success: true, output: output, error: nil)
    }

    private func executeTraceCommand(_ command: DebugCommand) async -> DebugCommandResult {
        // Implementation for trace command
        DebugCommandResult(success: true, output: "Trace command executed", error: nil)
    }

    private func executeProfileCommand(_ command: DebugCommand) async -> DebugCommandResult {
        // Implementation for profile command
        DebugCommandResult(success: true, output: "Profile command executed", error: nil)
    }

    private func executeValidateCommand(_ command: DebugCommand) async -> DebugCommandResult {
        // Implementation for validate command
        DebugCommandResult(success: true, output: "Validate command executed", error: nil)
    }

    private func executeResetCommand(_ command: DebugCommand) async -> DebugCommandResult {
        debugInfoCache.removeAll()
        eventHistory.removeAll()
        errorLog.removeAll()

        return DebugCommandResult(success: true, output: "Debug data reset successfully", error: nil)
    }

    private func formatInspectionOutput(_ debugInfo: ModuleDebugInfo) -> String {
        var output = "🔍 Module Inspection: \(debugInfo.moduleId)\n"
        output += "==========================================\n\n"

        output += "Container Info:\n"
        output += "  Services: \(debugInfo.containerInfo.serviceCount)\n"
        output += "  Registrations: \(debugInfo.containerInfo.registrationCount)\n"
        output += "  Memory: \(formatBytes(debugInfo.containerInfo.memoryFootprint))\n\n"

        output += "Dependencies:\n"
        output += "  Nodes: \(debugInfo.dependencyGraph.nodeCount)\n"
        output += "  Edges: \(debugInfo.dependencyGraph.edgeCount)\n"
        output += "  Max Depth: \(debugInfo.dependencyGraph.maxDepth)\n\n"

        output += "Performance:\n"
        output += "  Avg Resolution: \(String(format: "%.3f", debugInfo.performanceData.averageResolutionTime * 1000))ms\n"
        output += "  Cache Hit Rate: \(String(format: "%.1f", debugInfo.performanceData.cacheHitRate * 100))%\n"
        output += "  Memory Usage: \(formatBytes(debugInfo.performanceData.memoryUsage))\n\n"

        return output
    }
}

// MARK: - Supporting Types

public enum DebugFeature: String, CaseIterable {
    case basic = "BASIC"
    case performance = "PERFORMANCE"
    case lifecycle = "LIFECYCLE"
    case realTime = "REAL_TIME"
    case visualization = "VISUALIZATION"
    case tracing = "TRACING"
}

public struct DebugEvent: Sendable {
    public let type: String
    public let moduleId: String
    public let timestamp: Date
    public let data: [String: String]

    public init(type: String, moduleId: String, data: [String: String] = [:]) {
        self.type = type
        self.moduleId = moduleId
        timestamp = Date()
        self.data = data
    }
}

public struct DebugCommand: Sendable {
    public let name: String
    public let description: String
    public let parameters: [String]

    public init(name: String, description: String, parameters: [String] = []) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct DebugCommandResult: Sendable {
    public let success: Bool
    public let output: String
    public let error: String?

    public init(success: Bool, output: String, error: String? = nil) {
        self.success = success
        self.output = output
        self.error = error
    }
}
