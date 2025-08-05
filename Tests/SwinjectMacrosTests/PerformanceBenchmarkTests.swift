// PerformanceBenchmarkTests.swift - Performance benchmarks for production readiness
// Copyright © 2025 SwinJectMacros. All rights reserved.

import Foundation
import Swinject
@testable import SwinjectMacros
import XCTest

final class PerformanceBenchmarkTests: XCTestCase {

    // MARK: - LazyInject Performance Tests

    func testLazyInjectResolutionPerformance() {
        // Simulate a service with lazy injection
        class BenchmarkService {
            @LazyInject var repository: PerfMockRepositoryProtocol
            @LazyInject var apiClient: PerfMockAPIClientProtocol
            @LazyInject var cache: PerfMockCacheProtocol
            @LazyInject var logger: PerfMockLoggerProtocol
            @LazyInject var validator: PerfMockValidatorProtocol

            init() {}

            func performOperation() -> String {
                repository.getData() + apiClient.fetchData() + cache.getCachedValue() + logger
                    .getLogLevel() + validator.validateInput("test")
            }
        }

        // Setup mock container registrations
        setupMockContainer()

        let service = BenchmarkService()

        // Measure first access (cold start - includes resolution time)
        measure {
            _ = service.performOperation()
        }

        // This should be significantly faster on subsequent calls due to lazy caching
        let coldStartTime = measureTime {
            _ = service.performOperation()
        }

        let warmStartTime = measureTime {
            _ = service.performOperation()
        }

        // Warm start should be at least 10x faster than cold start
        XCTAssertLessThan(
            warmStartTime,
            coldStartTime / 10.0,
            "Lazy injection should be significantly faster after first resolution"
        )

        // Absolute performance requirements
        XCTAssertLessThan(coldStartTime, 0.001, "Cold start should be under 1ms") // 1ms
        XCTAssertLessThan(warmStartTime, 0.0001, "Warm start should be under 0.1ms") // 0.1ms
    }

    func testConcurrentLazyInjectPerformance() {
        class ConcurrentService {
            @LazyInject var sharedResource: MockExpensiveResource

            init() {}

            func accessResource() -> String {
                sharedResource.heavyComputation()
            }
        }

        setupMockContainer()
        let service = ConcurrentService()

        // Test concurrent access performance
        let concurrentAccessTime = measureTime {
            let group = DispatchGroup()
            let queue = DispatchQueue.global(qos: .userInitiated)

            for _ in 0..<100 {
                group.enter()
                queue.async {
                    _ = service.accessResource()
                    group.leave()
                }
            }

            group.wait()
        }

        // 100 concurrent accesses should complete within reasonable time
        XCTAssertLessThan(concurrentAccessTime, 0.1, "100 concurrent lazy inject accesses should complete under 100ms")
    }

    // MARK: - WeakInject Performance Tests

    func testWeakInjectPerformance() {
        class WeakService {
            @WeakInject var delegate: MockDelegate? = nil
            @WeakInject var observer: MockObserver? = nil

            init() {}

            func performDelegateOperations() -> Int {
                (delegate?.performAction() ?? 0) + (observer?.observeEvent() ?? 0)
            }
        }

        setupMockContainer()
        let service = WeakService()

        let accessTime = measureTime {
            for _ in 0..<1000 {
                _ = service.performDelegateOperations()
            }
        }

        // 1000 weak reference accesses should be very fast
        XCTAssertLessThan(accessTime, 0.01, "1000 weak inject accesses should complete under 10ms")
    }

    // MARK: - Circuit Breaker Performance Tests

    func testCircuitBreakerPerformance() {
        class CircuitBreakerService {
            @CircuitBreaker(failureThreshold: 5, timeout: 10.0)
            func networkOperation() throws -> String {
                // Simulate network operation
                Thread.sleep(forTimeInterval: 0.001) // 1ms simulated network delay
                return "success"
            }
        }

        let service = CircuitBreakerService()

        // Test performance when circuit is closed (normal operation)
        let normalOperationTime = measureTime {
            for _ in 0..<100 {
                do {
                    _ = try service.networkOperationCircuitBreaker()
                } catch {
                    // Handle errors
                }
            }
        }

        // Circuit breaker overhead should be minimal
        let baselineTime = measureTime {
            for _ in 0..<100 {
                do {
                    _ = try service.networkOperation()
                } catch {
                    // Handle errors
                }
            }
        }

        let overhead = normalOperationTime - baselineTime
        XCTAssertLessThan(overhead, baselineTime * 0.1, "Circuit breaker overhead should be less than 10% of baseline")
    }

