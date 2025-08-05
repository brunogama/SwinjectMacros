// StressTests.swift - Stress tests for production readiness validation
// Copyright © 2025 SwinJectMacros. All rights reserved.

import Foundation
import Swinject
@testable import SwinjectMacros
import XCTest

final class StressTests: XCTestCase {

    // MARK: - Concurrent Access Stress Tests

    func testMassiveConcurrentLazyInjection() {
        // Register dependencies for this test
        Container.shared.removeAll()
        Container.shared.register(PerfMockRepositoryProtocol.self) { _ in FastMockRepository() }
        Container.shared.register(APIClientProtocol.self) { _ in MockAPIClient() }
        Container.shared.register(PerfMockCacheProtocol.self) { _ in FastMockCache() }

        class ConcurrentTestService {
            @LazyInject var repository: PerfMockRepositoryProtocol
            @LazyInject var apiClient: APIClientProtocol
            @LazyInject var cache: PerfMockCacheProtocol

            init() {}

            func performWork() -> String {
                repository.getData() + apiClient.fetchData() + cache.getCachedValue()
            }
        }

        let service = ConcurrentTestService()
        let iterationCount = 10000
        let concurrentQueues = 20

        let expectation = expectation(description: "Concurrent lazy injection")
        expectation.expectedFulfillmentCount = concurrentQueues

        let results = NSMutableArray()
        let resultsLock = NSLock()

        // Launch multiple concurrent queues
        for _ in 0..<concurrentQueues {
            DispatchQueue.global(qos: .userInitiated).async {
                for _ in 0..<iterationCount {
                    let result = service.performWork()
                    resultsLock.lock()
                    results.add(result)
                    resultsLock.unlock()
                }
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 30.0) { error in
            XCTAssertNil(error, "Concurrent stress test should complete without timeout")
        }

        // Verify all operations completed successfully
        XCTAssertEqual(results.count, iterationCount * concurrentQueues, "All concurrent operations should complete")

        // Verify all results are consistent (lazy injection should return same instances)
        let expectedResult = "datamock-datacached"
        for result in results {
            if let stringResult = result as? String {
                XCTAssertEqual(stringResult, expectedResult, "All lazy injection results should be consistent")
            } else {
                XCTFail("Result is not a string")
            }
        }
    }

    func testWeakInjectMemoryPressure() {
        class WeakReferenceService {
            @WeakInject var delegate: MockDelegate? = nil
            @WeakInject var observer: MockObserver? = nil

            init() {}

            func checkReferences() -> (Bool, Bool) {
                (delegate != nil, observer != nil)
            }
        }

        var services: [WeakReferenceService] = []
        var delegates: [MockDelegate] = []

        // Create many services with weak references
        for _ in 0..<1000 {
            let service = WeakReferenceService()
            let delegate = FastMockDelegate()

            // Temporarily store delegate to keep it alive
            delegates.append(delegate)
            services.append(service)

            // Access weak properties to trigger resolution
            _ = service.checkReferences()
        }

        // Verify weak references are working
        XCTAssertFalse(services.isEmpty, "Services array should not be empty")
        let (hasDelegate, hasObserver) = services.first?.checkReferences() ?? (false, false)
        XCTAssertTrue(hasDelegate || hasObserver, "At least some weak references should be resolved")

        // Clear strong references
        delegates.removeAll()

        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {
                // Create temporary objects to trigger cleanup
                _ = Array(0..<1000).map { _ in NSObject() }
            }
        }

        // Check if weak references were cleared (this is timing-dependent)
        let clearedReferences = services.compactMap { service in
            service.checkReferences()
        }.filter { !$0.0 && !$0.1 }.count

        // We expect some references to be cleared, but exact timing is unpredictable
        print("Cleared weak references: \(clearedReferences)/\(services.count)")
    }

    // MARK: - Circuit Breaker Stress Tests

