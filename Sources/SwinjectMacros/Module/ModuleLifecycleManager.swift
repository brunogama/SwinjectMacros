// ModuleLifecycleManager.swift - Advanced lifecycle management for modules
// Copyright © 2025 SwinjectMacros. All rights reserved.

import Foundation
import os.log
import Swinject

/// Advanced lifecycle states for modules
public enum ModuleLifecycleState: String, CaseIterable, Sendable {
    case uninitialized = "UNINITIALIZED"
    case initializing = "INITIALIZING"
    case initialized = "INITIALIZED"
    case starting = "STARTING"
    case active = "ACTIVE"
    case pausing = "PAUSING"
    case paused = "PAUSED"
    case resuming = "RESUMING"
    case stopping = "STOPPING"
    case stopped = "STOPPED"
    case failed = "FAILED"
    case destroyed = "DESTROYED"

    /// Whether this state allows transitions
    public var canTransition: Bool {
        switch self {
        case .failed, .destroyed:
            false
        default:
            true
        }
    }

    /// Whether the module is in an operational state
    public var isOperational: Bool {
        switch self {
        case .active, .paused:
            true
        default:
            false
        }
    }
}

/// Lifecycle event types for module state changes
public enum ModuleLifecycleEvent: String, Sendable {
    case willInitialize = "WILL_INITIALIZE"
    case didInitialize = "DID_INITIALIZE"
    case willStart = "WILL_START"
    case didStart = "DID_START"
    case willPause = "WILL_PAUSE"
    case didPause = "DID_PAUSE"
    case willResume = "WILL_RESUME"
    case didResume = "DID_RESUME"
    case willStop = "WILL_STOP"
    case didStop = "DID_STOP"
    case willDestroy = "WILL_DESTROY"
    case didDestroy = "DID_DESTROY"
    case didFail = "DID_FAIL"
}

/// Lifecycle hook protocol for modules
public protocol ModuleLifecycleHook: Sendable {
    /// Called when module receives a lifecycle event
    func onLifecycleEvent(_ event: ModuleLifecycleEvent, module: String) async throws
}

/// Module lifecycle information
public struct ModuleLifecycleInfo: Sendable {
    public let identifier: String
    public let currentState: ModuleLifecycleState
    public let previousState: ModuleLifecycleState?
    public let stateHistory: [ModuleLifecycleState]
    public let lastTransition: Date
    public let initializationTime: Date?
    public let totalUptime: TimeInterval
    public let failureCount: Int
    public let metadata: [String: String]

    public init(
        identifier: String,
        currentState: ModuleLifecycleState,
        previousState: ModuleLifecycleState? = nil,
        stateHistory: [ModuleLifecycleState] = [],
        lastTransition: Date = Date(),
        initializationTime: Date? = nil,
        totalUptime: TimeInterval = 0,
        failureCount: Int = 0,
        metadata: [String: String] = [:]
    ) {
        self.identifier = identifier
        self.currentState = currentState
        self.previousState = previousState
        self.stateHistory = stateHistory
        self.lastTransition = lastTransition
        self.initializationTime = initializationTime
        self.totalUptime = totalUptime
        self.failureCount = failureCount
        self.metadata = metadata
    }
}

/// Lifecycle transition result
public enum LifecycleTransitionResult {
    case success
    case failure(Error)
    case blocked(reason: String)
    case timeout
}

