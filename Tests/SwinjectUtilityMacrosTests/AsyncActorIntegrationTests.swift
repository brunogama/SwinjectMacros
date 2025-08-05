// AsyncActorIntegrationTests.swift - Async/actor integration edge case tests

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwinjectUtilityMacrosImplementation

final class AsyncActorIntegrationTests: XCTestCase {

    // MARK: - Actor + @LazyInject Integration

    func testLazyInjectInActor() {
        assertMacroExpansion("""
        actor UserActor {
            @LazyInject var userService: UserServiceProtocol
            @LazyInject var logger: LoggerProtocol

            func processUser(_ id: String) async -> User? {
                return await userService.getUser(id: id)
            }
        }
        """, expandedSource: """
        actor UserActor {
            @LazyInject var userService: UserServiceProtocol
            @LazyInject var logger: LoggerProtocol

            func processUser(_ id: String) async -> User? {
                return await userService.getUser(id: id)
            }
            private var _userServiceBacking: UserServiceProtocol?
            private var _userServiceOnceToken: Bool = false
            private let _userServiceOnceTokenLock = NSLock()

            private func _userServiceLazyAccessor() -> UserServiceProtocol {
                // Thread-safe lazy initialization
                _userServiceOnceTokenLock.lock()
                defer { _userServiceOnceTokenLock.unlock() }

                if !_userServiceOnceToken {
                    _userServiceOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "userService",
                        propertyType: "UserServiceProtocol",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(UserServiceProtocol.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "UserServiceProtocol")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "userService",
                                propertyType: "UserServiceProtocol",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'userService' of type 'UserServiceProtocol' could not be resolved: \\(error.localizedDescription)")
                        }

                        _userServiceBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "userService",
                            propertyType: "UserServiceProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "userService",
                            propertyType: "UserServiceProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        if true {
                            fatalError("Failed to resolve required lazy property 'userService': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _userServiceBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "userService", type: "UserServiceProtocol")
                    fatalError("Lazy property 'userService' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
            private var _loggerBacking: LoggerProtocol?
            private var _loggerOnceToken: Bool = false
            private let _loggerOnceTokenLock = NSLock()

            private func _loggerLazyAccessor() -> LoggerProtocol {
                // Thread-safe lazy initialization
                _loggerOnceTokenLock.lock()
                defer { _loggerOnceTokenLock.unlock() }

                if !_loggerOnceToken {
                    _loggerOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "logger",
                        propertyType: "LoggerProtocol",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(LoggerProtocol.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "LoggerProtocol")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "logger",
                                propertyType: "LoggerProtocol",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'logger' of type 'LoggerProtocol' could not be resolved: \\(error.localizedDescription)")
                        }

                        _loggerBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "logger",
                            propertyType: "LoggerProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "logger",
                            propertyType: "LoggerProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        if true {
                            fatalError("Failed to resolve required lazy property 'logger': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _loggerBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "logger", type: "LoggerProtocol")
                    fatalError("Lazy property 'logger' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
        }
        """, macros: testMacros)
    }

