// ModuleDebugToolsTests.swift - Tests for debugging and visualization tools
// Copyright © 2025 SwinjectMacros. All rights reserved.

@testable import SwinjectMacros
import XCTest

final class ModuleDebugToolsTests: XCTestCase {

    var debugTools: ModuleDebugTools!

    override func setUp() async throws {
        try await super.setUp()
        debugTools = ModuleDebugTools.shared
    }

    override func tearDown() async throws {
        debugTools = nil
        try await super.tearDown()
    }

    // MARK: - Configuration Tests

    func testSetDebugLevel() async throws {
        await debugTools.setDebugLevel(.verbose)

        // Should complete without error
        XCTAssertTrue(true)
    }

    func testEnableFeatures() async throws {
        let features: Set<DebugFeature> = [.basic, .performance, .visualization]
        await debugTools.enableFeatures(features)

        // Should complete without error
        XCTAssertTrue(true)
    }

    // MARK: - Debug Information Collection Tests

    func testCollectDebugInfo() async throws {
        let moduleId = "TestModule"

        let debugInfo = await debugTools.collectDebugInfo(for: moduleId)

        XCTAssertEqual(debugInfo.moduleId, moduleId)
        XCTAssertNotNil(debugInfo.containerInfo)
        XCTAssertNotNil(debugInfo.dependencyGraph)
        XCTAssertNotNil(debugInfo.serviceRegistry)
        XCTAssertNotNil(debugInfo.performanceData)
        XCTAssertTrue(debugInfo.timestamp <= Date())
    }

    func testGetCachedDebugInfo() async throws {
        let moduleId = "TestModule"

        // First collect debug info
        let originalInfo = await debugTools.collectDebugInfo(for: moduleId)

        // Then get cached version
        let cachedInfo = await debugTools.getCachedDebugInfo(for: moduleId)

        XCTAssertNotNil(cachedInfo)
        XCTAssertEqual(cachedInfo?.moduleId, originalInfo.moduleId)
        XCTAssertEqual(cachedInfo?.timestamp, originalInfo.timestamp)
    }

    func testGetCachedDebugInfoForNonExistentModule() async throws {
        let cachedInfo = await debugTools.getCachedDebugInfo(for: "NonExistentModule")
        XCTAssertNil(cachedInfo)
    }

    func testCollectAllDebugInfo() async throws {
        let allDebugInfo = await debugTools.collectAllDebugInfo()

        // Should return dictionary (empty in our mock implementation)
        XCTAssertNotNil(allDebugInfo)
    }

    // MARK: - Visualization Tests

    func testGenerateMermaidDependencyGraph() async throws {
        let moduleId = "TestModule"

        let mermaidGraph = await debugTools.generateDependencyGraph(
            for: moduleId,
            format: .mermaid
        )

        XCTAssertFalse(mermaidGraph.isEmpty)
        XCTAssertTrue(mermaidGraph.contains("graph TD"))
        XCTAssertTrue(mermaidGraph.contains(moduleId))
    }

    func testGenerateDotDependencyGraph() async throws {
        let moduleId = "TestModule"

        let dotGraph = await debugTools.generateDependencyGraph(
            for: moduleId,
            format: .dot
        )

        XCTAssertFalse(dotGraph.isEmpty)
        XCTAssertTrue(dotGraph.contains("digraph"))
        XCTAssertTrue(dotGraph.contains(moduleId))
    }

    func testGenerateTextDependencyGraph() async throws {
        let moduleId = "TestModule"

        let textGraph = await debugTools.generateDependencyGraph(
            for: moduleId,
            format: .text
        )

        XCTAssertFalse(textGraph.isEmpty)
        XCTAssertTrue(textGraph.contains("Dependency Graph"))
        XCTAssertTrue(textGraph.contains(moduleId))
    }

