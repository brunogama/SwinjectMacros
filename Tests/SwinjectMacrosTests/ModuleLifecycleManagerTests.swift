// ModuleLifecycleManagerTests.swift - Tests for advanced lifecycle management
// Copyright © 2025 SwinjectMacros. All rights reserved.

@testable import SwinjectMacros
import XCTest

final class ModuleLifecycleManagerTests: XCTestCase {

    var lifecycleManager: ModuleLifecycleManager!
    fileprivate var testHook: TestLifecycleHook!

    override func setUp() async throws {
        try await super.setUp()
        lifecycleManager = ModuleLifecycleManager.shared
        testHook = TestLifecycleHook()
        await lifecycleManager.registerHook(testHook)
    }

    override func tearDown() async throws {
        testHook = nil
        try await super.tearDown()
    }

    // MARK: - Lifecycle State Tests

    func testModuleInitialization() async throws {
        let moduleId = "TestModule"

        let result = await lifecycleManager.initializeModule(moduleId)

        switch result {
        case .success:
            let info = await lifecycleManager.getLifecycleInfo(for: moduleId)
            XCTAssertEqual(info?.currentState, .initialized)
            XCTAssertNotNil(info?.initializationTime)

        case .failure(let error):
            XCTFail("Module initialization failed: \(error)")

        case .blocked(let reason):
            XCTFail("Module initialization blocked: \(reason)")

        case .timeout:
            XCTFail("Module initialization timed out")
        }
    }

    func testModuleStartup() async throws {
        let moduleId = "TestModule"

        // Initialize first
        let initResult = await lifecycleManager.initializeModule(moduleId)
        XCTAssertEqual(initResult, .success)

        // Then start
        let startResult = await lifecycleManager.startModule(moduleId)

        switch startResult {
        case .success:
            let info = await lifecycleManager.getLifecycleInfo(for: moduleId)
            XCTAssertEqual(info?.currentState, .active)

        case .failure(let error):
            XCTFail("Module startup failed: \(error)")

        case .blocked(let reason):
            XCTFail("Module startup blocked: \(reason)")

        case .timeout:
            XCTFail("Module startup timed out")
        }
    }

    func testModulePauseResume() async throws {
        let moduleId = "TestModule"

        // Initialize and start
        _ = await lifecycleManager.initializeModule(moduleId)
        _ = await lifecycleManager.startModule(moduleId)

        // Pause
        let pauseResult = await lifecycleManager.pauseModule(moduleId)
        XCTAssertEqual(pauseResult, .success)

        let pausedInfo = await lifecycleManager.getLifecycleInfo(for: moduleId)
        XCTAssertEqual(pausedInfo?.currentState, .paused)

        // Resume
        let resumeResult = await lifecycleManager.resumeModule(moduleId)
        XCTAssertEqual(resumeResult, .success)

        let resumedInfo = await lifecycleManager.getLifecycleInfo(for: moduleId)
        XCTAssertEqual(resumedInfo?.currentState, .active)
    }

    func testModuleStop() async throws {
        let moduleId = "TestModule"

        // Initialize and start
        _ = await lifecycleManager.initializeModule(moduleId)
        _ = await lifecycleManager.startModule(moduleId)

        // Stop
        let stopResult = await lifecycleManager.stopModule(moduleId)
        XCTAssertEqual(stopResult, .success)

        let info = await lifecycleManager.getLifecycleInfo(for: moduleId)
        XCTAssertEqual(info?.currentState, .stopped)
    }

    func testModuleDestroy() async throws {
        let moduleId = "TestModule"

        // Initialize, start, and stop
        _ = await lifecycleManager.initializeModule(moduleId)
        _ = await lifecycleManager.startModule(moduleId)
        _ = await lifecycleManager.stopModule(moduleId)

        // Destroy
        let destroyResult = await lifecycleManager.destroyModule(moduleId)
        XCTAssertEqual(destroyResult, .success)

        let info = await lifecycleManager.getLifecycleInfo(for: moduleId)
        XCTAssertNil(info) // Should be cleaned up
    }

