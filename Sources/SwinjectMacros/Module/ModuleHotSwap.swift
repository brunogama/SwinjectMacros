// ModuleHotSwap.swift - Hot-swappable module system for runtime updates
// Copyright © 2025 SwinjectMacros. All rights reserved.

import Foundation
import os.log
import Swinject

/// Hot-swap operation types
public enum HotSwapOperation: String, Sendable {
    case replace = "REPLACE"
    case update = "UPDATE"
    case rollback = "ROLLBACK"
    case validate = "VALIDATE"
}

/// Hot-swap validation result
public enum HotSwapValidationResult {
    case valid
    case incompatible(reason: String)
    case unsafe(reason: String)
    case dependencyConflict(conflicts: [String])
}

/// Hot-swap execution result
public enum HotSwapResult {
    case success(moduleId: String, operation: HotSwapOperation)
    case failure(error: Error)
    case validationFailed(result: HotSwapValidationResult)
    case rollbackRequired(reason: String)
}

/// Module version information for hot-swap tracking
public struct ModuleVersion: Sendable, Codable {
    public let identifier: String
    public let version: String
    public let buildNumber: String
    public let checksum: String
    public let compatibilityVersion: String
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        identifier: String,
        version: String,
        buildNumber: String,
        checksum: String,
        compatibilityVersion: String,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.version = version
        self.buildNumber = buildNumber
        self.checksum = checksum
        self.compatibilityVersion = compatibilityVersion
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Hot-swap context for tracking operations
public struct HotSwapContext: Sendable {
    public let operationId: UUID
    public let operation: HotSwapOperation
    public let sourceModule: ModuleVersion?
    public let targetModule: ModuleVersion
    public let initiatedBy: String
    public let timestamp: Date
    public let dryRun: Bool
    public let rollbackPoint: String?

    public init(
        operationId: UUID = UUID(),
        operation: HotSwapOperation,
        sourceModule: ModuleVersion? = nil,
        targetModule: ModuleVersion,
        initiatedBy: String,
        timestamp: Date = Date(),
        dryRun: Bool = false,
        rollbackPoint: String? = nil
    ) {
        self.operationId = operationId
        self.operation = operation
        self.sourceModule = sourceModule
        self.targetModule = targetModule
        self.initiatedBy = initiatedBy
        self.timestamp = timestamp
        self.dryRun = dryRun
        self.rollbackPoint = rollbackPoint
    }
}

/// Protocol for hot-swappable modules
public protocol HotSwappableModule {
    /// Module version information
    var version: ModuleVersion { get }

    /// Prepare for hot-swap operation
    func prepareForSwap(context: HotSwapContext) async throws

    /// Complete hot-swap operation
    func completeSwap(context: HotSwapContext) async throws

    /// Validate compatibility with another module version
    func validateCompatibility(with version: ModuleVersion) async -> HotSwapValidationResult

    /// Create snapshot for rollback
    func createSnapshot() async throws -> Data

    /// Restore from snapshot
    func restoreFromSnapshot(_ data: Data) async throws
}

/// Hot-swap event for notifications
public struct HotSwapEvent: Sendable {
    public let context: HotSwapContext
    public let phase: HotSwapPhase
    public let timestamp: Date
    public let metadata: [String: String]