    func testMainActorLazyInject() {
        assertMacroExpansion("""
        @MainActor
        class UIService {
            @LazyInject var backgroundService: BackgroundServiceProtocol
            @LazyInject var uiUpdater: UIUpdaterProtocol

            func updateUI() async {
                let data = await backgroundService.fetchData()
                await uiUpdater.updateUI(with: data)
            }
        }
        """, expandedSource: """
        @MainActor
        class UIService {
            @LazyInject var backgroundService: BackgroundServiceProtocol
            @LazyInject var uiUpdater: UIUpdaterProtocol

            func updateUI() async {
                let data = await backgroundService.fetchData()
                await uiUpdater.updateUI(with: data)
            }
            private var _backgroundServiceBacking: BackgroundServiceProtocol?
            private var _backgroundServiceOnceToken: Bool = false
            private let _backgroundServiceOnceTokenLock = NSLock()

            private func _backgroundServiceLazyAccessor() -> BackgroundServiceProtocol {
                // Thread-safe lazy initialization
                _backgroundServiceOnceTokenLock.lock()
                defer { _backgroundServiceOnceTokenLock.unlock() }

                if !_backgroundServiceOnceToken {
                    _backgroundServiceOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "backgroundService",
                        propertyType: "BackgroundServiceProtocol",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(BackgroundServiceProtocol.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "BackgroundServiceProtocol")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "backgroundService",
                                propertyType: "BackgroundServiceProtocol",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'backgroundService' of type 'BackgroundServiceProtocol' could not be resolved: \\(error.localizedDescription)")
                        }

                        _backgroundServiceBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "backgroundService",
                            propertyType: "BackgroundServiceProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "backgroundService",
                            propertyType: "BackgroundServiceProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        if true {
                            fatalError("Failed to resolve required lazy property 'backgroundService': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _backgroundServiceBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "backgroundService", type: "BackgroundServiceProtocol")
                    fatalError("Lazy property 'backgroundService' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
            private var _uiUpdaterBacking: UIUpdaterProtocol?
            private var _uiUpdaterOnceToken: Bool = false
            private let _uiUpdaterOnceTokenLock = NSLock()

            private func _uiUpdaterLazyAccessor() -> UIUpdaterProtocol {
                // Thread-safe lazy initialization
                _uiUpdaterOnceTokenLock.lock()
                defer { _uiUpdaterOnceTokenLock.unlock() }

                if !_uiUpdaterOnceToken {
                    _uiUpdaterOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "uiUpdater",
                        propertyType: "UIUpdaterProtocol",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(UIUpdaterProtocol.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "UIUpdaterProtocol")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "uiUpdater",
                                propertyType: "UIUpdaterProtocol",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'uiUpdater' of type 'UIUpdaterProtocol' could not be resolved: \\(error.localizedDescription)")
                        }

                        _uiUpdaterBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "uiUpdater",
                            propertyType: "UIUpdaterProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "uiUpdater",
                            propertyType: "UIUpdaterProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        if true {
                            fatalError("Failed to resolve required lazy property 'uiUpdater': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _uiUpdaterBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "uiUpdater", type: "UIUpdaterProtocol")
                    fatalError("Lazy property 'uiUpdater' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
        }
        """, macros: testMacros)
    }

    // MARK: - @Injectable with Async Initializers (Conceptual)

    func testInjectableWithAsyncInitializer() {
        // Note: This tests what would happen if someone tried to use @Injectable
        // with an async init - the macro should handle this gracefully
        assertMacroExpansion("""
        @Injectable
        class AsyncInitService {
            private let database: DatabaseProtocol

            init(database: DatabaseProtocol) async throws {
                self.database = database
                try await database.connect()
            }
        }
        """, expandedSource: """
        class AsyncInitService {
            private let database: DatabaseProtocol

            init(database: DatabaseProtocol) async throws {
                self.database = database
                try await database.connect()
            }

            static func register(in container: Container) {
                container.register(AsyncInitService.self) { resolver in
                    AsyncInitService(
                        database: resolver.synchronizedResolve(DatabaseProtocol.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension AsyncInitService: Injectable {
        }
        """, macros: testMacros)
        // Note: This generates code that won't compile since the init is async
        // but the registration is sync. This is expected behavior - the macro
        // should emit a diagnostic warning in a real implementation.
    }

    // MARK: - Async Method Testing with AOP Macros

    func testRetryWithTaskCancellation() {
        assertMacroExpansion("""
        class NetworkService {
            @Retry(maxAttempts: 3)
            func fetchDataWithCancellation() async throws -> Data {
                try Task.checkCancellation()
                return Data()
            }
        }
        """, expandedSource: """
        class NetworkService {
            @Retry(maxAttempts: 3)
            func fetchDataWithCancellation() async throws -> Data {
                try Task.checkCancellation()
                return Data()
            }

            public func fetchDataWithCancellationRetry() async throws -> Data {
                let methodKey = "\\(String(describing: type(of: self))).fetchDataWithCancellation"
                var lastError: Error?
                var totalDelay: TimeInterval = 0.0

                for attempt in 1...3 {

                    do {
                        let result = try await fetchDataWithCancellation()

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: totalDelay
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 3 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: totalDelay,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Add to total delay tracking
                        totalDelay += delay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 3)
            }
        }
        """, macros: testMacros)
    }

