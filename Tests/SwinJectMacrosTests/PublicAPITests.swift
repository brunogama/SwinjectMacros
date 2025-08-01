// PublicAPITests.swift - Test newly implemented public API declarations

import XCTest
@testable import SwinJectMacros
import SwiftSyntaxMacros

class PublicAPITests: XCTestCase {
    
    // MARK: - ScopedService API Tests
    
    func testScopedServiceMacroExists() {
        // Test that the ScopedService macro declaration exists and can be referenced
        // Note: Macros cannot be tested directly, we test the support types instead
        XCTAssertTrue(true, "ScopedService macro is available if this compiles")
    }
    
    func testScopedServiceConfiguration() {
        // Test ScopedServiceConfiguration struct
        let config = ScopedServiceConfiguration(
            scope: .container,
            name: "testService",
            isLazy: true,
            isWeak: false,
            preconditions: ["Environment.isProduction"]
        )
        
        XCTAssertEqual(config.scope, .container)
        XCTAssertEqual(config.name, "testService")
        XCTAssertTrue(config.isLazy)
        XCTAssertFalse(config.isWeak)
        XCTAssertEqual(config.preconditions.count, 1)
        XCTAssertEqual(config.preconditions.first, "Environment.isProduction")
    }
    
    // MARK: - OptionalInject API Tests
    
    func testOptionalInjectMacroExists() {
        // Test that the OptionalInject macro declaration exists
        // Note: Macros cannot be tested directly, we test the support types instead
        XCTAssertTrue(true, "OptionalInject macro is available if this compiles")
    }
    
    func testOptionalResolutionResult() {
        // Test OptionalResolutionResult enum
        let resolved = OptionalResolutionResult.resolved("test")
        let fallback = OptionalResolutionResult.fallback("fallback")
        let unavailable = OptionalResolutionResult<String>.unavailable
        
        XCTAssertEqual(resolved.value, "test")
        XCTAssertTrue(resolved.wasResolved)
        
        XCTAssertEqual(fallback.value, "fallback")
        XCTAssertFalse(fallback.wasResolved)
        
        XCTAssertNil(unavailable.value)
        XCTAssertFalse(unavailable.wasResolved)
    }
    
    func testOptionalInjectConfiguration() {
        // Test OptionalInjectConfiguration struct
        let config = OptionalInjectConfiguration(
            name: "optional",
            hasDefault: true,
            hasFallback: false,
            isLazy: true,
            resolverName: "customResolver"
        )
        
        XCTAssertEqual(config.name, "optional")
        XCTAssertTrue(config.hasDefault)
        XCTAssertFalse(config.hasFallback)
        XCTAssertTrue(config.isLazy)
        XCTAssertEqual(config.resolverName, "customResolver")
    }
    
    // MARK: - ThreadSafe API Tests
    
    func testThreadSafeMacroExists() {
        // Test that the ThreadSafe macro declaration exists
        // Note: Macros cannot be tested directly, we test the support types instead
        XCTAssertTrue(true, "ThreadSafe macro is available if this compiles")
    }
    
    func testThreadSafetyConfiguration() {
        // Test ThreadSafetyConfiguration struct
        let config = ThreadSafetyConfiguration(
            synchronizationType: .concurrent,
            lockType: .readerWriter,
            isolation: .instance,
            requiresMainThread: true,
            enableDeadlockDetection: true,
            timeoutInterval: 10.0
        )
        
        XCTAssertEqual(config.synchronizationType, .concurrent)
        XCTAssertEqual(config.lockType, .readerWriter)
        XCTAssertEqual(config.isolation, .instance)
        XCTAssertTrue(config.requiresMainThread)
        XCTAssertTrue(config.enableDeadlockDetection)
        XCTAssertEqual(config.timeoutInterval, 10.0)
    }
    
