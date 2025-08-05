// ModuleHotSwapTests.swift - Tests for hot-swap module functionality
// Copyright © 2025 SwinjectMacros. All rights reserved.

@testable import SwinjectMacros
import XCTest

final class ModuleHotSwapTests: XCTestCase {

    var hotSwapManager: ModuleHotSwapManager!
    fileprivate var testModule: TestHotSwappableModule!
    fileprivate var testListener: TestHotSwapListener!

    override func setUp() async throws {
        try await super.setUp()
        hotSwapManager = ModuleHotSwapManager.shared
        testModule = TestHotSwappableModule()
        testListener = TestHotSwapListener()

        try await hotSwapManager.registerModule(testModule)
        await hotSwapManager.registerEventListener(testListener)
    }

    override func tearDown() async throws {
        await hotSwapManager.unregisterModule(testModule.version.identifier)
        testModule = nil
        testListener = nil
        try await super.tearDown()
    }

    // MARK: - Registration Tests

    func testModuleRegistration() async throws {
        let moduleId = testModule.version.identifier

        let isSupported = await hotSwapManager.supportsHotSwap(moduleId: moduleId)
        XCTAssertTrue(isSupported)

        let currentVersion = await hotSwapManager.getCurrentVersion(for: moduleId)
        XCTAssertEqual(currentVersion?.identifier, moduleId)
        XCTAssertEqual(currentVersion?.version, "1.0.0")
    }

    func testModuleUnregistration() async throws {
        let moduleId = testModule.version.identifier

        await hotSwapManager.unregisterModule(moduleId)

        let isSupported = await hotSwapManager.supportsHotSwap(moduleId: moduleId)
        XCTAssertFalse(isSupported)
    }

