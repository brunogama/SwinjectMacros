// InvalidUsageTests.swift - Tests for invalid macro usage with helpful error messages
// Copyright © 2025 SwinJectMacros. All rights reserved.

import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import SwinjectUtilityMacrosImplementation

final class InvalidUsageTests: XCTestCase {
    
    // MARK: - Injectable Invalid Usage Tests
    
    func testInjectableOnExtension() {
        assertMacroExpansion("""
        @Injectable
        extension String {
            func customMethod() -> String {
                return self.uppercased()
            }
        }
        """, expandedSource: """
        extension String {
            func customMethod() -> String {
                return self.uppercased()
            }
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @Injectable can only be applied to classes or structs.
            
            ✅ Correct usage:
            @Injectable
            class UserService {
                init(repository: UserRepository) { ... }
            }
            
            ❌ Invalid usage:
            @Injectable
            enum Status { ... } // Enums not supported
            @Injectable
            protocol ServiceProtocol { ... } // Protocols not supported
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }
    
    func testInjectableOnActor() {
        assertMacroExpansion("""
        @Injectable
        actor ConcurrentService {
            init() {}
        }
        """, expandedSource: """
        actor ConcurrentService {
            init() {}
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @Injectable can only be applied to classes or structs.
            
            ✅ Correct usage:
            @Injectable
            class UserService {
                init(repository: UserRepository) { ... }
            }
            
            ❌ Invalid usage:
            @Injectable
            enum Status { ... } // Enums not supported
            @Injectable
            protocol ServiceProtocol { ... } // Protocols not supported
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }
    
    func testInjectableWithComplexInitializer() {
        // Test that Injectable handles complex initializers appropriately
        assertMacroExpansion("""
        @Injectable
        class ComplexService {
            private var data: String
            
            init() {
                self.data = "default"
                print("Initializing with default")
            }
            
            init(customData: String, formatter: DataFormatter) {
                self.data = formatter.format(customData)
                print("Initializing with custom data")
            }
            
            convenience init(simple: String) {
                self.init(customData: simple, formatter: DefaultFormatter())
            }
        }
        """, expandedSource: """
        class ComplexService {
            private var data: String
            
            init() {
                self.data = "default"
                print("Initializing with default")
            }
            
            init(customData: String, formatter: DataFormatter) {
                self.data = formatter.format(customData)
                print("Initializing with custom data")
            }
            
            convenience init(simple: String) {
                self.init(customData: simple, formatter: DefaultFormatter())
            }
            
            static func register(in container: Container) {
                container.register(ComplexService.self) { resolver in
                    ComplexService()
                }.inObjectScope(.graph)
            }
        }

        extension ComplexService: Injectable {
        }
        """, macros: testMacros)
        // Note: This should work - Injectable should pick the first non-convenience initializer
    }
    
    // MARK: - LazyInject Invalid Usage Tests
    
    func testLazyInjectOnLet() {
        assertMacroExpansion("""
        class TestService {
            @LazyInject let repository: UserRepository
        }
        """, expandedSource: """
        class TestService {
            @LazyInject let repository: UserRepository
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @LazyInject can only be applied to variable properties.
            
            ✅ Correct usage:
            class UserService {
                @LazyInject var repository: UserRepositoryProtocol
                @LazyInject("database") var dbConnection: DatabaseConnection
                @LazyInject(container: "network") var apiClient: APIClient
            }
            
            ❌ Invalid usage:
            @LazyInject
            func getRepository() -> Repository { ... } // Functions not supported
            
            @LazyInject
            let constValue = "test" // Constants not supported
            
            @LazyInject
            class MyService { ... } // Types not supported
            
            💡 Tips:
            - Use 'var' instead of 'let' for lazy properties
            - Provide explicit type annotations for better injection
            - Consider @WeakInject for optional weak references
            """, line: 2, column: 5, severity: .error)
        ], macros: testMacros)
    }
    