    public init(
        context: HotSwapContext,
        phase: HotSwapPhase,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.context = context
        self.phase = phase
        self.timestamp = timestamp
        self.metadata = metadata
    }
}

/// Hot-swap execution phases
public enum HotSwapPhase: String, Sendable {
    case validating = "VALIDATING"
    case preparing = "PREPARING"
    case snapshotting = "SNAPSHOTTING"
    case swapping = "SWAPPING"
    case completing = "COMPLETING"
    case rollingBack = "ROLLING_BACK"
}

/// Protocol for hot-swap event listeners
public protocol HotSwapEventListener: Sendable {
    func onHotSwapEvent(_ event: HotSwapEvent) async
}

/// Advanced hot-swap manager for runtime module updates
public actor ModuleHotSwapManager {

    // MARK: - Properties

    private var registeredModules: [String: HotSwappableModule] = [:]
    private var moduleVersions: [String: ModuleVersion] = [:]
    private var activeOperations: [UUID: HotSwapContext] = [:]
    private var rollbackPoints: [String: Data] = [:]
    private var eventListeners: [HotSwapEventListener] = []
    private let logger = Logger(subsystem: "com.swinjectmacros", category: "hot-swap")

    /// Shared instance
    public static let shared = ModuleHotSwapManager()

    private init() {}

    // MARK: - Registration

    /// Register a hot-swappable module
    public func registerModule(_ module: HotSwappableModule) throws {
        let moduleId = module.version.identifier

        // Validate module version
        guard !moduleId.isEmpty else {
            throw HotSwapError.invalidModule(reason: "Module identifier cannot be empty")
        }

        registeredModules[moduleId] = module
        moduleVersions[moduleId] = module.version

        logger.info("Registered hot-swappable module: \(moduleId) v\(module.version.version)")
    }

    /// Unregister a module
    public func unregisterModule(_ moduleId: String) {
        registeredModules.removeValue(forKey: moduleId)
        moduleVersions.removeValue(forKey: moduleId)
        rollbackPoints.removeValue(forKey: moduleId)

        logger.info("Unregistered module: \(moduleId)")
    }

    /// Register hot-swap event listener
    public func registerEventListener(_ listener: HotSwapEventListener) {
        eventListeners.append(listener)
    }

    // MARK: - Hot-Swap Operations

    /// Perform hot-swap operation
    public func performHotSwap(
        moduleId: String,
        targetVersion: ModuleVersion,
        operation: HotSwapOperation = .replace,
        initiatedBy: String,
        dryRun: Bool = false
    ) async -> HotSwapResult {

        guard let currentModule = registeredModules[moduleId] else {
            return .failure(error: HotSwapError.moduleNotFound(moduleId))
        }

        let context = HotSwapContext(
            operation: operation,
            sourceModule: moduleVersions[moduleId],
            targetModule: targetVersion,
            initiatedBy: initiatedBy,
            dryRun: dryRun,
            rollbackPoint: generateRollbackPointId(for: moduleId)
        )

        activeOperations[context.operationId] = context

        do {
            // Validation phase
            await notifyListeners(HotSwapEvent(context: context, phase: .validating))
            let validationResult = await currentModule.validateCompatibility(with: targetVersion)

            switch validationResult {
            case .valid:
                break
            case .incompatible(let reason):
                return .validationFailed(result: .incompatible(reason: reason))
            case .unsafe(let reason):
                return .validationFailed(result: .unsafe(reason: reason))
            case .dependencyConflict(let conflicts):
                return .validationFailed(result: .dependencyConflict(conflicts: conflicts))
            }

            if dryRun {
                logger.info("Dry run validation passed for \(moduleId)")
                return .success(moduleId: moduleId, operation: .validate)
            }

            // Preparation phase
            await notifyListeners(HotSwapEvent(context: context, phase: .preparing))
            try await currentModule.prepareForSwap(context: context)

            // Snapshot phase
            await notifyListeners(HotSwapEvent(context: context, phase: .snapshotting))
            let snapshot = try await currentModule.createSnapshot()
            rollbackPoints[context.rollbackPoint!] = snapshot

            // Swapping phase
            await notifyListeners(HotSwapEvent(context: context, phase: .swapping))
            try await performSwapOperation(context: context)

            // Completion phase
            await notifyListeners(HotSwapEvent(context: context, phase: .completing))
            try await currentModule.completeSwap(context: context)

            // Update version tracking
            moduleVersions[moduleId] = targetVersion

            activeOperations.removeValue(forKey: context.operationId)

            logger.info("Hot-swap completed successfully for \(moduleId) to version \(targetVersion.version)")
            return .success(moduleId: moduleId, operation: operation)

        } catch {
            logger.error("Hot-swap failed for \(moduleId): \(error.localizedDescription)")

            // Attempt rollback
            if let rollbackPoint = context.rollbackPoint,
               let snapshot = rollbackPoints[rollbackPoint]
            {
                await performRollback(moduleId: moduleId, snapshot: snapshot, context: context)
            }

            activeOperations.removeValue(forKey: context.operationId)
            return .failure(error: error)
        }
    }

    /// Rollback to previous version
    public func rollback(moduleId: String, rollbackPointId: String) async -> HotSwapResult {
        guard let currentModule = registeredModules[moduleId] else {
            return .failure(error: HotSwapError.moduleNotFound(moduleId))
        }

        guard let snapshot = rollbackPoints[rollbackPointId] else {
            return .failure(error: HotSwapError.rollbackPointNotFound(rollbackPointId))
        }

        let context = HotSwapContext(
            operation: .rollback,
            targetModule: moduleVersions[moduleId]!,
            initiatedBy: "system",
            rollbackPoint: rollbackPointId
        )

        do {
            await performRollback(moduleId: moduleId, snapshot: snapshot, context: context)
            return .success(moduleId: moduleId, operation: .rollback)
        } catch {
            return .failure(error: error)
        }
    }

    // MARK: - Query Methods

    /// Get current module version
    public func getCurrentVersion(for moduleId: String) -> ModuleVersion? {
        moduleVersions[moduleId]
    }

    /// Get all registered modules
    public func getRegisteredModules() -> [String: ModuleVersion] {
        moduleVersions
    }

    /// Get active operations
    public func getActiveOperations() -> [HotSwapContext] {
        Array(activeOperations.values)
    }

    /// Check if module supports hot-swap
    public func supportsHotSwap(moduleId: String) -> Bool {
        registeredModules[moduleId] != nil
    }

    /// Get available rollback points
    public func getAvailableRollbackPoints(for moduleId: String) -> [String] {
        rollbackPoints.keys.filter { $0.hasPrefix(moduleId) }.sorted()
    }

    // MARK: - Private Implementation

    private func performSwapOperation(context: HotSwapContext) async throws {
        // In a real implementation, this would handle the actual module replacement
        // This is a placeholder for the core swap logic
        logger.info("Performing swap operation for \(context.targetModule.identifier)")

        // Simulate swap operation
        try await Task.sleep(nanoseconds: 100_000_000)
    }

    private func performRollback(moduleId: String, snapshot: Data, context: HotSwapContext) async {
        do {
            await notifyListeners(HotSwapEvent(context: context, phase: .rollingBack))

            guard let module = registeredModules[moduleId] else { return }
            try await module.restoreFromSnapshot(snapshot)

            logger.info("Rollback completed for \(moduleId)")
        } catch {
            logger.error("Rollback failed for \(moduleId): \(error.localizedDescription)")
        }
    }

    private func generateRollbackPointId(for moduleId: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(moduleId)_\(timestamp)"
    }

    private func notifyListeners(_ event: HotSwapEvent) async {
        for listener in eventListeners {
            await listener.onHotSwapEvent(event)
        }
    }
}

// MARK: - Errors

public enum HotSwapError: Error, LocalizedError {
    case moduleNotFound(String)
    case invalidModule(reason: String)
    case rollbackPointNotFound(String)
    case swapInProgress(moduleId: String)
    case incompatibleVersion(current: String, target: String)
    case snapshotFailed(reason: String)
    case restoreFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .moduleNotFound(let moduleId):
            "Module '\(moduleId)' not found or not registered for hot-swap"
        case .invalidModule(let reason):
            "Invalid module: \(reason)"
        case .rollbackPointNotFound(let pointId):
            "Rollback point '\(pointId)' not found"
        case .swapInProgress(let moduleId):
            "Hot-swap operation already in progress for module '\(moduleId)'"
        case .incompatibleVersion(let current, let target):
            "Incompatible versions: current '\(current)' cannot be swapped to '\(target)'"
        case .snapshotFailed(let reason):
            "Snapshot creation failed: \(reason)"
        case .restoreFailed(let reason):
            "Restore from snapshot failed: \(reason)"
        }
    }
}