    func testInvalidStateTransition() async throws {
        let moduleId = "TestModule"

        // Try to start without initializing
        let startResult = await lifecycleManager.startModule(moduleId)

        switch startResult {
        case .blocked(let reason):
            XCTAssertTrue(reason.contains("Invalid state transition"))
        default:
            XCTFail("Expected blocked result for invalid transition")
        }
    }

    // MARK: - Lifecycle Hook Tests

    func testLifecycleHooks() async throws {
        let moduleId = "TestModule"

        _ = await lifecycleManager.initializeModule(moduleId)

        // Check that hooks were called
        XCTAssertTrue(testHook.events.contains { $0.event == .willInitialize && $0.module == moduleId })
        XCTAssertTrue(testHook.events.contains { $0.event == .didInitialize && $0.module == moduleId })
    }

    // MARK: - Metrics Tests

    func testUptimeTracking() async throws {
        let moduleId = "TestModule"

        _ = await lifecycleManager.initializeModule(moduleId)
        _ = await lifecycleManager.startModule(moduleId)

        // Wait a bit to accumulate uptime
        try await Task.sleep(for: .milliseconds(100))

        let info = await lifecycleManager.getLifecycleInfo(for: moduleId)
        XCTAssertNotNil(info)
        XCTAssertGreaterThan(info!.totalUptime, 0)
    }

    func testFailureTracking() async throws {
        let moduleId = "TestModule"

        await lifecycleManager.markModuleFailed(moduleId, error: LifecycleTestError.simulatedFailure)

        let info = await lifecycleManager.getLifecycleInfo(for: moduleId)
        XCTAssertEqual(info?.currentState, .failed)
        XCTAssertEqual(info?.failureCount, 1)
    }

    func testModuleQuery() async throws {
        let moduleId1 = "TestModule1"
        let moduleId2 = "TestModule2"

        _ = await lifecycleManager.initializeModule(moduleId1)
        _ = await lifecycleManager.startModule(moduleId1)

        _ = await lifecycleManager.initializeModule(moduleId2)

        let activeModules = await lifecycleManager.getModules(in: .active)
        let initializedModules = await lifecycleManager.getModules(in: .initialized)

        XCTAssertTrue(activeModules.contains(moduleId1))
        XCTAssertTrue(initializedModules.contains(moduleId2))
    }

    func testCanTransition() async throws {
        let moduleId = "TestModule"

        _ = await lifecycleManager.initializeModule(moduleId)

        let canStart = await lifecycleManager.canTransition(moduleId: moduleId, to: .starting)
        let canDestroy = await lifecycleManager.canTransition(moduleId: moduleId, to: .destroyed)

        XCTAssertTrue(canStart)
        XCTAssertFalse(canDestroy) // Can't destroy from initialized state
    }

    // MARK: - Built-in Hook Tests

    func testLoggingHook() async throws {
        let loggingHook = LoggingLifecycleHook()
        await lifecycleManager.registerHook(loggingHook)

        let moduleId = "TestModule"
        _ = await lifecycleManager.initializeModule(moduleId)

        // Should not throw or crash
        // Actual log verification would require more complex setup
    }

    func testPerformanceHook() async throws {
        let performanceHook = PerformanceLifecycleHook()
        await lifecycleManager.registerHook(performanceHook)

        let moduleId = "TestModule"
        _ = await lifecycleManager.initializeModule(moduleId)
        _ = await lifecycleManager.startModule(moduleId)

        // Should not throw or crash
        // Performance data would be logged internally
    }
}

// MARK: - Test Helpers

fileprivate class TestLifecycleHook: ModuleLifecycleHook {
    private(set) var events: [(event: ModuleLifecycleEvent, module: String)] = []

    func onLifecycleEvent(_ event: ModuleLifecycleEvent, module: String) async throws {
        events.append((event: event, module: module))
    }
}

enum LifecycleTestError: Error {
    case simulatedFailure
}

// MARK: - LifecycleTransitionResult Equatable

extension LifecycleTransitionResult: Equatable {
    public static func == (lhs: LifecycleTransitionResult, rhs: LifecycleTransitionResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            true
        case (.timeout, .timeout):
            true
        case (.blocked(let reason1), .blocked(let reason2)):
            reason1 == reason2
        case (.failure(_), .failure(_)):
            true // Simplified for testing
        default:
            false
        }
    }
}