    func testInvalidModuleRegistration() async throws {
        let invalidModule = TestHotSwappableModule(identifier: "")

        do {
            try await hotSwapManager.registerModule(invalidModule)
            XCTFail("Should have thrown error for invalid module")
        } catch HotSwapError.invalidModule(let reason) {
            XCTAssertTrue(reason.contains("identifier cannot be empty"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Hot-Swap Operation Tests

    func testSuccessfulHotSwap() async throws {
        let moduleId = testModule.version.identifier
        let targetVersion = ModuleVersion(
            identifier: moduleId,
            version: "2.0.0",
            buildNumber: "200",
            checksum: "def456",
            compatibilityVersion: "2.0"
        )

        let result = await hotSwapManager.performHotSwap(
            moduleId: moduleId,
            targetVersion: targetVersion,
            initiatedBy: "test"
        )

        switch result {
        case .success(let swappedModuleId, let operation):
            XCTAssertEqual(swappedModuleId, moduleId)
            XCTAssertEqual(operation, .replace)

            let currentVersion = await hotSwapManager.getCurrentVersion(for: moduleId)
            XCTAssertEqual(currentVersion?.version, "2.0.0")

        default:
            XCTFail("Hot-swap should have succeeded: \(result)")
        }
    }

    func testDryRunValidation() async throws {
        let moduleId = testModule.version.identifier
        let targetVersion = ModuleVersion(
            identifier: moduleId,
            version: "2.0.0",
            buildNumber: "200",
            checksum: "def456",
            compatibilityVersion: "2.0"
        )

        let result = await hotSwapManager.performHotSwap(
            moduleId: moduleId,
            targetVersion: targetVersion,
            initiatedBy: "test",
            dryRun: true
        )

        switch result {
        case .success(let swappedModuleId, let operation):
            XCTAssertEqual(swappedModuleId, moduleId)
            XCTAssertEqual(operation, .validate)

            // Version should not have changed
            let currentVersion = await hotSwapManager.getCurrentVersion(for: moduleId)
            XCTAssertEqual(currentVersion?.version, "1.0.0")

        default:
            XCTFail("Dry run validation should have succeeded: \(result)")
        }
    }

    func testIncompatibleVersionSwap() async throws {
        let moduleId = testModule.version.identifier
        let incompatibleVersion = ModuleVersion(
            identifier: moduleId,
            version: "3.0.0",
            buildNumber: "300",
            checksum: "ghi789",
            compatibilityVersion: "3.0" // Incompatible
        )

        // Configure test module to reject this version
        testModule.shouldRejectVersion = true

        let result = await hotSwapManager.performHotSwap(
            moduleId: moduleId,
            targetVersion: incompatibleVersion,
            initiatedBy: "test"
        )

        switch result {
        case .validationFailed(let validationResult):
            switch validationResult {
            case .incompatible(let reason):
                XCTAssertTrue(reason.contains("Incompatible"))
            default:
                XCTFail("Expected incompatible validation result")
            }
        default:
            XCTFail("Expected validation failure: \(result)")
        }
    }

    func testModuleNotFound() async throws {
        let nonExistentModuleId = "NonExistentModule"
        let targetVersion = ModuleVersion(
            identifier: nonExistentModuleId,
            version: "1.0.0",
            buildNumber: "100",
            checksum: "abc123",
            compatibilityVersion: "1.0"
        )

        let result = await hotSwapManager.performHotSwap(
            moduleId: nonExistentModuleId,
            targetVersion: targetVersion,
            initiatedBy: "test"
        )

        switch result {
        case .failure(let error):
            if case HotSwapError.moduleNotFound(let moduleId) = error {
                XCTAssertEqual(moduleId, nonExistentModuleId)
            } else {
                XCTFail("Expected moduleNotFound error")
            }
        default:
            XCTFail("Expected failure result: \(result)")
        }
    }

    // MARK: - Rollback Tests

    func testRollback() async throws {
        let moduleId = testModule.version.identifier
        let originalVersion = testModule.version.version

        let targetVersion = ModuleVersion(
            identifier: moduleId,
            version: "2.0.0",
            buildNumber: "200",
            checksum: "def456",
            compatibilityVersion: "2.0"
        )

        // Perform hot-swap
        let swapResult = await hotSwapManager.performHotSwap(
            moduleId: moduleId,
            targetVersion: targetVersion,
            initiatedBy: "test"
        )

        guard case .success = swapResult else {
            XCTFail("Initial hot-swap failed")
            return
        }

        // Get available rollback points
        let rollbackPoints = await hotSwapManager.getAvailableRollbackPoints(for: moduleId)
        XCTAssertFalse(rollbackPoints.isEmpty)

        let rollbackPointId = rollbackPoints.first!

        // Perform rollback
        let rollbackResult = await hotSwapManager.rollback(
            moduleId: moduleId,
            rollbackPointId: rollbackPointId
        )

        switch rollbackResult {
        case .success(let rolledBackModuleId, let operation):
            XCTAssertEqual(rolledBackModuleId, moduleId)
            XCTAssertEqual(operation, .rollback)

            // Version should be restored (in a real implementation)
            XCTAssertTrue(testModule.wasRestoredFromSnapshot)

        default:
            XCTFail("Rollback should have succeeded: \(rollbackResult)")
        }
    }

    func testRollbackPointNotFound() async throws {
        let moduleId = testModule.version.identifier
        let nonExistentRollbackPoint = "invalid_rollback_point"

        let result = await hotSwapManager.rollback(
            moduleId: moduleId,
            rollbackPointId: nonExistentRollbackPoint
        )

        switch result {
        case .failure(let error):
            if case HotSwapError.rollbackPointNotFound(let pointId) = error {
                XCTAssertEqual(pointId, nonExistentRollbackPoint)
            } else {
                XCTFail("Expected rollbackPointNotFound error")
            }
        default:
            XCTFail("Expected failure result: \(result)")
        }
    }

    // MARK: - Event Listener Tests

    func testEventNotification() async throws {
        let moduleId = testModule.version.identifier
        let targetVersion = ModuleVersion(
            identifier: moduleId,
            version: "2.0.0",
            buildNumber: "200",
            checksum: "def456",
            compatibilityVersion: "2.0"
        )

        _ = await hotSwapManager.performHotSwap(
            moduleId: moduleId,
            targetVersion: targetVersion,
            initiatedBy: "test"
        )

        // Check that events were received
        XCTAssertFalse(testListener.events.isEmpty)

        let eventPhases = testListener.events.map { $0.phase }
        XCTAssertTrue(eventPhases.contains(.validating))
        XCTAssertTrue(eventPhases.contains(.preparing))
        XCTAssertTrue(eventPhases.contains(.snapshotting))
        XCTAssertTrue(eventPhases.contains(.swapping))
        XCTAssertTrue(eventPhases.contains(.completing))
    }

    // MARK: - Query Tests

    func testGetRegisteredModules() async throws {
        let registeredModules = await hotSwapManager.getRegisteredModules()

        let moduleId = testModule.version.identifier
        XCTAssertTrue(registeredModules.keys.contains(moduleId))
        XCTAssertEqual(registeredModules[moduleId]?.version, "1.0.0")
    }

    func testGetActiveOperations() async throws {
        // Start a hot-swap operation but don't await it
        let moduleId = testModule.version.identifier
        let targetVersion = ModuleVersion(
            identifier: moduleId,
            version: "2.0.0",
            buildNumber: "200",
            checksum: "def456",
            compatibilityVersion: "2.0"
        )

        // Use a slow module to create a window where operation is active
        testModule.shouldDelay = true

        Task {
            _ = await hotSwapManager.performHotSwap(
                moduleId: moduleId,
                targetVersion: targetVersion,
                initiatedBy: "test"
            )
        }

        // Give the operation time to start
        try await Task.sleep(for: .milliseconds(50))

        let activeOperations = await hotSwapManager.getActiveOperations()

        // Reset delay to allow operation to complete
        testModule.shouldDelay = false

        // Should have at least one active operation
        XCTAssertFalse(activeOperations.isEmpty)

        let operation = activeOperations.first!
        XCTAssertEqual(operation.targetModule.identifier, moduleId)
        XCTAssertEqual(operation.operation, .replace)
    }
}

// MARK: - Test Helpers

fileprivate class TestHotSwappableModule: HotSwappableModule {
    var shouldRejectVersion = false
    var shouldDelay = false
    var wasRestoredFromSnapshot = false

    let version: ModuleVersion

    init(identifier: String = "TestModule") {
        version = ModuleVersion(
            identifier: identifier,
            version: "1.0.0",
            buildNumber: "100",
            checksum: "abc123",
            compatibilityVersion: "1.0"
        )
    }

    func prepareForSwap(context: HotSwapContext) async throws {
        if shouldDelay {
            try await Task.sleep(for: .milliseconds(200))
        }
        // Simulate preparation
    }

    func completeSwap(context: HotSwapContext) async throws {
        // Simulate completion
    }

    func validateCompatibility(with version: ModuleVersion) async -> HotSwapValidationResult {
        if shouldRejectVersion {
            return .incompatible(reason: "Incompatible version for testing")
        }

        // Simple compatibility check
        if version.compatibilityVersion.hasPrefix("2.") {
            return .valid
        } else if version.compatibilityVersion.hasPrefix("3.") {
            return .incompatible(reason: "Major version mismatch")
        }

        return .valid
    }

    func createSnapshot() async throws -> Data {
        // Return simple test snapshot
        Data("test_snapshot".utf8)
    }

    func restoreFromSnapshot(_ data: Data) async throws {
        wasRestoredFromSnapshot = true
        // Simulate restoration
    }
}

fileprivate class TestHotSwapListener: HotSwapEventListener {
    private(set) var events: [HotSwapEvent] = []

    func onHotSwapEvent(_ event: HotSwapEvent) async {
        events.append(event)
    }
}
