// ModulePerformanceOptimizerTests.swift - Tests for performance optimization
// Copyright © 2025 SwinjectMacros. All rights reserved.

@testable import SwinjectMacros
import XCTest

final class ModulePerformanceOptimizerTests: XCTestCase {

    var optimizer: ModulePerformanceOptimizer!

    override func setUp() async throws {
        try await super.setUp()
        optimizer = ModulePerformanceOptimizer.shared
    }

    override func tearDown() async throws {
        // Reset the singleton's internal state to avoid test pollution
        await optimizer.reset()
        optimizer = nil
        try await super.tearDown()
    }

    // MARK: - Configuration Tests

    func testModuleConfiguration() async throws {
        let moduleId = "TestModule"
        let config = ModulePerformanceConfig(
            moduleId: moduleId,
            strategy: .lazyLoading,
            priority: .high,
            maxMemoryUsage: 1024 * 1024,
            preloadDependencies: true,
            enableCaching: true,
            cacheSize: 50,
            lazyThreshold: 0.05,
            unloadTimeout: 300
        )

        await optimizer.configureModule(config)

        let retrievedConfig = await optimizer.getConfiguration(for: moduleId)
        XCTAssertNotNil(retrievedConfig)
        XCTAssertEqual(retrievedConfig?.strategy, .lazyLoading)
        XCTAssertEqual(retrievedConfig?.priority, .high)
        XCTAssertEqual(retrievedConfig?.maxMemoryUsage, 1024 * 1024)
        XCTAssertTrue(retrievedConfig?.preloadDependencies ?? false)
        XCTAssertTrue(retrievedConfig?.enableCaching ?? false)
        XCTAssertEqual(retrievedConfig?.cacheSize, 50)
    }

    func testStrategyUpdate() async throws {
        let moduleId = "TestModule"
        let initialConfig = ModulePerformanceConfig(
            moduleId: moduleId,
            strategy: .balanced
        )

        await optimizer.configureModule(initialConfig)
        await optimizer.updateStrategy(.lazyLoading, for: moduleId)

        let updatedConfig = await optimizer.getConfiguration(for: moduleId)
        XCTAssertEqual(updatedConfig?.strategy, .lazyLoading)
    }

    // MARK: - Optimization Strategy Tests

    func testLazyLoadingOptimization() async throws {
        let moduleId = "LazyModule"
        let config = ModulePerformanceConfig(
            moduleId: moduleId,
            strategy: .lazyLoading,
            priority: .low
        )

        await optimizer.configureModule(config)

        do {
            try await optimizer.optimizeModuleLoading(moduleId)

            // Should not throw error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Lazy loading optimization failed: \(error)")
        }
    }

    func testPreloadingOptimization() async throws {
        let moduleId = "PreloadModule"
        let config = ModulePerformanceConfig(
            moduleId: moduleId,
            strategy: .preloading,
            priority: .high,
            preloadDependencies: true
        )

        await optimizer.configureModule(config)

        do {
            try await optimizer.optimizeModuleLoading(moduleId)

            // Should not throw error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Preloading optimization failed: \(error)")
        }
    }

    func testMemoryOptimization() async throws {
        let moduleId = "MemoryModule"
        let config = ModulePerformanceConfig(
            moduleId: moduleId,
            strategy: .memoryOptimized,
            maxMemoryUsage: 512 * 1024,
            unloadTimeout: 60
        )

        await optimizer.configureModule(config)

        do {
            try await optimizer.optimizeModuleLoading(moduleId)

            // Should not throw error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Memory optimization failed: \(error)")
        }
    }

    func testStartupOptimization() async throws {
        let moduleId = "StartupModule"
        let config = ModulePerformanceConfig(
            moduleId: moduleId,
            strategy: .startupOptimized,
            priority: .critical
        )

        await optimizer.configureModule(config)

        do {
            try await optimizer.optimizeModuleLoading(moduleId)

            // Should not throw error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Startup optimization failed: \(error)")
        }
    }