    func testLazyInjectWithInitializer() {
        assertMacroExpansion("""
        class TestService {
            @LazyInject var repository: UserRepository = UserRepository()
        }
        """, expandedSource: """
        class TestService {
            @LazyInject var repository: UserRepository = UserRepository()
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @LazyInject requires an explicit type annotation to determine what to inject.
            
            ✅ Correct usage:
            @LazyInject var repository: UserRepositoryProtocol
            @LazyInject var apiClient: APIClientProtocol
            @LazyInject var database: DatabaseConnection?
            
            ❌ Invalid usage:
            @LazyInject var repository // Missing type annotation
            @LazyInject var service = SomeService() // Type inferred from assignment
            
            💡 Tips:
            - Always provide explicit type annotations
            - Use protocols for better testability
            - Mark as optional if the service might not be available
            """, line: 2, column: 5, severity: .error)
        ], macros: testMacros)
        // Note: The macro should reject properties with initializers since they conflict with lazy injection
    }
    
    func testLazyInjectOnStaticProperty() {
        assertMacroExpansion("""
        class TestService {
            @LazyInject static var sharedRepository: UserRepository
        }
        """, expandedSource: """
        class TestService {
            @LazyInject static var sharedRepository: UserRepository
            
            private static var _sharedRepositoryBacking: UserRepository?
            private static var _sharedRepositoryOnceToken: Bool = false
            private static let _sharedRepositoryOnceTokenLock = NSLock()
            
            private static func _sharedRepositoryLazyAccessor() -> UserRepository {
                // Thread-safe lazy initialization
                _sharedRepositoryOnceTokenLock.lock()
                defer { _sharedRepositoryOnceTokenLock.unlock() }
                
                if !_sharedRepositoryOnceToken {
                    _sharedRepositoryOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "sharedRepository",
                        propertyType: "UserRepository",
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
                        guard let resolved = Container.shared.synchronizedResolve(UserRepository.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "UserRepository")
                            
                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "sharedRepository",
                                propertyType: "UserRepository",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)
                            
                            fatalError("Required lazy property 'sharedRepository' of type 'UserRepository' could not be resolved: \\(error.localizedDescription)")
                        }
                        
                        _sharedRepositoryBacking = resolved
                        
                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime
                        
                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "sharedRepository",
                            propertyType: "UserRepository",
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
                            propertyName: "sharedRepository",
                            propertyType: "UserRepository",
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
                            fatalError("Failed to resolve required lazy property 'sharedRepository': \\(error.localizedDescription)")
                        }
                    }
                }
                
                guard let resolvedValue = _sharedRepositoryBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "sharedRepository", type: "UserRepository")
                    fatalError("Lazy property 'sharedRepository' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
        }
        """, macros: testMacros)
        // Note: LazyInject should work on static properties too
    }
    
    // MARK: - WeakInject Invalid Usage Tests
    
    func testWeakInjectOnFunction() {
        assertMacroExpansion("""
        @WeakInject
        func getDelegate() -> ServiceDelegate? {
            return nil
        }
        """, expandedSource: """
        func getDelegate() -> ServiceDelegate? {
            return nil
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @WeakInject can only be applied to variable properties.
            
            ✅ Correct usage:
            class UserService {
                @WeakInject var repository: UserRepositoryProtocol
                @WeakInject("database") var dbConnection: DatabaseConnection
                @WeakInject(container: "network") var apiClient: APIClient
            }
            
            ❌ Invalid usage:
            @WeakInject
            func getRepository() -> Repository { ... } // Functions not supported
            
            @WeakInject
            let constValue = "test" // Constants not supported
            
            @WeakInject
            class MyService { ... } // Types not supported
            
            💡 Tips:
            - Use 'var' instead of 'let' for lazy properties
            - Provide explicit type annotations for better injection
            - Consider @WeakInject for optional weak references
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }
    
    func testWeakInjectWithImplicitlyUnwrappedOptional() {
        assertMacroExpansion("""
        class TestService {
            @WeakInject var delegate: ServiceDelegate!
        }
        """, expandedSource: """
        class TestService {
            @WeakInject var delegate: ServiceDelegate!
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @WeakInject requires an optional type because weak references must be optional.
            
            ✅ Correct usage:
            @WeakInject var delegate: UserServiceDelegate?
            @WeakInject var parent: ParentViewControllerProtocol?
            @WeakInject("cache") var cacheManager: CacheManagerProtocol?
            
            ❌ Invalid usage:
            @WeakInject var delegate: UserServiceDelegate // Missing '?' for optional
            @WeakInject var service: UserService // Non-optional type
            
            💡 Why optional is required:
            - Weak references can become nil when the referenced object is deallocated
            - This prevents strong reference cycles and memory leaks
            - Use @LazyInject instead if you need a strong reference
            
            Quick fix: Add '?' to make the type optional
            """, line: 2, column: 5, severity: .error)
        ], macros: testMacros)
        // Note: Implicitly unwrapped optionals (!) should be treated as non-optional for WeakInject purposes
    }
    
    // MARK: - Retry Invalid Usage Tests
    
    func testRetryOnInit() {
        assertMacroExpansion("""
        class TestService {
            @Retry
            init() {
                // Initialization logic that might fail
            }
        }
        """, expandedSource: """
        class TestService {
            @Retry
            init() {
                // Initialization logic that might fail
            }
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @Retry can only be applied to functions and methods.
            
            ✅ Correct usage:
            @Retry(maxAttempts: 3, backoffStrategy: .exponential)
            func fetchUserData() throws -> UserData {
                // Network operation that might fail
            }
            
            @Retry(maxAttempts: 5, jitter: true)
            func syncDatabase() async throws {
                // Async operation with retry logic
            }
            
            ❌ Invalid usage:
            @Retry
            var retryCount: Int = 0 // Properties not supported
            
            @Retry
            struct Configuration { ... } // Types not supported
            
            💡 Tips:
            - Use on throwing functions for error handling
            - Combine with async for non-blocking retries
            - Set appropriate maxAttempts for your use case
            """, line: 2, column: 5, severity: .error)
        ], macros: testMacros)
    }
    
    func testRetryOnNonThrowingFunction() {
        assertMacroExpansion("""
        @Retry
        func normalFunction() -> String {
            return "Hello"
        }
        """, expandedSource: """
        func normalFunction() -> String {
            return "Hello"
        }
        
        public func normalFunctionRetry() throws -> String {
            let methodKey = "\\(String(describing: type(of: self))).normalFunction"
            var lastError: Error?
            var totalDelay: TimeInterval = 0.0
            
            for attempt in 1...3 {
                
                do {
                    let result = normalFunction()
                    
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
                        Thread.sleep(forTimeInterval: delay)
                    }
                }
            }
            
            // This should never be reached, but just in case
            throw lastError ?? RetryError.maxAttemptsExceeded(attempts: 3)
        }
        """, macros: testMacros)
        // Note: Retry can be applied to non-throwing functions, but it makes the retry version throwing
    }
    
    // MARK: - CircuitBreaker Invalid Usage Tests
    
    func testCircuitBreakerOnProperty() {
        assertMacroExpansion("""
        @CircuitBreaker
        var networkEnabled: Bool = true
        """, expandedSource: """
        var networkEnabled: Bool = true
        """, diagnostics: [
            DiagnosticSpec(message: """
            @CircuitBreaker can only be applied to functions and methods.
            
            ✅ Correct usage:
            @CircuitBreaker(failureThreshold: 3, backoffStrategy: .exponential)
            func fetchUserData() throws -> UserData {
                // Network operation that might fail
            }
            
            @CircuitBreaker(failureThreshold: 5, jitter: true)
            func syncDatabase() async throws {
                // Async operation with retry logic
            }
            
            ❌ Invalid usage:
            @CircuitBreaker
            var retryCount: Int = 0 // Properties not supported
            
            @CircuitBreaker
            struct Configuration { ... } // Types not supported
            
            💡 Tips:
            - Use on throwing functions for error handling
            - Combine with async for non-blocking retries
            - Set appropriate maxAttempts for your use case
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }
    
    // MARK: - Cache Invalid Usage Tests
    
    func testCacheOnVoidFunction() {
        assertMacroExpansion("""
        @Cache
        func performAction() {
            print("Action performed")
        }
        """, expandedSource: """
        func performAction() {
            print("Action performed")
        }
        
        public func performActionCache() {
            let cacheKey = "\\(String(describing: type(of: self))).performAction_"
            
            // Get or create cache instance
            let cache = CacheRegistry.getCache(
                for: cacheKey,
                maxSize: 100,
                ttl: 300,
                evictionPolicy: .lru
            )
            
            // Check cache first
            if let cachedResult = cache.get(cacheKey) as? Void {
                // Record cache hit
                let cacheHit = CacheAccess(
                    key: cacheKey,
                    wasHit: true,
                    accessTime: Date(),
                    computationTime: 0.0
                )
                CacheRegistry.recordAccess(cacheHit, for: cacheKey)
                
                return cachedResult
            }
            
            // Cache miss - compute result
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                let result = performAction()
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let computationTime = (endTime - startTime) * 1000 // Convert to milliseconds
                
                // Store in cache
                cache.set(cacheKey, value: result)
                
                // Record cache miss and computation
                let cacheMiss = CacheAccess(
                    key: cacheKey,
                    wasHit: false,
                    accessTime: Date(),
                    computationTime: computationTime
                )
                CacheRegistry.recordAccess(cacheMiss, for: cacheKey)
                
                return result
            }
        }
        """, macros: testMacros)
        // Note: Cache on Void functions is technically possible but not very useful
    }
    
    // MARK: - Complex Invalid Combinations
    
    func testMultipleMacrosOnSameDeclaration() {
        assertMacroExpansion("""
        @Injectable
        @Retry
        class ServiceWithMultipleMacros {
            init() {}
        }
        """, expandedSource: """
        class ServiceWithMultipleMacros {
            init() {}
            
            static func register(in container: Container) {
                container.register(ServiceWithMultipleMacros.self) { resolver in
                    ServiceWithMultipleMacros()
                }.inObjectScope(.graph)
            }
        }

        extension ServiceWithMultipleMacros: Injectable {
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @Retry can only be applied to functions and methods.
            
            ✅ Correct usage:
            @Retry(maxAttempts: 3, backoffStrategy: .exponential)
            func fetchUserData() throws -> UserData {
                // Network operation that might fail
            }
            
            @Retry(maxAttempts: 5, jitter: true)
            func syncDatabase() async throws {
                // Async operation with retry logic
            }
            
            ❌ Invalid usage:
            @Retry
            var retryCount: Int = 0 // Properties not supported
            
            @Retry
            struct Configuration { ... } // Types not supported
            
            💡 Tips:
            - Use on throwing functions for error handling
            - Combine with async for non-blocking retries
            - Set appropriate maxAttempts for your use case
            """, line: 2, column: 1, severity: .error)
        ], macros: testMacros)
    }
    
    func testInvalidParameterValues() {
        assertMacroExpansion("""
        @Retry(maxAttempts: -5, timeout: -10.0)
        func invalidParamsFunction() throws -> String {
            return "test"
        }
        """, expandedSource: """
        func invalidParamsFunction() throws -> String {
            return "test"
        }
        
        public func invalidParamsFunctionRetry() throws -> String {
            let methodKey = "\\(String(describing: type(of: self))).invalidParamsFunction"
            var lastError: Error?
            var totalDelay: TimeInterval = 0.0
            let startTime = Date()
            let timeoutInterval: TimeInterval = -10.0
            
            for attempt in 1...-5 {
                // Check overall timeout
                if Date().timeIntervalSince(startTime) >= timeoutInterval {
                    throw RetryError.timeoutExceeded(timeout: timeoutInterval)
                }
                
                do {
                    let result = try invalidParamsFunction()
                    
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
                    if attempt == -5 {
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
                        Thread.sleep(forTimeInterval: delay)
                    }
                }
            }
            
            // This should never be reached, but just in case
            throw lastError ?? RetryError.maxAttemptsExceeded(attempts: -5)
        }
        """, macros: testMacros)
        // Note: The macro accepts invalid values - runtime validation would catch these
    }
    
    // MARK: - Test Utilities
    
    private let testMacros: [String: Macro.Type] = [
        "Injectable": InjectableMacro.self,
        "Retry": RetryMacro.self,
        "LazyInject": LazyInjectMacro.self,
        "WeakInject": WeakInjectMacro.self,
        "CircuitBreaker": CircuitBreakerMacro.self,
        "Cache": CacheMacro.self
    ]
}

// MARK: - Supporting Types for Invalid Usage Tests

protocol DataFormatter {
    func format(_ input: String) -> String
}

class DefaultFormatter: DataFormatter {
    func format(_ input: String) -> String {
        return input.uppercased()
    }
}

class TestUserRepository {
    func findUser(id: String) -> String? {
        return "User-\(id)"
    }
}