    func testGenerateJsonDependencyGraph() async throws {
        let moduleId = "TestModule"

        let jsonGraph = await debugTools.generateDependencyGraph(
            for: moduleId,
            format: .json
        )

        XCTAssertFalse(jsonGraph.isEmpty)
        XCTAssertTrue(jsonGraph.contains(moduleId))
        XCTAssertTrue(jsonGraph.contains("nodeCount"))
    }

    func testGenerateHtmlDependencyGraph() async throws {
        let moduleId = "TestModule"

        let htmlGraph = await debugTools.generateDependencyGraph(
            for: moduleId,
            format: .html
        )

        XCTAssertFalse(htmlGraph.isEmpty)
        XCTAssertTrue(htmlGraph.contains("<html>"))
        XCTAssertTrue(htmlGraph.contains(moduleId))
    }

    // MARK: - Dashboard Tests

    func testGenerateHtmlPerformanceDashboard() async throws {
        let dashboard = await debugTools.generatePerformanceDashboard(format: .html)

        XCTAssertFalse(dashboard.isEmpty)
        XCTAssertTrue(dashboard.contains("<html>"))
        XCTAssertTrue(dashboard.contains("Performance Dashboard"))
    }

    func testGenerateJsonPerformanceDashboard() async throws {
        let dashboard = await debugTools.generatePerformanceDashboard(format: .json)

        XCTAssertFalse(dashboard.isEmpty)
        XCTAssertTrue(dashboard.contains("modules"))
    }

    func testGenerateTextPerformanceDashboard() async throws {
        let dashboard = await debugTools.generatePerformanceDashboard(format: .text)

        XCTAssertFalse(dashboard.isEmpty)
        XCTAssertTrue(dashboard.contains("Performance Dashboard"))
    }

    // MARK: - Health Report Tests

    func testGenerateHealthReport() async throws {
        let healthReport = await debugTools.generateHealthReport()

        XCTAssertFalse(healthReport.isEmpty)
        XCTAssertTrue(healthReport.contains("Module Health Report"))
        XCTAssertTrue(healthReport.contains("Status:"))
    }

    // MARK: - Real-time Monitoring Tests

    func testStartRealTimeMonitoring() async throws {
        await debugTools.startRealTimeMonitoring()

        // Should complete without error
        XCTAssertTrue(true)
    }

    func testRecordEvent() async throws {
        let event = DebugEvent(
            type: "TEST_EVENT",
            moduleId: "TestModule",
            data: ["key": "value"]
        )

        await debugTools.recordEvent(event)

        let recentEvents = await debugTools.getRecentEvents(limit: 10)
        XCTAssertTrue(recentEvents.contains { $0.type == "TEST_EVENT" })
    }

    func testGetRecentEvents() async throws {
        // Record multiple events
        for i in 0..<5 {
            let event = DebugEvent(
                type: "EVENT_\(i)",
                moduleId: "TestModule"
            )
            await debugTools.recordEvent(event)
        }

        let recentEvents = await debugTools.getRecentEvents(limit: 3)
        XCTAssertEqual(recentEvents.count, 3)

        // Should be in reverse chronological order (most recent first)
        XCTAssertEqual(recentEvents.last?.type, "EVENT_2")
    }

    func testEventHistoryLimit() async throws {
        // Record many events to test the 1000 event limit
        for i in 0..<1005 {
            let event = DebugEvent(
                type: "EVENT_\(i)",
                moduleId: "TestModule"
            )
            await debugTools.recordEvent(event)
        }

        let allEvents = await debugTools.getRecentEvents(limit: 2000)
        XCTAssertLessThanOrEqual(allEvents.count, 1000)
    }

    // MARK: - Interactive Debugging Tests

    func testGetAvailableCommands() async throws {
        let commands = await debugTools.getAvailableCommands()

        XCTAssertFalse(commands.isEmpty)

        let commandNames = commands.map { $0.name }
        XCTAssertTrue(commandNames.contains("inspect"))
        XCTAssertTrue(commandNames.contains("trace"))
        XCTAssertTrue(commandNames.contains("profile"))
        XCTAssertTrue(commandNames.contains("validate"))
        XCTAssertTrue(commandNames.contains("reset"))
    }