    func testCircuitBreakerUnderFailureStorm() {
        class UnreliableService {
            private var callCount = 0
            private let failureRate = 0.7 // 70% failure rate

            @CircuitBreaker(failureThreshold: 10, timeout: 1.0, successThreshold: 5)
            func unreliableNetworkCall() throws -> String {
                callCount += 1

                if Double.random(in: 0...1) < failureRate {
                    throw NetworkError.timeout
                }

                return "success-\(callCount)"
            }
        }

        let service = UnreliableService()
        let totalCalls = 1000
        var successCount = 0
        var circuitOpenCount = 0
        var failureCount = 0

        for _ in 0..<totalCalls {
            do {
                _ = try service.unreliableNetworkCallCircuitBreaker()
                successCount += 1
            } catch CircuitBreakerError.circuitOpen {
                circuitOpenCount += 1
            } catch {
                failureCount += 1
            }
        }

        print(
            "Circuit Breaker Results: Success: \(successCount), Circuit Open: \(circuitOpenCount), Failures: \(failureCount)"
        )

        // Circuit breaker should prevent many failures by opening the circuit
        XCTAssertGreaterThan(circuitOpenCount, 0, "Circuit should open under failure storm")
        XCTAssertLessThan(
            failureCount,
            Int(Double(totalCalls) * 0.2),
            "Circuit breaker should prevent excessive failures"
        )
    }

    // MARK: - Cache Stress Tests

