// ModulePerformanceOptimizer.swift - Performance optimization for module system
// Copyright © 2025 SwinjectMacros. All rights reserved.

import Foundation
import os.log
import Swinject

/// Performance optimization strategies
public enum OptimizationStrategy: String, CaseIterable, Sendable {
    case lazyLoading = "LAZY_LOADING"
    case preloading = "PRELOADING"
    case memoryOptimized = "MEMORY_OPTIMIZED"
    case startupOptimized = "STARTUP_OPTIMIZED"
    case balanced = "BALANCED"
}

/// Module loading priority levels
public enum ModuleLoadingPriority: Int, CaseIterable, Sendable {
    case critical = 0 // Must load immediately
    case high = 1 // Load early in startup
    case normal = 2 // Load as needed
    case low = 3 // Load when convenient
    case deferred = 4 // Load only when explicitly requested
}

/// Performance metrics for modules
public struct ModulePerformanceMetrics: Sendable {
    public let moduleId: String
    public let loadTime: TimeInterval
    public let initializationTime: TimeInterval
    public let memoryUsage: UInt64
    public let resolutionTime: TimeInterval
    public let cacheHitRate: Double
    public let dependencyCount: Int
    public let lastAccessed: Date
    public let accessCount: UInt64
    public let errorCount: UInt64

    public init(
        moduleId: String,
        loadTime: TimeInterval = 0,
        initializationTime: TimeInterval = 0,
        memoryUsage: UInt64 = 0,
        resolutionTime: TimeInterval = 0,
        cacheHitRate: Double = 0,
        dependencyCount: Int = 0,
        lastAccessed: Date = Date(),
        accessCount: UInt64 = 0,
        errorCount: UInt64 = 0
    ) {
        self.moduleId = moduleId
        self.loadTime = loadTime
        self.initializationTime = initializationTime
        self.memoryUsage = memoryUsage
        self.resolutionTime = resolutionTime
        self.cacheHitRate = cacheHitRate
        self.dependencyCount = dependencyCount
        self.lastAccessed = lastAccessed
        self.accessCount = accessCount
        self.errorCount = errorCount
    }
}

/// Performance configuration for modules
public struct ModulePerformanceConfig: Sendable {
    public let moduleId: String
    public let strategy: OptimizationStrategy
    public let priority: ModuleLoadingPriority
    public let maxMemoryUsage: UInt64?
    public let preloadDependencies: Bool
    public let enableCaching: Bool
    public let cacheSize: Int
    public let lazyThreshold: TimeInterval
    public let unloadTimeout: TimeInterval?

    public init(
        moduleId: String,
        strategy: OptimizationStrategy = .balanced,
        priority: ModuleLoadingPriority = .normal,
        maxMemoryUsage: UInt64? = nil,
        preloadDependencies: Bool = false,
        enableCaching: Bool = true,
        cacheSize: Int = 100,
        lazyThreshold: TimeInterval = 0.1,
        unloadTimeout: TimeInterval? = nil
    ) {
        self.moduleId = moduleId
        self.strategy = strategy
        self.priority = priority
        self.maxMemoryUsage = maxMemoryUsage
        self.preloadDependencies = preloadDependencies
        self.enableCaching = enableCaching
        self.cacheSize = cacheSize
        self.lazyThreshold = lazyThreshold
        self.unloadTimeout = unloadTimeout
    }
}

/// Lazy loading state for modules
private enum LazyLoadingState {
    case unloaded
    case loading
    case loaded
    case failed(Error)
}

/// Module cache entry
private struct ModuleCacheEntry {
    let service: Any
    let accessTime: Date
    let accessCount: UInt64

    init(service: Any, accessTime: Date = Date(), accessCount: UInt64 = 1) {
        self.service = service
        self.accessTime = accessTime
        self.accessCount = accessCount
    }

    func withAccess() -> ModuleCacheEntry {
        ModuleCacheEntry(
            service: service,
            accessTime: Date(),
            accessCount: accessCount + 1
        )
    }
}