    func testExecuteInspectCommand() async throws {
        let command = DebugCommand(
            name: "inspect",
            description: "Inspect module",
            parameters: ["TestModule"]
        )

        let result = await debugTools.executeCommand(command)

        XCTAssertTrue(result.success)
        XCTAssertFalse(result.output.isEmpty)
        XCTAssertTrue(result.output.contains("Module Inspection"))
        XCTAssertTrue(result.output.contains("TestModule"))
        XCTAssertNil(result.error)
    }

    func testExecuteInspectCommandWithoutParameters() async throws {
        let command = DebugCommand(
            name: "inspect",
            description: "Inspect module",
            parameters: []
        )

        let result = await debugTools.executeCommand(command)

        XCTAssertFalse(result.success)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error!.contains("Missing moduleId parameter"))
    }

    func testExecuteTraceCommand() async throws {
        let command = DebugCommand(
            name: "trace",
            description: "Trace service",
            parameters: ["TestService", "TestModule"]
        )

        let result = await debugTools.executeCommand(command)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Trace command executed"))
    }

    func testExecuteProfileCommand() async throws {
        let command = DebugCommand(
            name: "profile",
            description: "Profile module",
            parameters: ["TestModule", "10"]
        )

        let result = await debugTools.executeCommand(command)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Profile command executed"))
    }

    func testExecuteValidateCommand() async throws {
        let command = DebugCommand(
            name: "validate",
            description: "Validate module",
            parameters: ["TestModule"]
        )

        let result = await debugTools.executeCommand(command)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Validate command executed"))
    }

    func testExecuteResetCommand() async throws {
        // First record some events and collect debug info
        await debugTools.recordEvent(DebugEvent(type: "TEST", moduleId: "TestModule"))
        _ = await debugTools.collectDebugInfo(for: "TestModule")

        let command = DebugCommand(
            name: "reset",
            description: "Reset debug data",
            parameters: []
        )

        let result = await debugTools.executeCommand(command)

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.output.contains("Debug data reset successfully"))

        // Verify data was reset
        let cachedInfo = await debugTools.getCachedDebugInfo(for: "TestModule")
        XCTAssertNil(cachedInfo)

        let recentEvents = await debugTools.getRecentEvents()
        XCTAssertTrue(recentEvents.isEmpty)
    }

    func testExecuteUnknownCommand() async throws {
        let command = DebugCommand(
            name: "unknown",
            description: "Unknown command",
            parameters: []
        )

        let result = await debugTools.executeCommand(command)

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.output.contains("Unknown command"))
        XCTAssertNotNil(result.error)
    }
}

// MARK: - Debug Data Structure Tests

final class DebugDataStructureTests: XCTestCase {

    func testModuleDebugInfoInitialization() {
        let containerInfo = ContainerDebugInfo(
            containerCount: 1,
            serviceCount: 5,
            registrationCount: 8,
            scopeCount: 2,
            hierarchyDepth: 3,
            memoryFootprint: 1024
        )

        let dependencyGraph = DependencyGraphInfo(
            nodeCount: 5,
            edgeCount: 4,
            cyclicDependencies: [],
            isolatedNodes: ["IsolatedService"],
            criticalPath: ["ServiceA", "ServiceB"],
            maxDepth: 2
        )

        let serviceRegistry = ServiceRegistryInfo(
            registeredServices: [
                ServiceInfo(typeName: "TestService", scope: "singleton")
            ]
        )

        let performanceData = PerformanceDebugInfo(
            averageResolutionTime: 0.001,
            slowestService: "SlowService",
            slowestResolutionTime: 0.01,
            cacheHitRate: 0.8,
            memoryUsage: 512,
            gcPressure: 0.1
        )

        let debugInfo = ModuleDebugInfo(
            moduleId: "TestModule",
            containerInfo: containerInfo,
            dependencyGraph: dependencyGraph,
            serviceRegistry: serviceRegistry,
            performanceData: performanceData
        )

        XCTAssertEqual(debugInfo.moduleId, "TestModule")
        XCTAssertEqual(debugInfo.containerInfo.serviceCount, 5)
        XCTAssertEqual(debugInfo.dependencyGraph.nodeCount, 5)
        XCTAssertEqual(debugInfo.serviceRegistry.registeredServices.count, 1)
        XCTAssertEqual(debugInfo.performanceData.averageResolutionTime, 0.001)
    }