    // MARK: - Cache Performance Tests

    func testCachePerformance() {
        class CacheService {
            @Cache(ttl: 60, maxEntries: 1000)
            func expensiveComputation(input: Int) -> String {
                // Simulate expensive computation
                Thread.sleep(forTimeInterval: 0.01) // 10ms computation
                return "computed-\(input)"
            }
        }

        let service = CacheService()

        // Test cache miss performance (first access)
        let cacheMissTime = measureTime {
            _ = service.expensiveComputation(input: 1)
        }

        // Test cache hit performance (subsequent access)
        let cacheHitTime = measureTime {
            _ = service.expensiveComputation(input: 1)
        }

        // Cache hit should be significantly faster
        XCTAssertLessThan(
            cacheHitTime,
            cacheMissTime / 100.0,
            "Cache hit should be at least 100x faster than cache miss"
        )
        XCTAssertLessThan(cacheHitTime, 0.0001, "Cache hit should be under 0.1ms")
    }

    // MARK: - Retry Performance Tests

    func testRetryPerformance() {
        class RetryService {
            private var attemptCount = 0

            @Retry(maxAttempts: 3, backoffStrategy: .fixed(delay: 0.001))
            func unreliableOperation() throws -> String {
                attemptCount += 1
                if attemptCount < 2 {
                    throw NSError(domain: "test", code: 1, userInfo: nil)
                }
                return "success"
            }
        }

        let service = RetryService()

        let retryTime = measureTime {
            do {
                _ = try service.unreliableOperation()
            } catch {
                // Handle final failure
            }
        }

        // Retry with 2 attempts and 1ms delay should complete quickly
        XCTAssertLessThan(retryTime, 0.01, "Retry operation should complete under 10ms")
    }

    // MARK: - Memory Usage Tests

    func testMemoryUsageUnderLoad() {
        // Test memory usage with many injectable services
        class MemoryTestService {
            @LazyInject var service1: PerfMockRepositoryProtocol
            @LazyInject var service2: PerfMockAPIClientProtocol
            @LazyInject var service3: PerfMockCacheProtocol
            @LazyInject var service4: PerfMockLoggerProtocol
            @LazyInject var service5: PerfMockValidatorProtocol
            @WeakInject var delegate1: MockDelegate? = nil
            @WeakInject var delegate2: MockObserver? = nil

            init() {}
        }

        setupMockContainer()

        let initialMemory = getCurrentMemoryUsage()

        // Create many service instances
        var services: [MemoryTestService] = []
        for _ in 0..<1000 {
            let service = MemoryTestService()
            // Trigger lazy resolution
            _ = service.service1
            _ = service.service2
            services.append(service)
        }

        let peakMemory = getCurrentMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory

        // Clean up
        services.removeAll()

        let finalMemory = getCurrentMemoryUsage()
        let memoryReclaimed = peakMemory - finalMemory

        // Memory usage should be reasonable
        XCTAssertLessThan(
            memoryIncrease,
            50_000_000,
            "Memory increase should be less than 50MB for 1000 services"
        ) // 50MB
        XCTAssertGreaterThan(
            memoryReclaimed,
            Int64(Double(memoryIncrease) * 0.8),
            "At least 80% of memory should be reclaimed after cleanup"
        )
    }

    // MARK: - Scalability Tests

    func testScalabilityWithManyDependencies() {
        // Test service with many dependencies
        class MegaService {
            @LazyInject var dep1: PerfMockRepositoryProtocol
            @LazyInject var dep2: PerfMockAPIClientProtocol
            @LazyInject var dep3: PerfMockCacheProtocol
            @LazyInject var dep4: PerfMockLoggerProtocol
            @LazyInject var dep5: PerfMockValidatorProtocol
            @LazyInject var dep6: PerfMockRepositoryProtocol
            @LazyInject var dep7: PerfMockAPIClientProtocol
            @LazyInject var dep8: PerfMockCacheProtocol
            @LazyInject var dep9: PerfMockLoggerProtocol
            @LazyInject var dep10: PerfMockValidatorProtocol

            init() {}

            func accessAllDependencies() -> String {
                dep1.getData() + dep2.fetchData() + dep3.getCachedValue() +
                    dep4.getLogLevel() + dep5.validateInput("test") +
                    dep6.getData() + dep7.fetchData() + dep8.getCachedValue() +
                    dep9.getLogLevel() + dep10.validateInput("test")
            }
        }

        setupMockContainer()
        let service = MegaService()

        // First access (resolution of all dependencies)
        let resolutionTime = measureTime {
            _ = service.accessAllDependencies()
        }

        // Subsequent accesses should be fast
        let accessTime = measureTime {
            for _ in 0..<100 {
                _ = service.accessAllDependencies()
            }
        }

        XCTAssertLessThan(resolutionTime, 0.01, "Resolution of 10 dependencies should be under 10ms")
        XCTAssertLessThan(accessTime, 0.001, "100 accesses to resolved dependencies should be under 1ms")
    }