/// Advanced performance optimizer for module system
public actor ModulePerformanceOptimizer {

    // MARK: - Properties

    private var configurations: [String: ModulePerformanceConfig] = [:]
    private var metrics: [String: ModulePerformanceMetrics] = [:]
    private var lazyLoadingStates: [String: LazyLoadingState] = [:]
    private var serviceCache: [String: ModuleCacheEntry] = [:]
    private var preloadQueue: [String] = []
    private var unloadTasks: [String: Task<Void, Never>] = [:]
    private let logger = Logger(subsystem: "com.swinjectmacros", category: "performance")

    // Cache hit/miss tracking
    private var cacheHits: [String: UInt64] = [:]
    private var cacheMisses: [String: UInt64] = [:]

    /// Shared instance
    public static let shared = ModulePerformanceOptimizer()

    private init() {
        Task {
            await startPerformanceMonitoring()
        }
    }

    // MARK: - Configuration

    /// Configure performance settings for a module
    public func configureModule(_ config: ModulePerformanceConfig) {
        configurations[config.moduleId] = config

        // Initialize metrics
        if metrics[config.moduleId] == nil {
            metrics[config.moduleId] = ModulePerformanceMetrics(moduleId: config.moduleId)
        }

        // Set up lazy loading state
        if config.strategy == .lazyLoading {
            lazyLoadingStates[config.moduleId] = .unloaded
        }

        logger.info("Configured performance for module \(config.moduleId) with strategy \(config.strategy.rawValue)")
    }

    /// Get performance configuration for a module
    public func getConfiguration(for moduleId: String) -> ModulePerformanceConfig? {
        configurations[moduleId]
    }

    /// Update optimization strategy for a module
    public func updateStrategy(_ strategy: OptimizationStrategy, for moduleId: String) {
        guard var config = configurations[moduleId] else { return }

        config = ModulePerformanceConfig(
            moduleId: config.moduleId,
            strategy: strategy,
            priority: config.priority,
            maxMemoryUsage: config.maxMemoryUsage,
            preloadDependencies: config.preloadDependencies,
            enableCaching: config.enableCaching,
            cacheSize: config.cacheSize,
            lazyThreshold: config.lazyThreshold,
            unloadTimeout: config.unloadTimeout
        )

        configurations[moduleId] = config
        applyStrategy(strategy, to: moduleId)
    }

    // MARK: - Performance Optimization

    /// Optimize module loading based on strategy
    public func optimizeModuleLoading(_ moduleId: String) async throws {
        guard let config = configurations[moduleId] else {
            throw PerformanceError.configurationNotFound(moduleId)
        }

        let startTime = Date()

        switch config.strategy {
        case .lazyLoading:
            try await setupLazyLoading(for: moduleId, config: config)
        case .preloading:
            try await performPreloading(for: moduleId, config: config)
        case .memoryOptimized:
            try await optimizeMemoryUsage(for: moduleId, config: config)
        case .startupOptimized:
            try await optimizeStartupTime(for: moduleId, config: config)
        case .balanced:
            try await applyBalancedOptimization(for: moduleId, config: config)
        }

        // Update metrics
        updateLoadTime(for: moduleId, duration: Date().timeIntervalSince(startTime))
    }

    /// Preload critical modules based on priority
    public func preloadCriticalModules() async {
        let criticalModules = configurations.values
            .filter { $0.priority == .critical || $0.priority == .high }
            .sorted { $0.priority.rawValue < $1.priority.rawValue }

        for config in criticalModules {
            do {
                try await optimizeModuleLoading(config.moduleId)
            } catch {
                logger.error("Failed to preload module \(config.moduleId): \(error.localizedDescription)")
                updateErrorCount(for: config.moduleId)
            }
        }
    }

    /// Optimize service resolution
    public func optimizeServiceResolution<T>(
        _ serviceType: T.Type,
        name: String?,
        moduleId: String
    ) async -> T? {
        let startTime = Date()
        let cacheKey = createCacheKey(for: serviceType, name: name, moduleId: moduleId)

        // Check cache first
        if let config = configurations[moduleId],
           config.enableCaching,
           let cached = serviceCache[cacheKey]
        {
            serviceCache[cacheKey] = cached.withAccess()
            updateCacheHit(for: moduleId)
            return cached.service as? T
        }

        // Cache miss - track it
        if let config = configurations[moduleId], config.enableCaching {
            updateCacheMiss(for: moduleId)
        }

        // Resolve service
        let service = await resolveService(serviceType, name: name, moduleId: moduleId)

        // Cache the result
        if let service = service,
           let config = configurations[moduleId],
           config.enableCaching
        {
            cacheService(service, key: cacheKey, config: config)
        }

        // Update metrics
        updateResolutionTime(for: moduleId, duration: Date().timeIntervalSince(startTime))
        updateAccessCount(for: moduleId)

        return service
    }

    /// Memory pressure handling
    public func handleMemoryPressure() async {
        logger.info("Handling memory pressure - clearing caches and unloading unused modules")

        // Clear service cache and cache statistics
        let cacheSize = serviceCache.count
        serviceCache.removeAll()
        cacheHits.removeAll()
        cacheMisses.removeAll()
        logger.info("Cleared service cache (\(cacheSize) entries) and cache statistics")

        // Unload low-priority modules that haven't been accessed recently
        let threshold = Date().addingTimeInterval(-300) // 5 minutes ago

        for (moduleId, config) in configurations {
            if config.priority == .low || config.priority == .deferred,
               let metrics = metrics[moduleId],
               metrics.lastAccessed < threshold
            {
                await unloadModule(moduleId)
            }
        }
    }

    /// Reset all internal state for testing purposes
    public func reset() async {
        logger.info("Resetting ModulePerformanceOptimizer state")

        // Clear all internal state
        configurations.removeAll()
        metrics.removeAll()
        lazyLoadingStates.removeAll()
        serviceCache.removeAll()
        preloadQueue.removeAll()

        // Cancel all unload tasks
        for task in unloadTasks.values {
            task.cancel()
        }
        unloadTasks.removeAll()

        // Clear cache statistics
        cacheHits.removeAll()
        cacheMisses.removeAll()

        logger.info("ModulePerformanceOptimizer state reset completed")
    }

    // MARK: - Metrics and Monitoring

    /// Get performance metrics for a module
    public func getMetrics(for moduleId: String) -> ModulePerformanceMetrics? {
        metrics[moduleId]
    }

    /// Get aggregated performance metrics for all modules
    public func getAggregatedMetrics() -> [ModulePerformanceMetrics] {
        Array(metrics.values)
    }

    /// Get performance summary
    public func getPerformanceSummary() -> PerformanceSummary {
        let allMetrics = Array(metrics.values)

        return PerformanceSummary(
            totalModules: allMetrics.count,
            averageLoadTime: allMetrics.map(\.loadTime).reduce(0, +) / Double(max(allMetrics.count, 1)),
            totalMemoryUsage: allMetrics.map(\.memoryUsage).reduce(0, +),
            averageCacheHitRate: allMetrics.map(\.cacheHitRate).reduce(0, +) / Double(max(allMetrics.count, 1)),
            totalAccessCount: allMetrics.map(\.accessCount).reduce(0, +),
            totalErrorCount: allMetrics.map(\.errorCount).reduce(0, +),
            cacheSize: serviceCache.count
        )
    }

    /// Generate performance report
    public func generatePerformanceReport() -> String {
        let summary = getPerformanceSummary()
        var report = "📊 Module Performance Report\n"
        report += "===========================\n"
        report += "Total Modules: \(summary.totalModules)\n"
        report += "Average Load Time: \(String(format: "%.3f", summary.averageLoadTime * 1000))ms\n"
        report += "Total Memory Usage: \(formatBytes(summary.totalMemoryUsage))\n"
        report += "Average Cache Hit Rate: \(String(format: "%.1f", summary.averageCacheHitRate * 100))%\n"
        report += "Total Access Count: \(summary.totalAccessCount)\n"
        report += "Total Error Count: \(summary.totalErrorCount)\n"
        report += "Cache Size: \(summary.cacheSize) entries\n\n"

        report += "Module Details:\n"
        for metrics in metrics.values.sorted(by: { $0.moduleId < $1.moduleId }) {
            report += "  \(metrics.moduleId):\n"
            report += "    Load Time: \(String(format: "%.3f", metrics.loadTime * 1000))ms\n"
            report += "    Memory: \(formatBytes(metrics.memoryUsage))\n"
            report += "    Cache Hit Rate: \(String(format: "%.1f", metrics.cacheHitRate * 100))%\n"

            let hits = cacheHits[metrics.moduleId] ?? 0
            let misses = cacheMisses[metrics.moduleId] ?? 0
            if hits > 0 || misses > 0 {
                report += "    Cache Hits: \(hits), Misses: \(misses)\n"
            }

            report += "    Access Count: \(metrics.accessCount)\n"
        }

        return report
    }

    // MARK: - Private Implementation

    private func setupLazyLoading(for moduleId: String, config: ModulePerformanceConfig) async throws {
        lazyLoadingStates[moduleId] = .unloaded
        logger.info("Set up lazy loading for module \(moduleId)")
    }

    private func performPreloading(for moduleId: String, config: ModulePerformanceConfig) async throws {
        // Add to preload queue
        if !preloadQueue.contains(moduleId) {
            preloadQueue.append(moduleId)
        }

        // If preload dependencies is enabled, recursively preload
        if config.preloadDependencies {
            // This would analyze and preload module dependencies
            logger.info("Preloading dependencies for module \(moduleId)")
        }
    }

    private func optimizeMemoryUsage(for moduleId: String, config: ModulePerformanceConfig) async throws {
        // Implement memory optimization strategies
        if let maxMemory = config.maxMemoryUsage {
            // Monitor and enforce memory limits
            let maxMemoryStr = formatBytes(maxMemory)
            logger.info("Optimizing memory usage for module \(moduleId) (max: \(maxMemoryStr))")
        }

        // Set up unload timer if configured
        if let timeout = config.unloadTimeout {
            scheduleUnload(for: moduleId, after: timeout)
        }
    }

    private func optimizeStartupTime(for moduleId: String, config: ModulePerformanceConfig) async throws {
        // Optimize for fastest startup
        logger.info("Optimizing startup time for module \(moduleId)")
    }

    private func applyBalancedOptimization(for moduleId: String, config: ModulePerformanceConfig) async throws {
        // Apply balanced optimization strategy
        switch config.priority {
        case .critical, .high:
            try await performPreloading(for: moduleId, config: config)
        case .normal:
            // Use default loading
            break
        case .low, .deferred:
            try await setupLazyLoading(for: moduleId, config: config)
        }
    }

    private func applyStrategy(_ strategy: OptimizationStrategy, to moduleId: String) {
        Task {
            do {
                try await optimizeModuleLoading(moduleId)
            } catch {
                logger
                    .error(
                        "Failed to apply strategy \(strategy.rawValue) to module \(moduleId): \(error.localizedDescription)"
                    )
            }
        }
    }

    private func resolveService<T>(_ serviceType: T.Type, name: String?, moduleId: String) async -> T? {
        // This would integrate with the actual module system to resolve services
        // Placeholder implementation
        nil
    }

    private func createCacheKey(for serviceType: (some Any).Type, name: String?, moduleId: String) -> String {
        let typeName = String(describing: serviceType)
        let serviceName = name ?? "default"
        return "\(moduleId):\(typeName):\(serviceName)"
    }

    private func cacheService(_ service: Any, key: String, config: ModulePerformanceConfig) {
        serviceCache[key] = ModuleCacheEntry(service: service)

        // Implement cache size limit
        if serviceCache.count > config.cacheSize {
            evictLeastRecentlyUsed()
        }
    }

    private func evictLeastRecentlyUsed() {
        guard !serviceCache.isEmpty else { return }

        let oldestKey = serviceCache.min { $0.value.accessTime < $1.value.accessTime }?.key
        if let key = oldestKey {
            serviceCache.removeValue(forKey: key)
        }
    }

    private func scheduleUnload(for moduleId: String, after timeout: TimeInterval) {
        unloadTasks[moduleId]?.cancel()

        // Schedule unload using Task instead of Timer for actor compatibility
        let task = Task {
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            await unloadModule(moduleId)
        }

        unloadTasks[moduleId] = task
    }

    private func unloadModule(_ moduleId: String) async {
        logger.info("Unloading module \(moduleId) due to timeout")
        lazyLoadingStates[moduleId] = .unloaded

        // Clear module-specific cache entries
        let moduleKeys = serviceCache.keys.filter { $0.hasPrefix("\(moduleId):") }
        for key in moduleKeys {
            serviceCache.removeValue(forKey: key)
        }
    }

    private func startPerformanceMonitoring() {
        // Start background monitoring using Task
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                await performPeriodicMaintenance()
            }
        }
    }

    private func performPeriodicMaintenance() async {
        // Update memory usage metrics
        for moduleId in configurations.keys {
            updateMemoryUsage(for: moduleId)
        }

        // Clean up expired cache entries
        cleanupExpiredCacheEntries()
    }

    private func cleanupExpiredCacheEntries() {
        let expireThreshold = Date().addingTimeInterval(-600) // 10 minutes
        let expiredKeys = serviceCache.filter { $0.value.accessTime < expireThreshold }.map(\.key)

        for key in expiredKeys {
            serviceCache.removeValue(forKey: key)
        }

        if !expiredKeys.isEmpty {
            logger.info("Cleaned up \(expiredKeys.count) expired cache entries")
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Metrics Updates

    private func updateLoadTime(for moduleId: String, duration: TimeInterval) {
        guard var current = metrics[moduleId] else { return }
        current = ModulePerformanceMetrics(
            moduleId: current.moduleId,
            loadTime: duration,
            initializationTime: current.initializationTime,
            memoryUsage: current.memoryUsage,
            resolutionTime: current.resolutionTime,
            cacheHitRate: current.cacheHitRate,
            dependencyCount: current.dependencyCount,
            lastAccessed: current.lastAccessed,
            accessCount: current.accessCount,
            errorCount: current.errorCount
        )
        metrics[moduleId] = current
    }

    private func updateResolutionTime(for moduleId: String, duration: TimeInterval) {
        guard var current = metrics[moduleId] else { return }
        current = ModulePerformanceMetrics(
            moduleId: current.moduleId,
            loadTime: current.loadTime,
            initializationTime: current.initializationTime,
            memoryUsage: current.memoryUsage,
            resolutionTime: duration,
            cacheHitRate: current.cacheHitRate,
            dependencyCount: current.dependencyCount,
            lastAccessed: Date(),
            accessCount: current.accessCount,
            errorCount: current.errorCount
        )
        metrics[moduleId] = current
    }

    private func updateAccessCount(for moduleId: String) {
        guard var current = metrics[moduleId] else { return }
        current = ModulePerformanceMetrics(
            moduleId: current.moduleId,
            loadTime: current.loadTime,
            initializationTime: current.initializationTime,
            memoryUsage: current.memoryUsage,
            resolutionTime: current.resolutionTime,
            cacheHitRate: current.cacheHitRate,
            dependencyCount: current.dependencyCount,
            lastAccessed: Date(),
            accessCount: current.accessCount + 1,
            errorCount: current.errorCount
        )
        metrics[moduleId] = current
    }

    private func updateCacheHit(for moduleId: String) {
        // Increment cache hit counter
        cacheHits[moduleId] = (cacheHits[moduleId] ?? 0) + 1

        // Update cache hit rate in metrics
        guard var current = metrics[moduleId] else { return }

        let totalHits = cacheHits[moduleId] ?? 0
        let totalMisses = cacheMisses[moduleId] ?? 0
        let totalAccesses = totalHits + totalMisses

        let cacheHitRate = totalAccesses > 0 ? Double(totalHits) / Double(totalAccesses) : 0.0

        current = ModulePerformanceMetrics(
            moduleId: current.moduleId,
            loadTime: current.loadTime,
            initializationTime: current.initializationTime,
            memoryUsage: current.memoryUsage,
            resolutionTime: current.resolutionTime,
            cacheHitRate: cacheHitRate,
            dependencyCount: current.dependencyCount,
            lastAccessed: Date(),
            accessCount: current.accessCount,
            errorCount: current.errorCount
        )
        metrics[moduleId] = current

        logger.debug("Cache hit for module \(moduleId): hit rate = \(String(format: "%.2f%%", cacheHitRate * 100))")
    }

    private func updateCacheMiss(for moduleId: String) {
        // Increment cache miss counter
        cacheMisses[moduleId] = (cacheMisses[moduleId] ?? 0) + 1

        // Update cache hit rate in metrics
        guard var current = metrics[moduleId] else { return }

        let totalHits = cacheHits[moduleId] ?? 0
        let totalMisses = cacheMisses[moduleId] ?? 0
        let totalAccesses = totalHits + totalMisses

        let cacheHitRate = totalAccesses > 0 ? Double(totalHits) / Double(totalAccesses) : 0.0

        current = ModulePerformanceMetrics(
            moduleId: current.moduleId,
            loadTime: current.loadTime,
            initializationTime: current.initializationTime,
            memoryUsage: current.memoryUsage,
            resolutionTime: current.resolutionTime,
            cacheHitRate: cacheHitRate,
            dependencyCount: current.dependencyCount,
            lastAccessed: Date(),
            accessCount: current.accessCount,
            errorCount: current.errorCount
        )
        metrics[moduleId] = current

        logger.debug("Cache miss for module \(moduleId): hit rate = \(String(format: "%.2f%%", cacheHitRate * 100))")
    }

    private func updateErrorCount(for moduleId: String) {
        guard var current = metrics[moduleId] else { return }
        current = ModulePerformanceMetrics(
            moduleId: current.moduleId,
            loadTime: current.loadTime,
            initializationTime: current.initializationTime,
            memoryUsage: current.memoryUsage,
            resolutionTime: current.resolutionTime,
            cacheHitRate: current.cacheHitRate,
            dependencyCount: current.dependencyCount,
            lastAccessed: current.lastAccessed,
            accessCount: current.accessCount,
            errorCount: current.errorCount + 1
        )
        metrics[moduleId] = current
    }

    private func updateMemoryUsage(for moduleId: String) {
        // This would integrate with system memory monitoring
        // Placeholder implementation
    }
}

// MARK: - Supporting Types

public struct PerformanceSummary: Sendable {
    public let totalModules: Int
    public let averageLoadTime: TimeInterval
    public let totalMemoryUsage: UInt64
    public let averageCacheHitRate: Double
    public let totalAccessCount: UInt64
    public let totalErrorCount: UInt64
    public let cacheSize: Int
}

public enum PerformanceError: Error, LocalizedError {
    case configurationNotFound(String)
    case optimizationFailed(String, Error)
    case memoryLimitExceeded(String, UInt64)

    public var errorDescription: String? {
        switch self {
        case .configurationNotFound(let moduleId):
            "Performance configuration not found for module '\(moduleId)'"
        case .optimizationFailed(let moduleId, let error):
            "Performance optimization failed for module '\(moduleId)': \(error.localizedDescription)"
        case .memoryLimitExceeded(let moduleId, let limit):
            "Memory limit exceeded for module '\(moduleId)': \(limit) bytes"
        }
    }
}