    func testCircuitBreakerWithAsyncMethod() {
        assertMacroExpansion("""
        class APIService {
            @CircuitBreaker(failureThreshold: 5, timeout: 10.0)
            func callExternalAPI() async throws -> APIResponse {
                // Simulate API call
                try await Task.sleep(nanoseconds: 100_000_000)
                return APIResponse(data: "success")
            }
        }
        """, expandedSource: """
        class APIService {
            @CircuitBreaker(failureThreshold: 5, timeout: 10.0)
            func callExternalAPI() async throws -> APIResponse {
                // Simulate API call
                try await Task.sleep(nanoseconds: 100_000_000)
                return APIResponse(data: "success")
            }

            public func callExternalAPICircuitBreaker() async throws -> APIResponse {
                let circuitKey = "\\(String(describing: type(of: self))).callExternalAPI"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 5,
                    timeout: 10.0,
                    successThreshold: 3,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    throw CircuitBreakerError.circuitOpen(circuitName: circuitKey, lastFailureTime: circuitBreaker.lastOpenedTime)
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = try await callExternalAPI()
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)

                    return result
                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Complex Async + Dependency Injection Scenarios

    func testAsyncServiceWithLazyDependencies() {
        assertMacroExpansion("""
        class AsyncDataService {
            @LazyInject var repository: AsyncRepositoryProtocol
            @LazyInject var validator: AsyncValidatorProtocol
            @WeakInject var delegate: AsyncServiceDelegate?

            @Retry(maxAttempts: 2)
            @CircuitBreaker(failureThreshold: 3)
            @Cache(ttl: 60)
            func processDataFlow(_ input: String) async throws -> ProcessedResult {
                // Validate input
                try await validator.validate(input)

                // Retrieve data from repository
                let rawData = try await repository.fetchRawData(for: input)

                // Process and return
                let result = ProcessedResult(data: rawData.processed)

                // Notify delegate asynchronously
                Task {
                    await delegate?.didProcessData(result)
                }

                return result
            }
        }
        """, expandedSource: """
        class AsyncDataService {
            @LazyInject var repository: AsyncRepositoryProtocol
            @LazyInject var validator: AsyncValidatorProtocol
            @WeakInject var delegate: AsyncServiceDelegate?

            @Retry(maxAttempts: 2)
            @CircuitBreaker(failureThreshold: 3)
            @Cache(ttl: 60)
            func processDataFlow(_ input: String) async throws -> ProcessedResult {
                // Validate input
                try await validator.validate(input)

                // Retrieve data from repository
                let rawData = try await repository.fetchRawData(for: input)

                // Process and return
                let result = ProcessedResult(data: rawData.processed)

                // Notify delegate asynchronously
                Task {
                    await delegate?.didProcessData(result)
                }

                return result
            }
            private var _repositoryBacking: AsyncRepositoryProtocol?
            private var _repositoryOnceToken: Bool = false
            private let _repositoryOnceTokenLock = NSLock()

            private func _repositoryLazyAccessor() -> AsyncRepositoryProtocol {
                // Thread-safe lazy initialization
                _repositoryOnceTokenLock.lock()
                defer { _repositoryOnceTokenLock.unlock() }

                if !_repositoryOnceToken {
                    _repositoryOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "repository",
                        propertyType: "AsyncRepositoryProtocol",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(AsyncRepositoryProtocol.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "AsyncRepositoryProtocol")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "repository",
                                propertyType: "AsyncRepositoryProtocol",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'repository' of type 'AsyncRepositoryProtocol' could not be resolved: \\(error.localizedDescription)")
                        }

                        _repositoryBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "repository",
                            propertyType: "AsyncRepositoryProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "repository",
                            propertyType: "AsyncRepositoryProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        if true {
                            fatalError("Failed to resolve required lazy property 'repository': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _repositoryBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "repository", type: "AsyncRepositoryProtocol")
                    fatalError("Lazy property 'repository' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
            private var _validatorBacking: AsyncValidatorProtocol?
            private var _validatorOnceToken: Bool = false
            private let _validatorOnceTokenLock = NSLock()

            private func _validatorLazyAccessor() -> AsyncValidatorProtocol {
                // Thread-safe lazy initialization
                _validatorOnceTokenLock.lock()
                defer { _validatorOnceTokenLock.unlock() }

                if !_validatorOnceToken {
                    _validatorOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "validator",
                        propertyType: "AsyncValidatorProtocol",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(AsyncValidatorProtocol.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "AsyncValidatorProtocol")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "validator",
                                propertyType: "AsyncValidatorProtocol",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'validator' of type 'AsyncValidatorProtocol' could not be resolved: \\(error.localizedDescription)")
                        }

                        _validatorBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "validator",
                            propertyType: "AsyncValidatorProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "validator",
                            propertyType: "AsyncValidatorProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        if true {
                            fatalError("Failed to resolve required lazy property 'validator': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _validatorBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "validator", type: "AsyncValidatorProtocol")
                    fatalError("Lazy property 'validator' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
            private weak var _delegateWeakBacking: AsyncServiceDelegate?
            private var _delegateOnceToken: Bool = false
            private let _delegateOnceTokenLock = NSLock()

            private func _delegateWeakAccessor() -> AsyncServiceDelegate? {
                func resolveWeakReference() {
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = WeakPropertyInfo(
                        propertyName: "delegate",
                        propertyType: "AsyncServiceDelegate",
                        containerName: "default",
                        serviceName: nil,
                        autoResolve: true,
                        state: .pending,
                        initialResolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    WeakInjectionMetrics.recordOperation(pendingInfo)

                    do {
                        // Resolve dependency as weak reference
                        if let resolved = Container.shared.synchronizedResolve(AsyncServiceDelegate.self) {
                            _delegateWeakBacking = resolved

                            // Record successful resolution
                            let resolvedInfo = WeakPropertyInfo(
                                propertyName: "delegate",
                                propertyType: "AsyncServiceDelegate",
                                containerName: "default",
                                serviceName: nil,
                                autoResolve: true,
                                state: .resolved,
                                initialResolutionTime: Date(),
                                lastAccessTime: Date(),
                                resolutionCount: 1,
                                threadInfo: ThreadInfo()
                            )
                            WeakInjectionMetrics.recordOperation(resolvedInfo)
                        } else {
                            // Service not found - record failure
                            let error = WeakInjectionError.serviceNotRegistered(serviceName: nil, type: "AsyncServiceDelegate")

                            let failedInfo = WeakPropertyInfo(
                                propertyName: "delegate",
                                propertyType: "AsyncServiceDelegate",
                                containerName: "default",
                                serviceName: nil,
                                autoResolve: true,
                                state: .failed,
                                initialResolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            WeakInjectionMetrics.recordOperation(failedInfo)
                        }
                    } catch {
                        // Record failed resolution
                        let failedInfo = WeakPropertyInfo(
                            propertyName: "delegate",
                            propertyType: "AsyncServiceDelegate",
                            containerName: "default",
                            serviceName: nil,
                            autoResolve: true,
                            state: .failed,
                            initialResolutionTime: Date(),
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        WeakInjectionMetrics.recordOperation(failedInfo)
                    }
                }

                // Auto-resolve if reference is nil and auto-resolve is enabled
                if _delegateWeakBacking == nil {
                    _delegateOnceTokenLock.lock()
                    if !_delegateOnceToken {
                        _delegateOnceToken = true
                        _delegateOnceTokenLock.unlock()
                        resolveWeakReference()
                    } else {
                        _delegateOnceTokenLock.unlock()
                    }
                }

                // Check if reference was deallocated and record deallocation
                if _delegateWeakBacking == nil {
                    let deallocatedInfo = WeakPropertyInfo(
                        propertyName: "delegate",
                        propertyType: "AsyncServiceDelegate",
                        containerName: "default",
                        serviceName: nil,
                        autoResolve: true,
                        state: .deallocated,
                        lastAccessTime: Date(),
                        deallocationTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    WeakInjectionMetrics.recordOperation(deallocatedInfo)
                }

                return _delegateWeakBacking
            }

            public func processDataFlowRetry(_ input: String) async throws -> ProcessedResult {
                let methodKey = "\\(String(describing: type(of: self))).processDataFlow"
                var lastError: Error?
                var totalDelay: TimeInterval = 0.0

                for attempt in 1...2 {

                    do {
                        let result = try await processDataFlow(input)

                        // Record successful call
                        RetryMetricsManager.recordResult(
                            for: methodKey,
                            succeeded: true,
                            attemptCount: attempt,
                            totalDelay: totalDelay
                        )

                        return result
                    } catch {
                        lastError = error

                        // Check if this is the last attempt
                        if attempt == 2 {
                            // Record final failure
                            RetryMetricsManager.recordResult(
                                for: methodKey,
                                succeeded: false,
                                attemptCount: attempt,
                                totalDelay: totalDelay,
                                finalError: error
                            )
                            throw error
                        }

                        // Calculate backoff delay
                        let baseDelay = 1.0 * pow(2.0, Double(attempt - 1))
                        let cappedDelay = min(baseDelay, 60.0)
                        let delay = cappedDelay

                        // Add to total delay tracking
                        totalDelay += delay

                        // Record retry attempt
                        let retryAttempt = RetryAttempt(
                            attemptNumber: attempt,
                            error: error,
                            delay: delay
                        )
                        RetryMetricsManager.recordAttempt(retryAttempt, for: methodKey)

                        // Wait before retry
                        if delay > 0 {
                            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        }
                    }
                }

                // This should never be reached, but just in case
                throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 2)
            }

            public func processDataFlowCircuitBreaker(_ input: String) async throws -> ProcessedResult {
                let circuitKey = "\\(String(describing: type(of: self))).processDataFlow"

                // Get or create circuit breaker instance
                let circuitBreaker = CircuitBreakerRegistry.getCircuitBreaker(
                    for: circuitKey,
                    failureThreshold: 3,
                    timeout: 60.0,
                    successThreshold: 3,
                    monitoringWindow: 60.0
                )

                // Check if call should be allowed
                guard circuitBreaker.shouldAllowCall() else {
                    // Circuit is open, record blocked call and handle fallback
                    let blockedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: true,
                        responseTime: 0.0,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(blockedCall, for: circuitKey)

                    throw CircuitBreakerError.circuitOpen(circuitName: circuitKey, lastFailureTime: circuitBreaker.lastOpenedTime)
                }

                // Execute the method with circuit breaker protection
                let startTime = CFAbsoluteTimeGetCurrent()
                var wasSuccessful = false
                var callError: Error?

                do {
                    let result = try await processDataFlow(input)
                    wasSuccessful = true

                    // Record successful call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let successfulCall = CircuitBreakerCall(
                        wasSuccessful: true,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState
                    )
                    CircuitBreakerRegistry.recordCall(successfulCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: true)

                    return result
                } catch {
                    wasSuccessful = false
                    callError = error

                    // Record failed call
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000

                    let failedCall = CircuitBreakerCall(
                        wasSuccessful: false,
                        wasBlocked: false,
                        responseTime: responseTime,
                        circuitState: circuitBreaker.currentState,
                        error: error
                    )
                    CircuitBreakerRegistry.recordCall(failedCall, for: circuitKey)

                    // Update circuit breaker state
                    circuitBreaker.recordCall(wasSuccessful: false)

                    // Re-throw the error
                    throw error
                }
            }

            public func processDataFlowCache(_ input: String) async throws -> ProcessedResult {
                let cacheKey = "\\(String(describing: type(of: self))).processDataFlow_\\(input)"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: cacheKey,
                    maxSize: 100,
                    ttl: 60,
                    evictionPolicy: .lru
                )

                // Check cache first
                if let cachedResult = cache.get(cacheKey) as? ProcessedResult {
                    // Record cache hit
                    let cacheHit = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: 0.0,
                        valueSize: 0
                    )
                    CacheRegistry.recordOperation(cacheHit, for: cacheKey)

                    return cachedResult
                }

                // Cache miss - compute result
                let startTime = CFAbsoluteTimeGetCurrent()

                do {
                    let result = try await processDataFlow(input)

                    let endTime = CFAbsoluteTimeGetCurrent()
                    let computationTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    // Store in cache
                    cache.set(cacheKey, value: result)

                    // Record cache miss and computation
                    let cacheMiss = CacheOperation(
                        wasHit: false,
                        key: cacheKey,
                        responseTime: computationTime,
                        valueSize: MemoryLayout.size(ofValue: result)
                    )
                    CacheRegistry.recordOperation(cacheMiss, for: cacheKey)

                    return result
                } catch {
                    // Record failed computation
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let computationTime = (endTime - startTime) * 1000

                    let failedAccess = CacheOperation(
                        wasHit: false,
                        key: cacheKey,
                        responseTime: computationTime,
                        valueSize: 0,
                        error: error
                    )
                    CacheRegistry.recordOperation(failedAccess, for: cacheKey)

                    throw error
                }
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Test Utilities

    private let testMacros: [String: Macro.Type] = [
        "Injectable": InjectableMacro.self,
        "LazyInject": LazyInjectMacro.self,
        "WeakInject": WeakInjectMacro.self,
        "Retry": RetryMacro.self,
        "CircuitBreaker": CircuitBreakerMacro.self,
        "Cache": CacheMacro.self
    ]
}

// MARK: - Supporting Async Test Types

// Async protocols
protocol AsyncTestUserServiceProtocol {
    func getUser(id: String) async -> AsyncTestUser?
}

protocol AsyncTestLoggerProtocol {
    func log(_ message: String) async
}

protocol BackgroundServiceProtocol {
    func fetchData() async -> Data
}

protocol UIUpdaterProtocol {
    func updateUI(with data: Data) async
}

// DatabaseProtocol already declared in TestUtilities.swift

protocol AsyncRepositoryProtocol {
    func fetchRawData(for input: String) async throws -> RawData
}

protocol AsyncValidatorProtocol {
    func validate(_ input: String) async throws
}

@MainActor
protocol AsyncServiceDelegate: AnyObject {
    func didProcessData(_ result: ProcessedResult) async
}

// Data types
struct AsyncTestUser {
    let id: String
    let name: String
}

struct RawData {
    let raw: String
    var processed: String {
        raw.uppercased()
    }
}

struct ProcessedResult {
    let data: String
}

struct APIResponse {
    let data: String
}

// Error types
// RetryError is now imported from TestUtilities.swift

// Extended CircuitBreakerCall for async tests (extends shared type)
struct AsyncCircuitBreakerCall {
    let wasSuccessful: Bool
    let wasBlocked: Bool
    let responseTime: TimeInterval
    let circuitState: String
    let error: Error?

    init(wasSuccessful: Bool, wasBlocked: Bool, responseTime: TimeInterval, circuitState: String, error: Error? = nil) {
        self.wasSuccessful = wasSuccessful
        self.wasBlocked = wasBlocked
        self.responseTime = responseTime
        self.circuitState = circuitState
        self.error = error
    }
}

struct CacheOperation {
    let timestamp: Date
    let wasHit: Bool
    let key: String
    let responseTime: TimeInterval
    let valueSize: Int
    let error: Error?

    init(
        timestamp: Date = Date(),
        wasHit: Bool,
        key: String,
        responseTime: TimeInterval,
        valueSize: Int,
        error: Error? = nil
    ) {
        self.timestamp = timestamp
        self.wasHit = wasHit
        self.key = key
        self.responseTime = responseTime
        self.valueSize = valueSize
        self.error = error
    }
}

// Mock registries and managers (would be implemented elsewhere)
// Note: Using shared types from TestUtilities.swift

enum CacheRegistry {
    static func getCache(
        for key: String,
        ttl: TimeInterval,
        maxEntries: Int,
        evictionPolicy: CacheEvictionPolicy
    ) -> AsyncTestMockCache {
        AsyncTestMockCache()
    }

    static func recordOperation(_ operation: CacheOperation, for key: String) {}
}

enum CacheEvictionPolicy {
    case lru
}

// Using MockCircuitBreaker from TestUtilities.swift

struct AsyncTestMockCache {
    func get<T>(key: String, type: T.Type) -> T? { nil }
    func set(key: String, value: some Any) {}
}