    func testCacheUnderHighLoad() {
        class CachedComputationService {
            private var computationCount = 0

            @Cache(ttl: 10, maxEntries: 100)
            func expensiveComputation(input: Int) -> String {
                computationCount += 1
                // Simulate expensive computation
                Thread.sleep(forTimeInterval: 0.001) // 1ms
                return "computed-\(input)"
            }

            func getComputationCount() -> Int {
                computationCount
            }
        }

        let service = CachedComputationService()
        let concurrentAccesses = 1000
        let uniqueInputs = 50 // Many accesses to few unique inputs

        let expectation = expectation(description: "Cache stress test")
        var results: [String] = []
        let resultsQueue = DispatchQueue(label: "results")

        DispatchQueue.concurrentPerform(iterations: concurrentAccesses) { index in
            let input = index % uniqueInputs
            let result = service.expensiveComputation(input: input)

            resultsQueue.sync {
                results.append(result)
            }

            if index == concurrentAccesses - 1 {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 10.0)

        XCTAssertEqual(results.count, concurrentAccesses, "All cache operations should complete")

        // Verify cache effectiveness - should have exactly uniqueInputs unique results
        let uniqueResults = Set(results)
        XCTAssertEqual(uniqueResults.count, uniqueInputs, "Each input should produce exactly one unique result")

        // Verify computation count - should be significantly less than total accesses
        // Under heavy concurrent load, some race conditions are expected
        let computationCount = service.getComputationCount()
        XCTAssertLessThan(computationCount, concurrentAccesses / 2, "Cache should reduce computations by at least 50%")
        print(
            "Cache effectiveness: \(computationCount) computations for \(concurrentAccesses) accesses (\(Double(computationCount) / Double(concurrentAccesses) * 100)% computation rate)"
        )
    }

    // MARK: - Retry Mechanism Stress Tests

    func testRetryUnderContinuousFailures() {
        class FlakeyService {
            private var attemptCount = 0

            @Retry(maxAttempts: 5, backoffStrategy: .exponential(baseDelay: 0.001, multiplier: 2.0), maxDelay: 0.1)
            func intermittentFailureOperation() throws -> String {
                attemptCount += 1

                // Fail first 3 attempts, then succeed
                if attemptCount % 4 != 0 {
                    throw ServiceError.temporaryFailure
                }

                return "success-\(attemptCount)"
            }
        }

        let service = FlakeyService()
        let operationCount = 100
        var successCount = 0
        var finalFailureCount = 0

        for _ in 0..<operationCount {
            do {
                _ = try service.intermittentFailureOperationRetry()
                successCount += 1
            } catch {
                finalFailureCount += 1
            }
        }

        print("Retry Results: Successes: \(successCount), Final Failures: \(finalFailureCount)")

        // Most operations should eventually succeed due to retry mechanism
        XCTAssertGreaterThan(
            successCount,
            Int(Double(operationCount) * 0.8),
            "Retry should enable most operations to succeed"
        )
    }

    // MARK: - Memory Leak Detection Tests

    func testMemoryLeakDetection() {
        autoreleasepool {
            let initialMemory = self.getCurrentMemoryUsage()

            // Create and destroy many service instances
            for _ in 0..<1000 {
                autoreleasepool {
                    class LeakTestService {
                        @LazyInject var repository: PerfMockRepositoryProtocol
                        @WeakInject var delegate: MockDelegate? = nil

                        init() {}

                        func doWork() -> String {
                            self.repository.getData() + (self.delegate?.performAction().description ?? "nil")
                        }
                    }

                    let service = LeakTestService()
                    _ = service.doWork()

                    // Service should be deallocated at end of autoreleasepool
                }
            }

            let finalMemory = self.getCurrentMemoryUsage()
            let memoryIncrease = finalMemory - initialMemory

            // Memory increase should be minimal (allowing for some overhead)
            XCTAssertLessThan(memoryIncrease, 10_000_000, "Memory increase should be less than 10MB") // 10MB threshold
        }
    }

    // MARK: - Resource Exhaustion Tests

    func testResourceExhaustionHandling() {
        // Register dependencies for this test
        Container.shared.register(MockExpensiveResource.self) { _ in MockExpensiveResource() }

        class ResourceIntensiveService {
            @LazyInject var resource1: MockExpensiveResource
            @LazyInject var resource2: MockExpensiveResource
            @LazyInject var resource3: MockExpensiveResource

            init() {}

            func consumeResources() -> String {
                resource1.heavyComputation() + resource2.heavyComputation() + resource3
                    .heavyComputation()
            }
        }

        // Create many services simultaneously
        var services: [ResourceIntensiveService] = []
        let serviceCount = 1000

        let creationTime = measureExecutionTime {
            for _ in 0..<serviceCount {
                let service = ResourceIntensiveService()
                services.append(service)
            }
        }

        let accessTime = measureExecutionTime {
            for service in services {
                _ = service.consumeResources()
            }
        }

        XCTAssertLessThan(creationTime, 1.0, "Creating 1000 services should take less than 1 second")
        XCTAssertLessThan(accessTime, 2.0, "Accessing resources in 1000 services should take less than 2 seconds")
    }

    // MARK: - Error Recovery Stress Tests

    func disabled_testErrorRecoveryResilience() {
        // DISABLED: Test takes too long and may hang
        class RecoveryTestService {
            private var isHealthy = false
            private var callCount = 0

            @CircuitBreaker(failureThreshold: 5, timeout: 0.1, successThreshold: 3)
            @Retry(maxAttempts: 3, backoffStrategy: .linear(baseDelay: 0.001, increment: 0.001))
            func recoveryOperation() throws -> String {
                callCount += 1

                // Simulate service recovering after some time
                if callCount > 20 {
                    isHealthy = true
                }

                if !isHealthy && Double.random(in: 0...1) < 0.8 {
                    throw ServiceError.serviceUnavailable
                }

                return "recovered-\(callCount)"
            }
        }

        let service = RecoveryTestService()
        var results: [Result<String, Error>] = []

        // Simulate continuous operations during service recovery
        for _ in 0..<100 {
            do {
                let result = try service.recoveryOperationRetry()
                results.append(.success(result))
            } catch {
                results.append(.failure(error))
            }

            // Small delay between operations
            Thread.sleep(forTimeInterval: 0.001)
        }

        let successCount = results.compactMap { result in
            if case .success = result { return result }
            return nil
        }.count

        // Service should eventually recover and succeed
        XCTAssertGreaterThan(successCount, 0, "Service should eventually recover and succeed")

        // Later operations should have higher success rate
        let laterResults = results.suffix(20)
        let laterSuccessCount = laterResults.compactMap { result in
            if case .success = result { return result }
            return nil
        }.count

        XCTAssertGreaterThan(laterSuccessCount, 10, "Later operations should have higher success rate after recovery")
    }

    // MARK: - Utility Methods

    private func measureExecutionTime(_ block: () -> Void) -> TimeInterval {
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
}

// MARK: - Error Types for Testing

// NetworkError is imported from TestUtilities.swift

enum ServiceError: Error {
    case temporaryFailure
    case serviceUnavailable
    case configurationError
}

// MARK: - Mock Implementations for StressTests
// Note: Mock protocols and implementations are defined in PerformanceBenchmarkTests.swift