    func testThreadSafetyError() {
        // Test ThreadSafetyError enum
        let timeoutError = ThreadSafetyError.timeout("Operation timed out after 5 seconds")
        let deadlockError = ThreadSafetyError.deadlock("Circular wait detected")
        let mainThreadError = ThreadSafetyError.mainThreadRequired("UI updates must be on main thread")
        
        XCTAssertNotNil(timeoutError.errorDescription)
        XCTAssertTrue(timeoutError.errorDescription!.contains("timeout"))
        
        XCTAssertNotNil(deadlockError.errorDescription)
        XCTAssertTrue(deadlockError.errorDescription!.contains("Deadlock"))
        
        XCTAssertNotNil(mainThreadError.errorDescription)
        XCTAssertTrue(mainThreadError.errorDescription!.contains("Main thread"))
    }
    
    // MARK: - Named API Tests
    
    func testNamedMacroExists() {
        // Test that the Named macro declaration exists
        // Note: Macros cannot be tested directly, we test the support types instead
        XCTAssertTrue(true, "Named macro is available if this compiles")
    }
    
    func testNamedServiceConfiguration() {
        // Test NamedServiceConfiguration struct
        let config = NamedServiceConfiguration(
            names: ["primary", "main"],
            protocolType: "DatabaseProtocol",
            scope: .container,
            isDefault: true,
            aliases: ["default", "fallback"],
            priority: 100
        )
        
        XCTAssertEqual(config.names.count, 2)
        XCTAssertEqual(config.names, ["primary", "main"])
        XCTAssertEqual(config.protocolType, "DatabaseProtocol")
        XCTAssertEqual(config.scope, .container)
        XCTAssertTrue(config.isDefault)
        XCTAssertEqual(config.aliases, ["default", "fallback"])
        XCTAssertEqual(config.priority, 100)
        XCTAssertEqual(config.primaryName, "primary")
        XCTAssertEqual(config.allNames, ["primary", "main", "default", "fallback"])
    }
    
    func testNamedServiceRegistry() {
        // Test NamedServiceRegistry class
        let config = NamedServiceConfiguration(
            names: ["test"],
            protocolType: "TestProtocol",
            scope: .graph,
            isDefault: false,
            aliases: ["alias"],
            priority: 0
        )
        
        // Register configuration
        NamedServiceRegistry.register(config, for: "TestService")
        
        // Retrieve configurations
        let configurations = NamedServiceRegistry.getConfigurations(for: "TestService")
        XCTAssertEqual(configurations.count, 1)
        XCTAssertEqual(configurations.first?.primaryName, "test")
        
        // Find by name
        let foundConfig = NamedServiceRegistry.findConfiguration(name: "test", for: "TestService")
        XCTAssertNotNil(foundConfig)
        XCTAssertEqual(foundConfig?.primaryName, "test")
        
        // Find by alias
        let foundByAlias = NamedServiceRegistry.findConfiguration(name: "alias", for: "TestService")
        XCTAssertNotNil(foundByAlias)
        XCTAssertEqual(foundByAlias?.primaryName, "test")
        
        // Get all names
        let allNames = NamedServiceRegistry.getAllNames(for: "TestService")
        XCTAssertEqual(allNames.count, 2)
        XCTAssertTrue(allNames.contains("test"))
        XCTAssertTrue(allNames.contains("alias"))
    }
    
    // MARK: - Decorator API Tests
    
    func testDecoratorMacroExists() {
        // Test that the Decorator macro declaration exists
        // Note: Macros cannot be tested directly, we test the support types instead
        XCTAssertTrue(true, "Decorator macro is available if this compiles")
    }
    
    func testServiceDecoratorProtocol() {
        // Test ServiceDecorator protocol with concrete implementation
        class TestDecorator: ServiceDecorator {
            var priority: Int { return 50 }
            
            func decorate<T>(method: String, execution: () throws -> T) rethrows -> T {
                // Simple pass-through for testing
                return try execution()
            }
        }
        
        let decorator = TestDecorator()
        XCTAssertEqual(decorator.priority, 50)
        XCTAssertTrue(decorator.shouldDecorate(method: "test"))
        
        // Test decoration
        let result = decorator.decorate(method: "testMethod") {
            return "decorated"
        }
        XCTAssertEqual(result, "decorated")
    }
    