// MARK: - Built-in Event Listeners

/// Logging hot-swap event listener
public struct LoggingHotSwapListener: HotSwapEventListener {
    private let logger: Logger

    public init() {
        logger = Logger(subsystem: "com.swinjectmacros", category: "hot-swap-events")
    }

    public func onHotSwapEvent(_ event: HotSwapEvent) async {
        let moduleId = event.context.targetModule.identifier
        let phase = event.phase.rawValue
        let operation = event.context.operation.rawValue

        logger.info("Hot-swap \(operation) for \(moduleId): \(phase)")
    }
}

/// Performance monitoring hot-swap listener
public actor PerformanceHotSwapListener: HotSwapEventListener {
    private let logger: Logger
    private var timingData: [String: [HotSwapPhase: Date]] = [:]

    public init() {
        logger = Logger(subsystem: "com.swinjectmacros", category: "hot-swap-performance")
    }

    public func onHotSwapEvent(_ event: HotSwapEvent) async {
        let operationId = event.context.operationId.uuidString
        let phase = event.phase
        let now = Date()

        if timingData[operationId] == nil {
            timingData[operationId] = [:]
        }

        timingData[operationId]![phase] = now

        // Log timing when operation completes
        if phase == .completing || phase == .rollingBack {
            logOperationTiming(for: event.context.operationId, event: event)
            timingData.removeValue(forKey: operationId)
        }
    }

    private func logOperationTiming(for operationId: UUID, event: HotSwapEvent) {
        guard let phases = timingData[operationId.uuidString] else { return }

        let moduleId = event.context.targetModule.identifier
        logger.info("Hot-swap timing for \(moduleId):")

        let orderedPhases: [HotSwapPhase] = [.validating, .preparing, .snapshotting, .swapping, .completing]
        var previousTime: Date?

        for phase in orderedPhases {
            if let phaseTime = phases[phase] {
                if let prev = previousTime {
                    let duration = phaseTime.timeIntervalSince(prev)
                    logger.info("  \(phase.rawValue): \(String(format: "%.3f", duration * 1000))ms")
                }
                previousTime = phaseTime
            }
        }
    }
}