/// Advanced module lifecycle manager with state tracking and hooks
public actor ModuleLifecycleManager {

    // MARK: - Properties

    private var moduleStates: [String: ModuleLifecycleState] = [:]
    private var stateHistory: [String: [ModuleLifecycleState]] = [:]
    private var transitionTimes: [String: Date] = [:]
    private var initializationTimes: [String: Date] = [:]
    private var uptimeTracking: [String: Date] = [:]
    private var totalUptimes: [String: TimeInterval] = [:]
    private var failureCounts: [String: Int] = [:]
    private var moduleMetadata: [String: [String: String]] = [:]
    private var lifecycleHooks: [ModuleLifecycleHook] = []
    private let logger = Logger(subsystem: "com.swinjectmacros", category: "lifecycle")

    /// Shared instance
    public static let shared = ModuleLifecycleManager()

    private init() {}

    // MARK: - Public Interface

    /// Register a lifecycle hook
    public func registerHook(_ hook: ModuleLifecycleHook) {
        lifecycleHooks.append(hook)
        logger.info("Lifecycle hook registered")
    }

    /// Get current lifecycle information for a module
    public func getLifecycleInfo(for moduleId: String) -> ModuleLifecycleInfo? {
        guard let currentState = moduleStates[moduleId] else { return nil }

        let history = stateHistory[moduleId] ?? []
        let previousState = history.count > 1 ? history[history.count - 2] : nil

        return ModuleLifecycleInfo(
            identifier: moduleId,
            currentState: currentState,
            previousState: previousState,
            stateHistory: history,
            lastTransition: transitionTimes[moduleId] ?? Date(),
            initializationTime: initializationTimes[moduleId],
            totalUptime: calculateTotalUptime(for: moduleId),
            failureCount: failureCounts[moduleId] ?? 0,
            metadata: moduleMetadata[moduleId] ?? [:]
        )
    }

    /// Get all module lifecycle information
    public func getAllLifecycleInfo() -> [ModuleLifecycleInfo] {
        moduleStates.keys.compactMap { getLifecycleInfo(for: $0) }
    }

    /// Initialize a module
    public func initializeModule(
        _ moduleId: String,
        metadata: [String: String] = [:]
    ) async -> LifecycleTransitionResult {
        await performTransition(
            moduleId: moduleId,
            from: .uninitialized,
            to: .initializing,
            event: .willInitialize,
            metadata: metadata
        ) { [weak self] in
            await self?.completeInitialization(moduleId)
        }
    }

    /// Start a module
    public func startModule(_ moduleId: String) async -> LifecycleTransitionResult {
        await performTransition(
            moduleId: moduleId,
            from: .initialized,
            to: .starting,
            event: .willStart
        ) { [weak self] in
            await self?.completeStart(moduleId)
        }
    }

    /// Pause a module
    public func pauseModule(_ moduleId: String) async -> LifecycleTransitionResult {
        await performTransition(
            moduleId: moduleId,
            from: .active,
            to: .pausing,
            event: .willPause
        ) { [weak self] in
            await self?.completePause(moduleId)
        }
    }

    /// Resume a module
    public func resumeModule(_ moduleId: String) async -> LifecycleTransitionResult {
        await performTransition(
            moduleId: moduleId,
            from: .paused,
            to: .resuming,
            event: .willResume
        ) { [weak self] in
            await self?.completeResume(moduleId)
        }
    }

    /// Stop a module
    public func stopModule(_ moduleId: String) async -> LifecycleTransitionResult {
        await performTransition(
            moduleId: moduleId,
            from: .active,
            to: .stopping,
            event: .willStop
        ) { [weak self] in
            await self?.completeStop(moduleId)
        }
    }

    /// Destroy a module
    public func destroyModule(_ moduleId: String) async -> LifecycleTransitionResult {
        await performTransition(
            moduleId: moduleId,
            from: .stopped,
            to: .destroyed,
            event: .willDestroy
        ) { [weak self] in
            await self?.completeDestroy(moduleId)
        }
    }

    /// Mark a module as failed
    public func markModuleFailed(_ moduleId: String, error: Error) async {
        logger.error("Module \(moduleId) failed: \(error.localizedDescription)")

        failureCounts[moduleId] = (failureCounts[moduleId] ?? 0) + 1
        await setState(moduleId, .failed)
        await notifyHooks(.didFail, module: moduleId)
    }

    /// Update module metadata
    public func updateMetadata(for moduleId: String, metadata: [String: String]) {
        moduleMetadata[moduleId] = metadata
        logger.debug("Updated metadata for module \(moduleId)")
    }

    /// Get modules in a specific state
    public func getModules(in state: ModuleLifecycleState) -> [String] {
        moduleStates.compactMap { key, value in
            value == state ? key : nil
        }
    }

    /// Check if module can transition to target state
    public func canTransition(moduleId: String, to targetState: ModuleLifecycleState) -> Bool {
        guard let currentState = moduleStates[moduleId] else { return false }
        return currentState.canTransition && isValidTransition(from: currentState, to: targetState)
    }

    // MARK: - Private Implementation

    private func performTransition(
        moduleId: String,
        from expectedState: ModuleLifecycleState,
        to targetState: ModuleLifecycleState,
        event: ModuleLifecycleEvent,
        metadata: [String: String] = [:],
        action: @escaping () async -> Void
    ) async -> LifecycleTransitionResult {

        let currentState = moduleStates[moduleId] ?? .uninitialized

        // Validate transition
        guard currentState == expectedState || expectedState == .uninitialized else {
            logger
                .warning(
                    "Invalid transition for \(moduleId): expected \(expectedState.rawValue), current \(currentState.rawValue)"
                )
            return .blocked(reason: "Invalid state transition")
        }

        guard canTransition(moduleId: moduleId, to: targetState) else {
            return .blocked(reason: "Transition not allowed")
        }

        do {
            // Update metadata if provided
            if !metadata.isEmpty {
                updateMetadata(for: moduleId, metadata: metadata)
            }

            // Set transitional state
            await setState(moduleId, targetState)

            // Notify hooks
            await notifyHooks(event, module: moduleId)

            // Perform action
            await action()

            return .success

        } catch {
            logger.error("Transition failed for \(moduleId): \(error.localizedDescription)")
            await markModuleFailed(moduleId, error: error)
            return .failure(error)
        }
    }

    private func setState(_ moduleId: String, _ state: ModuleLifecycleState) async {
        let previousState = moduleStates[moduleId]
        moduleStates[moduleId] = state
        transitionTimes[moduleId] = Date()

        // Update state history
        var history = stateHistory[moduleId] ?? []
        history.append(state)
        stateHistory[moduleId] = history

        // Track uptime
        updateUptimeTracking(moduleId: moduleId, newState: state, previousState: previousState)

        logger.info("Module \(moduleId) transitioned to \(state.rawValue)")
    }

    private func updateUptimeTracking(
        moduleId: String,
        newState: ModuleLifecycleState,
        previousState: ModuleLifecycleState?
    ) {
        let now = Date()

        // Start tracking when module becomes active
        if newState == .active && previousState != .active {
            uptimeTracking[moduleId] = now
        }

        // Stop tracking and accumulate uptime when leaving active state
        if previousState == .active && newState != .active {
            if let startTime = uptimeTracking[moduleId] {
                let sessionUptime = now.timeIntervalSince(startTime)
                totalUptimes[moduleId] = (totalUptimes[moduleId] ?? 0) + sessionUptime
                uptimeTracking[moduleId] = nil
            }
        }
    }

    private func calculateTotalUptime(for moduleId: String) -> TimeInterval {
        let accumulatedUptime = totalUptimes[moduleId] ?? 0

        // Add current session if module is active
        if moduleStates[moduleId] == .active, let startTime = uptimeTracking[moduleId] {
            let currentSession = Date().timeIntervalSince(startTime)
            return accumulatedUptime + currentSession
        }

        return accumulatedUptime
    }

    private func isValidTransition(
        from currentState: ModuleLifecycleState,
        to targetState: ModuleLifecycleState
    ) -> Bool {
        // Define valid state transitions
        switch (currentState, targetState) {
        case (.uninitialized, .initializing),
             (.initializing, .initialized),
             (.initializing, .failed),
             (.initialized, .starting),
             (.starting, .active),
             (.starting, .failed),
             (.active, .pausing),
             (.active, .stopping),
             (.pausing, .paused),
             (.pausing, .failed),
             (.paused, .resuming),
             (.paused, .stopping),
             (.resuming, .active),
             (.resuming, .failed),
             (.stopping, .stopped),
             (.stopping, .failed),
             (.stopped, .destroyed),
             (.failed, .destroyed):
            true
        default:
            false
        }
    }

    private func notifyHooks(_ event: ModuleLifecycleEvent, module: String) async {
        for hook in lifecycleHooks {
            do {
                try await hook.onLifecycleEvent(event, module: module)
            } catch {
                logger.error("Lifecycle hook failed for event \(event.rawValue): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Lifecycle Completion Methods

    private func completeInitialization(_ moduleId: String) async {
        initializationTimes[moduleId] = Date()
        await setState(moduleId, .initialized)
        await notifyHooks(.didInitialize, module: moduleId)
    }

    private func completeStart(_ moduleId: String) async {
        await setState(moduleId, .active)
        await notifyHooks(.didStart, module: moduleId)
    }

    private func completePause(_ moduleId: String) async {
        await setState(moduleId, .paused)
        await notifyHooks(.didPause, module: moduleId)
    }

    private func completeResume(_ moduleId: String) async {
        await setState(moduleId, .active)
        await notifyHooks(.didResume, module: moduleId)
    }

    private func completeStop(_ moduleId: String) async {
        await setState(moduleId, .stopped)
        await notifyHooks(.didStop, module: moduleId)
    }

    private func completeDestroy(_ moduleId: String) async {
        // Clean up all tracking data
        moduleStates.removeValue(forKey: moduleId)
        stateHistory.removeValue(forKey: moduleId)
        transitionTimes.removeValue(forKey: moduleId)
        initializationTimes.removeValue(forKey: moduleId)
        uptimeTracking.removeValue(forKey: moduleId)
        totalUptimes.removeValue(forKey: moduleId)
        failureCounts.removeValue(forKey: moduleId)
        moduleMetadata.removeValue(forKey: moduleId)

        await notifyHooks(.didDestroy, module: moduleId)
        logger.info("Module \(moduleId) destroyed and cleaned up")
    }
}

// MARK: - Built-in Lifecycle Hooks

/// Logging lifecycle hook
public struct LoggingLifecycleHook: ModuleLifecycleHook {
    private let logger: Logger

    public init(subsystem: String = "com.swinjectmacros", category: String = "module-lifecycle") {
        logger = Logger(subsystem: subsystem, category: category)
    }

    public func onLifecycleEvent(_ event: ModuleLifecycleEvent, module: String) async throws {
        logger.info("Module \(module) lifecycle event: \(event.rawValue)")
    }
}

/// Performance monitoring lifecycle hook
public actor PerformanceLifecycleHook: ModuleLifecycleHook {
    private let logger: Logger
    private var timingData: [String: Date] = [:]

    public init() {
        logger = Logger(subsystem: "com.swinjectmacros", category: "module-performance")
    }

    public func onLifecycleEvent(_ event: ModuleLifecycleEvent, module: String) async throws {
        let now = Date()
        let key = "\(module):\(event.rawValue)"

        switch event {
        case .willInitialize, .willStart, .willPause, .willResume, .willStop, .willDestroy:
            timingData[key] = now

        case .didInitialize, .didStart, .didPause, .didResume, .didStop, .didDestroy:
            let willKey = key.replacingOccurrences(of: "DID_", with: "WILL_")
            if let startTime = timingData[willKey] {
                let duration = now.timeIntervalSince(startTime)
                logger.info("Module \(module) \(event.rawValue) took \(String(format: "%.3f", duration * 1000))ms")
                timingData.removeValue(forKey: willKey)
            }

        case .didFail:
            logger.warning("Module \(module) failed during lifecycle operation")
        }
    }
}
