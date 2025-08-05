// ModuleDebugToolsMonitoringTests.swift - Tests for ModuleDebugTools monitoring lifecycle
// Copyright © 2025 SwinjectMacros. All rights reserved.

@testable import SwinjectMacros
import XCTest

final class ModuleDebugToolsMonitoringTests: XCTestCase {

    func testMonitoringLifecycle() async throws {
        let debugTools = ModuleDebugTools.shared

        // Initially, monitoring should not be active
        let initialState = await debugTools.isMonitoringActive
        XCTAssertFalse(initialState, "Monitoring should not be active initially")

        // Start monitoring
        await debugTools.startRealTimeMonitoring()

        // Give it a moment to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Check if monitoring is active
        let activeState = await debugTools.isMonitoringActive
        XCTAssertTrue(activeState, "Monitoring should be active after starting")

        // Stop monitoring
        await debugTools.stopRealTimeMonitoring()

        // Give it a moment to stop
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Check if monitoring has stopped
        let stoppedState = await debugTools.isMonitoringActive
        XCTAssertFalse(stoppedState, "Monitoring should not be active after stopping")
    }

    func testMultipleStartCalls() async throws {
        let debugTools = ModuleDebugTools.shared

        // Start monitoring multiple times
        await debugTools.startRealTimeMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        await debugTools.startRealTimeMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Should still have only one active monitoring task
        let activeState = await debugTools.isMonitoringActive
        XCTAssertTrue(activeState, "Monitoring should be active")

        // Stop once should stop all monitoring
        await debugTools.stopRealTimeMonitoring()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let stoppedState = await debugTools.isMonitoringActive
        XCTAssertFalse(stoppedState, "Monitoring should be stopped")
    }

    func testMonitoringStopsOnCancel() async throws {
        let debugTools = ModuleDebugTools.shared

        // Start monitoring
        await debugTools.startRealTimeMonitoring()

        // Create a task that will be cancelled
        let testTask = Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await debugTools.stopRealTimeMonitoring()
        }

        // Cancel the task immediately
        testTask.cancel()

        // The monitoring should still be running
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        let activeState = await debugTools.isMonitoringActive
        XCTAssertTrue(activeState, "Monitoring should still be active")

        // Clean up
        await debugTools.stopRealTimeMonitoring()
    }
}