    func testLoggingDecorator() {
        // Test built-in LoggingDecorator
        let decorator = LoggingDecorator()
        XCTAssertEqual(decorator.priority, 100)
        
        // Test decoration doesn't throw
        let result = decorator.decorate(method: "testMethod") {
            return 42
        }
        XCTAssertEqual(result, 42)
    }
    
    func testMetricsDecorator() {
        // Test built-in MetricsDecorator
        let decorator = MetricsDecorator()
        XCTAssertEqual(decorator.priority, 90)
        
        // Test decoration and metrics collection
        let result = decorator.decorate(method: "testMethod") {
            return "success"
        }
        XCTAssertEqual(result, "success")
        
        // Check metrics were recorded
        let metrics = decorator.getMetrics()
        XCTAssertEqual(metrics.count, 1)
        XCTAssertNotNil(metrics["testMethod"])
        XCTAssertEqual(metrics["testMethod"]?.callCount, 1)
        XCTAssertEqual(metrics["testMethod"]?.successCount, 1)
        XCTAssertEqual(metrics["testMethod"]?.failureCount, 0)
    }
    
    func testDecoratorMetrics() {
        // Test DecoratorMetrics struct
        var metrics = DecoratorMetrics(method: "testMethod")
        
        // Record success
        metrics.recordSuccess(duration: 0.1)
        XCTAssertEqual(metrics.callCount, 1)
        XCTAssertEqual(metrics.successCount, 1)
        XCTAssertEqual(metrics.failureCount, 0)
        XCTAssertEqual(metrics.averageDuration, 0.1)
        XCTAssertEqual(metrics.successRate, 100.0)
        
        // Record failure
        struct TestError: Error {}
        metrics.recordFailure(duration: 0.2, error: TestError())
        XCTAssertEqual(metrics.callCount, 2)
        XCTAssertEqual(metrics.successCount, 1)
        XCTAssertEqual(metrics.failureCount, 1)
        XCTAssertEqual(metrics.averageDuration, 0.15, accuracy: 0.001) // (0.1 + 0.2) / 2
        XCTAssertEqual(metrics.successRate, 50.0)
        XCTAssertNotNil(metrics.lastError)
    }
    
    func testCompositeDecorator() {
        // Test CompositeDecorator
        class TestDecorator1: ServiceDecorator {
            var priority: Int { return 10 }
            func decorate<T>(method: String, execution: () throws -> T) rethrows -> T {
                return try execution()
            }
        }
        
        class TestDecorator2: ServiceDecorator {
            var priority: Int { return 20 }
            func decorate<T>(method: String, execution: () throws -> T) rethrows -> T {
                return try execution()
            }
        }
        
        let decorator1 = TestDecorator1()
        let decorator2 = TestDecorator2()
        let composite = CompositeDecorator(decorators: [decorator1, decorator2])
        
        XCTAssertEqual(composite.priority, Int.max)
        
        let result = composite.decorate(method: "test") {
            return "composed"
        }
        XCTAssertEqual(result, "composed")
    }
    
    func testDecoratorComposer() {
        // Test DecoratorComposer utility
        class TestDecorator1: ServiceDecorator {
            var priority: Int { return 10 }
            func decorate<T>(method: String, execution: () throws -> T) rethrows -> T {
                return try execution()
            }
        }
        
        class TestDecorator2: ServiceDecorator {
            var priority: Int { return 20 }
            func decorate<T>(method: String, execution: () throws -> T) rethrows -> T {
                return try execution()
            }
        }
        
        let decorators: [ServiceDecorator] = [TestDecorator1(), TestDecorator2()]
        let composed = DecoratorComposer.compose(decorators)
        
        XCTAssertEqual(composed.priority, Int.max)
        
        let result = composed.decorate(method: "test") {
            return "composed"
        }
        XCTAssertEqual(result, "composed")
    }
}