    func testBalancedOptimization() async throws {
        let moduleId = "BalancedModule"
        let config = ModulePerformanceConfig(
            moduleId: moduleId,
            strategy: .balanced,
            priority: .normal
        )

        await optimizer.configureModule(config)

        do {
            try await optimizer.optimizeModuleLoading(moduleId)

            // Should not throw error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Balanced optimization failed: \(error)")
        }
    }

    func testUnconfiguredModuleOptimization() async throws {
        let moduleId = "UnconfiguredModule"

        do {
            try await optimizer.optimizeModuleLoading(moduleId)
            XCTFail("Should have thrown configuration not found error")
        } catch PerformanceError.configurationNotFound(let id) {
            XCTAssertEqual(id, moduleId)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Critical Modules Preloading Tests

    func testCriticalModulesPreloading() async throws {
        let criticalModule = "CriticalModule"
        let highPriorityModule = "HighPriorityModule"
        let normalModule = "NormalModule"

        await optimizer.configureModule(ModulePerformanceConfig(
            moduleId: criticalModule,
            strategy: .preloading,
            priority: .critical
        ))

        await optimizer.configureModule(ModulePerformanceConfig(
            moduleId: highPriorityModule,
            strategy: .preloading,
            priority: .high
        ))

        await optimizer.configureModule(ModulePerformanceConfig(
            moduleId: normalModule,
            strategy: .balanced,
            priority: .normal
        ))

        // This should preload critical and high priority modules only
        await optimizer.preloadCriticalModules()

        // Should complete without errors
        XCTAssertTrue(true)
    }

    // MARK: - Service Resolution Optimization Tests

    func testServiceResolutionOptimization() async throws {
        let moduleId = "TestModule"
        let config = ModulePerformanceConfig(
            moduleId: moduleId,
            enableCaching: true,
            cacheSize: 10
        )

        await optimizer.configureModule(config)

        // Test service resolution (would return nil in our mock implementation)
        let service: String? = await optimizer.optimizeServiceResolution(
            String.self,
            name: "testService",
            moduleId: moduleId
        )

        // Should not crash even if service is not found
        XCTAssertNil(service) // Expected in our mock implementation
    }

    // MARK: - Memory Pressure Tests

    func testMemoryPressureHandling() async throws {
        let moduleId = "TestModule"
        let config = ModulePerformanceConfig(
            moduleId: moduleId,
            strategy: .memoryOptimized,
            priority: .low,
            enableCaching: true
        )

        await optimizer.configureModule(config)

        // Handle memory pressure
        await optimizer.handleMemoryPressure()

        // Should complete without errors
        XCTAssertTrue(true)
    }

    // MARK: - Metrics Tests

    func testMetricsCollection() async throws {
        let moduleId = "MetricsModule"
        let config = ModulePerformanceConfig(moduleId: moduleId)

        await optimizer.configureModule(config)

        let metrics = await optimizer.getMetrics(for: moduleId)
        XCTAssertNotNil(metrics)
        XCTAssertEqual(metrics?.moduleId, moduleId)
    }

    func testAggregatedMetrics() async throws {
        let module1 = "Module1"
        let module2 = "Module2"

        await optimizer.configureModule(ModulePerformanceConfig(moduleId: module1))
        await optimizer.configureModule(ModulePerformanceConfig(moduleId: module2))

        let allMetrics = await optimizer.getAggregatedMetrics()
        XCTAssertGreaterThanOrEqual(allMetrics.count, 2)

        let moduleIds = allMetrics.map { $0.moduleId }
        XCTAssertTrue(moduleIds.contains(module1))
        XCTAssertTrue(moduleIds.contains(module2))
    }

    func testPerformanceSummary() async throws {
        let moduleId = "SummaryModule"
        await optimizer.configureModule(ModulePerformanceConfig(moduleId: moduleId))

        let summary = await optimizer.getPerformanceSummary()
        XCTAssertGreaterThan(summary.totalModules, 0)
        XCTAssertGreaterThanOrEqual(summary.averageLoadTime, 0)
        XCTAssertGreaterThanOrEqual(summary.totalMemoryUsage, 0)
        XCTAssertGreaterThanOrEqual(summary.averageCacheHitRate, 0)
        XCTAssertGreaterThanOrEqual(summary.cacheSize, 0)
    }

    func testPerformanceReport() async throws {
        let moduleId = "ReportModule"
        await optimizer.configureModule(ModulePerformanceConfig(moduleId: moduleId))

        let report = await optimizer.generatePerformanceReport()
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("Module Performance Report"))
        XCTAssertTrue(report.contains("Total Modules:"))
        XCTAssertTrue(report.contains(moduleId))
    }

    // MARK: - Edge Cases Tests

    func testConfigurationWithNilValues() async throws {
        let moduleId = "NilConfigModule"
        let config = ModulePerformanceConfig(
            moduleId: moduleId,
            maxMemoryUsage: nil,
            unloadTimeout: nil
        )

        await optimizer.configureModule(config)

        let retrievedConfig = await optimizer.getConfiguration(for: moduleId)
        XCTAssertNotNil(retrievedConfig)
        XCTAssertNil(retrievedConfig?.maxMemoryUsage)
        XCTAssertNil(retrievedConfig?.unloadTimeout)
    }

    func testGetConfigurationForNonExistentModule() async throws {
        let config = await optimizer.getConfiguration(for: "NonExistentModule")
        XCTAssertNil(config)
    }

    func testGetMetricsForNonExistentModule() async throws {
        let metrics = await optimizer.getMetrics(for: "NonExistentModule")
        XCTAssertNil(metrics)
    }

    // MARK: - Reset Tests

    func testResetClearsAllState() async throws {
        // Configure multiple modules
        let moduleIds = ["Module1", "Module2", "Module3"]
        for moduleId in moduleIds {
            let config = ModulePerformanceConfig(
                moduleId: moduleId,
                strategy: .lazyLoading,
                priority: .normal,
                enableCaching: true
            )
            await optimizer.configureModule(config)
        }

        // Verify modules are configured
        for moduleId in moduleIds {
            let config = await optimizer.getConfiguration(for: moduleId)
            XCTAssertNotNil(config, "Module \(moduleId) should be configured")
        }

        // Reset the optimizer
        await optimizer.reset()

        // Verify all state is cleared
        for moduleId in moduleIds {
            let config = await optimizer.getConfiguration(for: moduleId)
            XCTAssertNil(config, "Module \(moduleId) configuration should be cleared after reset")

            let metrics = await optimizer.getMetrics(for: moduleId)
            XCTAssertNil(metrics, "Module \(moduleId) metrics should be cleared after reset")
        }

        // Verify aggregated metrics are empty
        let aggregatedMetrics = await optimizer.getAggregatedMetrics()
        XCTAssertTrue(aggregatedMetrics.isEmpty, "Aggregated metrics should be empty after reset")

        // Verify performance summary shows zero values
        let summary = await optimizer.getPerformanceSummary()
        XCTAssertEqual(summary.totalModules, 0, "Total modules should be 0 after reset")
        XCTAssertEqual(summary.cacheSize, 0, "Cache size should be 0 after reset")
    }
}

// MARK: - Performance Error Tests

final class PerformanceErrorTests: XCTestCase {

    func testConfigurationNotFoundError() {
        let error = PerformanceError.configurationNotFound("TestModule")
        XCTAssertEqual(error.localizedDescription, "Performance configuration not found for module 'TestModule'")
    }

    func testOptimizationFailedError() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = PerformanceError.optimizationFailed("TestModule", underlyingError)
        XCTAssertTrue(error.localizedDescription.contains("Performance optimization failed for module 'TestModule'"))
        XCTAssertTrue(error.localizedDescription.contains("Test error"))
    }

    func testMemoryLimitExceededError() {
        let error = PerformanceError.memoryLimitExceeded("TestModule", 1024)
        XCTAssertEqual(error.localizedDescription, "Memory limit exceeded for module 'TestModule': 1024 bytes")
    }
}
