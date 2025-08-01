// PerformanceBenchmarkTests.swift - Performance benchmarks for production readiness
// Copyright © 2025 SwinJectMacros. All rights reserved.

import XCTest
import Foundation
import Swinject
@testable import SwinjectUtilityMacros

final class PerformanceBenchmarkTests: XCTestCase {
    
    // MARK: - LazyInject Performance Tests
    
    func testLazyInjectResolutionPerformance() {
        // Simulate a service with lazy injection
        class BenchmarkService {
            @LazyInject var repository: MockRepository = FastMockRepository()
            @LazyInject var apiClient: MockAPIClient = FastMockAPIClient()
            @LazyInject var cache: MockCache = FastMockCache()
            @LazyInject var logger: MockLogger = FastMockLogger()
            @LazyInject var validator: MockValidator = FastMockValidator()
            
            init() {}
            
            func performOperation() -> String {
                return repository.getData() + apiClient.fetchData() + cache.getCachedValue() + logger.getLogLevel() + validator.validateInput("test")
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
        XCTAssertLessThan(warmStartTime, coldStartTime / 10.0, "Lazy injection should be significantly faster after first resolution")
        
        // Absolute performance requirements
        XCTAssertLessThan(coldStartTime, 0.001, "Cold start should be under 1ms") // 1ms
        XCTAssertLessThan(warmStartTime, 0.0001, "Warm start should be under 0.1ms") // 0.1ms
    }
    
    func testConcurrentLazyInjectPerformance() {
        class ConcurrentService {
            @LazyInject var sharedResource: MockExpensiveResource = FastMockExpensiveResource()
            
            init() {}
            
            func accessResource() -> String {
                return sharedResource.heavyComputation()
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
                return (delegate?.performAction() ?? 0) + (observer?.observeEvent() ?? 0)
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
        XCTAssertLessThan(cacheHitTime, cacheMissTime / 100.0, "Cache hit should be at least 100x faster than cache miss")
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
            @LazyInject var service1: MockRepository = FastMockRepository()
            @LazyInject var service2: MockAPIClient = FastMockAPIClient()
            @LazyInject var service3: MockCache = FastMockCache()
            @LazyInject var service4: MockLogger = FastMockLogger()
            @LazyInject var service5: MockValidator = FastMockValidator()
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
        XCTAssertLessThan(memoryIncrease, 50_000_000, "Memory increase should be less than 50MB for 1000 services") // 50MB
        XCTAssertGreaterThan(memoryReclaimed, Int64(Double(memoryIncrease) * 0.8), "At least 80% of memory should be reclaimed after cleanup")
    }
    
    // MARK: - Scalability Tests
    
    func testScalabilityWithManyDependencies() {
        // Test service with many dependencies
        class MegaService {
            @LazyInject var dep1: MockRepository = FastMockRepository()
            @LazyInject var dep2: MockAPIClient = FastMockAPIClient()
            @LazyInject var dep3: MockCache = FastMockCache()
            @LazyInject var dep4: MockLogger = FastMockLogger()
            @LazyInject var dep5: MockValidator = FastMockValidator()
            @LazyInject var dep6: MockRepository = FastMockRepository()
            @LazyInject var dep7: MockAPIClient = FastMockAPIClient()
            @LazyInject var dep8: MockCache = FastMockCache()
            @LazyInject var dep9: MockLogger = FastMockLogger()
            @LazyInject var dep10: MockValidator = FastMockValidator()
            
            init() {}
            
            func accessAllDependencies() -> String {
                return dep1.getData() + dep2.fetchData() + dep3.getCachedValue() + 
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
            @LazyInject var sharedResource: MockExpensiveResource = FastMockExpensiveResource()
            
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
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func setupMockContainer() {
        // Setup mock registrations for testing
        // This would typically be done in a test setup method
        // For now, we'll assume Container.shared is properly configured
    }
}

// MARK: - Mock Types for Performance Testing

protocol MockRepository {
    func getData() -> String
}

protocol MockAPIClient {
    func fetchData() -> String
}

protocol MockCache {
    func getCachedValue() -> String
}

protocol MockLogger {
    func getLogLevel() -> String
}

protocol MockValidator {
    func validateInput(_ input: String) -> String
}

protocol MockDelegate: AnyObject {
    func performAction() -> Int
}

protocol MockObserver: AnyObject {
    func observeEvent() -> Int
}

protocol MockExpensiveResource {
    func heavyComputation() -> String
}

// Lightweight implementations for testing
class FastMockRepository: MockRepository {
    func getData() -> String { "data" }
}

class FastMockAPIClient: MockAPIClient {
    func fetchData() -> String { "fetched" }
}

class FastMockCache: MockCache {
    func getCachedValue() -> String { "cached" }
}

class FastMockLogger: MockLogger {
    func getLogLevel() -> String { "info" }
}

class FastMockValidator: MockValidator {
    func validateInput(_ input: String) -> String { "valid" }
}

class FastMockDelegate: MockDelegate {
    func performAction() -> Int { 1 }
}

class FastMockObserver: MockObserver {
    func observeEvent() -> Int { 1 }
}

class FastMockExpensiveResource: MockExpensiveResource {
    func heavyComputation() -> String { "computed" }
}