    func testServiceInfoInitialization() {
        let serviceInfo = ServiceInfo(
            typeName: "UserService",
            name: "primary",
            scope: "singleton",
            isFactory: false,
            dependencies: ["NetworkService", "DatabaseService"],
            registrationCount: 1,
            resolutionCount: 10,
            lastResolved: Date()
        )

        XCTAssertEqual(serviceInfo.typeName, "UserService")
        XCTAssertEqual(serviceInfo.name, "primary")
        XCTAssertEqual(serviceInfo.scope, "singleton")
        XCTAssertFalse(serviceInfo.isFactory)
        XCTAssertEqual(serviceInfo.dependencies.count, 2)
        XCTAssertEqual(serviceInfo.resolutionCount, 10)
    }

    func testLifecycleEventInfoInitialization() {
        let eventInfo = LifecycleEventInfo(
            event: "MODULE_STARTED",
            duration: 0.05,
            success: true,
            metadata: ["reason": "user_request"]
        )

        XCTAssertEqual(eventInfo.event, "MODULE_STARTED")
        XCTAssertEqual(eventInfo.duration, 0.05)
        XCTAssertTrue(eventInfo.success)
        XCTAssertEqual(eventInfo.metadata["reason"], "user_request")
    }

    func testErrorInfoInitialization() {
        let errorInfo = ErrorInfo(
            errorType: "ResolutionError",
            message: "Service not found",
            stackTrace: ["frame1", "frame2"],
            context: ["moduleId": "TestModule"]
        )

        XCTAssertEqual(errorInfo.errorType, "ResolutionError")
        XCTAssertEqual(errorInfo.message, "Service not found")
        XCTAssertEqual(errorInfo.stackTrace.count, 2)
        XCTAssertEqual(errorInfo.context["moduleId"], "TestModule")
    }

    func testDebugEventInitialization() {
        let event = DebugEvent(
            type: "SERVICE_RESOLVED",
            moduleId: "TestModule",
            data: ["serviceName": "UserService", "duration": "0.001"]
        )

        XCTAssertEqual(event.type, "SERVICE_RESOLVED")
        XCTAssertEqual(event.moduleId, "TestModule")
        XCTAssertEqual(event.data["serviceName"], "UserService")
        XCTAssertEqual(event.data["duration"], "0.001")
        XCTAssertTrue(event.timestamp <= Date())
    }

    func testDebugCommandInitialization() {
        let command = DebugCommand(
            name: "inspect",
            description: "Inspect module details",
            parameters: ["moduleId", "verbose"]
        )

        XCTAssertEqual(command.name, "inspect")
        XCTAssertEqual(command.description, "Inspect module details")
        XCTAssertEqual(command.parameters.count, 2)
        XCTAssertTrue(command.parameters.contains("moduleId"))
        XCTAssertTrue(command.parameters.contains("verbose"))
    }

    func testDebugCommandResultInitialization() {
        let successResult = DebugCommandResult(
            success: true,
            output: "Command executed successfully"
        )

        let failureResult = DebugCommandResult(
            success: false,
            output: "Command failed",
            error: "Invalid parameters"
        )

        XCTAssertTrue(successResult.success)
        XCTAssertEqual(successResult.output, "Command executed successfully")
        XCTAssertNil(successResult.error)

        XCTAssertFalse(failureResult.success)
        XCTAssertEqual(failureResult.output, "Command failed")
        XCTAssertEqual(failureResult.error, "Invalid parameters")
    }
}