    // MARK: - Thread Safety Performance Tests

    func testThreadSafetyPerformance() {
        class ThreadSafeService {
            @LazyInject var sharedResource: MockExpensiveResource

            init() {}
        }

        setupMockContainer()

        let service = ThreadSafeService()
        let queue = DispatchQueue.global(qos: .userInitiated)

        // Test performance under heavy concurrent load
        let concurrentTime = measureTime {
            DispatchQueue.concurrentPerform(iterations: 1000) { _ in
                _ = service.sharedResource.heavyComputation()
            }
        }

        XCTAssertLessThan(concurrentTime, 1.0, "1000 concurrent thread-safe accesses should complete under 1 second")
    }

    // MARK: - Utility Methods

    private func measureTime(_ block: () -> Void) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        block()
        let endTime = CFAbsoluteTimeGetCurrent()
        return endTime - startTime
    }

    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    private func setupMockContainer() {
        // Setup mock registrations for testing
        Container.shared.removeAll()
        Container.shared.register(PerfMockRepositoryProtocol.self) { _ in FastMockRepository() }
        Container.shared.register(PerfMockAPIClientProtocol.self) { _ in PerfFastMockAPIClient() }
        Container.shared.register(PerfMockCacheProtocol.self) { _ in FastMockCache() }
        Container.shared.register(PerfMockLoggerProtocol.self) { _ in PerfFastMockLogger() }
        Container.shared.register(PerfMockValidatorProtocol.self) { _ in FastMockValidator() }
        Container.shared.register(PerfMockObserverProtocol.self) { _ in FastMockObserver() }
        Container.shared.register(PerfMockDelegateProtocol.self) { _ in FastMockDelegate() }
        Container.shared.register(MockExpensiveResource.self) { _ in FastMockExpensiveResource() }
    }
}

// MARK: - Mock Types for Performance Testing

protocol PerfMockRepositoryProtocol {
    func getData() -> String
}

protocol PerfMockAPIClientProtocol {
    func fetchData() -> String
}

protocol PerfMockCacheProtocol {
    func getCachedValue() -> String
}

protocol PerfMockLoggerProtocol {
    func getLogLevel() -> String
}

protocol PerfMockValidatorProtocol {
    func validateInput(_ input: String) -> String
}

protocol PerfMockDelegateProtocol: AnyObject {
    func performAction() -> Int
}

protocol PerfMockObserverProtocol: AnyObject {
    func observeEvent() -> Int
}

protocol PerfMockExpensiveResourceProtocol {
    func heavyComputation() -> String
}

// Lightweight implementations for testing
class FastMockRepository: PerfMockRepositoryProtocol {
    func getData() -> String { "data" }
}

class PerfFastMockAPIClient: PerfMockAPIClientProtocol {
    func fetchData() -> String { "fetched" }
}

class FastMockCache: PerfMockCacheProtocol {
    func getCachedValue() -> String { "cached" }
}

class PerfFastMockLogger: PerfMockLoggerProtocol {
    func getLogLevel() -> String { "info" }
}

class FastMockValidator: PerfMockValidatorProtocol {
    func validateInput(_ input: String) -> String { "valid" }
}

class FastMockDelegate: MockDelegate, PerfMockDelegateProtocol {
    func didPerformAction() {
        // Fast no-op implementation
    }

    func didReceiveValue(_ value: Int) {
        // Fast no-op implementation
    }

    func performAction() -> Int { 1 }
}

class FastMockObserver: PerfMockObserverProtocol {
    func observeEvent() -> Int { 1 }
}

class FastMockExpensiveResource: MockExpensiveResource, PerfMockExpensiveResourceProtocol {
    override init() {
        super.init()
        // Skip expensive initialization for performance tests
        isInitialized = true
    }

    override func heavyComputation() -> String { "computed" }
}
