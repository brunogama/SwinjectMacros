// APIValidationTests.swift - Tests to validate generated code compiles against actual Swinject API
// Copyright © 2025 SwinJectMacros. All rights reserved.

import XCTest
import Swinject
@testable import SwinjectUtilityMacros

final class APIValidationTests: XCTestCase {
    
    var container: Container!
    var assembler: Assembler!
    
    override func setUp() {
        super.setUp()
        container = Container()
        assembler = Assembler([], container: container)
    }
    
    override func tearDown() {
        container = nil
        assembler = nil
        super.tearDown()
    }
    
    // MARK: - Swinject API Validation
    
    func testGeneratedCodeUsesCorrectResolverAPI() {
        // Verify that generated code uses resolver.resolve() not resolver.synchronizedResolve()
        @Injectable
        class APIValidationService {
            let dependency: TestDependency
            
            init(dependency: TestDependency) {
                self.dependency = dependency
            }
        }
        
        // Register dependency
        container.register(TestDependency.self) { _ in
            TestDependency()
        }
        
        // This should work if the generated code uses correct API
        APIValidationService.register(in: container)
        
        let service = container.resolve(APIValidationService.self)
        XCTAssertNotNil(service, "Service should resolve with correct Swinject API")
        XCTAssertNotNil(service?.dependency, "Dependency should be injected")
    }
    
    func testSwinjectObjectScopesWork() {
        @Injectable(scope: .container)
        class ContainerScopedService {
            let id = UUID()
            init() {}
        }
        
        @Injectable(scope: .graph)
        class GraphScopedService {
            let id = UUID()
            init() {}
        }
        
        ContainerScopedService.register(in: container)
        GraphScopedService.register(in: container)
        
        // Container scope - should be same instance
        let containerService1 = container.resolve(ContainerScopedService.self)
        let containerService2 = container.resolve(ContainerScopedService.self)
        XCTAssertNotNil(containerService1)
        XCTAssertNotNil(containerService2)
        XCTAssertEqual(containerService1?.id, containerService2?.id)
        
        // Graph scope - should be different instances (in this test context)
        let graphService1 = container.resolve(GraphScopedService.self)
        let graphService2 = container.resolve(GraphScopedService.self)
        XCTAssertNotNil(graphService1)
        XCTAssertNotNil(graphService2)
        // Note: Graph scope behavior depends on resolution context
    }
    
    func testNamedServiceRegistration() {
        @Injectable(name: "primary")
        class PrimaryService {
            let value: String = "primary"
            init() {}
        }
        
        @Injectable(name: "secondary")
        class SecondaryService {
            let value: String = "secondary"
            init() {}
        }
        
        PrimaryService.register(in: container)
        SecondaryService.register(in: container)
        
        let primaryService = container.resolve(PrimaryService.self, name: "primary")
        let secondaryService = container.resolve(SecondaryService.self, name: "secondary")
        let unnamedService = container.resolve(PrimaryService.self)
        
        XCTAssertNotNil(primaryService)
        XCTAssertNotNil(secondaryService)
        XCTAssertNil(unnamedService, "Unnamed resolution should fail for named service")
        XCTAssertEqual(primaryService?.value, "primary")
        XCTAssertEqual(secondaryService?.value, "secondary")
    }
    
    func testOptionalDependencyResolution() {
        @Injectable
        class OptionalDependencyService {
            let required: TestDependency
            let optional: OptionalTestDependency?
            
            init(required: TestDependency, optional: OptionalTestDependency?) {
                self.required = required
                self.optional = optional
            }
        }
        
        // Register only required dependency
        container.register(TestDependency.self) { _ in TestDependency() }
        // Intentionally don't register OptionalTestDependency
        
        OptionalDependencyService.register(in: container)
        
        let service = container.resolve(OptionalDependencyService.self)
        XCTAssertNotNil(service)
        XCTAssertNotNil(service?.required)
        XCTAssertNil(service?.optional, "Optional dependency should be nil when not registered")
    }
    
    // MARK: - Factory API Validation
    
    func testAutoFactoryIntegrationWithSwinject() {
        @AutoFactory
        class FactoryTestService {
            let dependency: TestDependency
            let runtimeParam: String
            
            init(dependency: TestDependency, runtimeParam: String) {
                self.dependency = dependency
                self.runtimeParam = runtimeParam
            }
        }
        
        // Register dependency and factory
        container.register(TestDependency.self) { _ in TestDependency() }
        container.register(FactoryTestServiceFactory.self) { resolver in
            FactoryTestServiceFactoryImpl(resolver: resolver)
        }
        
        let factory = container.resolve(FactoryTestServiceFactory.self)
        XCTAssertNotNil(factory, "Factory should resolve from container")
        
        let service = factory?.makeFactoryTestService(runtimeParam: "test")
        XCTAssertNotNil(service)
        XCTAssertNotNil(service?.dependency)
        XCTAssertEqual(service?.runtimeParam, "test")
    }
    
    func testFactoryWithMultipleRuntimeParameters() {
        @AutoFactory
        class MultiParamFactoryService {
            let dependency: TestDependency
            let param1: String
            let param2: Int
            let param3: Bool
            
            init(dependency: TestDependency, param1: String, param2: Int, param3: Bool) {
                self.dependency = dependency
                self.param1 = param1
                self.param2 = param2
                self.param3 = param3
            }
        }
        
        container.register(TestDependency.self) { _ in TestDependency() }
        container.register(MultiParamFactoryServiceFactory.self) { resolver in
            MultiParamFactoryServiceFactoryImpl(resolver: resolver)
        }
        
        let factory = container.resolve(MultiParamFactoryServiceFactory.self)
        let service = factory?.makeMultiParamFactoryService(param1: "test", param2: 42, param3: true)
        
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.param1, "test")
        XCTAssertEqual(service?.param2, 42)
        XCTAssertEqual(service?.param3, true)
    }
    
    // MARK: - Assembly Integration
    
    func testAssemblyIntegration() {
        class TestAssembly: Assembly {
            func assemble(container: Container) {
                // Register dependencies
                container.register(TestDependency.self) { _ in TestDependency() }
                container.register(OptionalTestDependency.self) { _ in OptionalTestDependency() }
                
                // Register @Injectable services
                TestServiceWithDependencies.register(in: container)
                
                // Register factories
                container.register(TestFactoryServiceFactory.self) { resolver in
                    TestFactoryServiceFactoryImpl(resolver: resolver)
                }
            }
        }
        
        @Injectable
        class TestServiceWithDependencies {
            let dependency: TestDependency
            let optional: OptionalTestDependency?
            
            init(dependency: TestDependency, optional: OptionalTestDependency?) {
                self.dependency = dependency
                self.optional = optional
            }
        }
        
        @AutoFactory
        class TestFactoryService {
            let dependency: TestDependency
            let value: String
            
            init(dependency: TestDependency, value: String) {
                self.dependency = dependency
                self.value = value
            }
        }
        
        let testContainer = Container()
        let testAssembler = Assembler([TestAssembly()], container: testContainer)
        
        // Test regular service
        let service = testContainer.resolve(TestServiceWithDependencies.self)
        XCTAssertNotNil(service)
        XCTAssertNotNil(service?.dependency)
        XCTAssertNotNil(service?.optional)
        
        // Test factory service
        let factory = testContainer.resolve(TestFactoryServiceFactory.self)
        XCTAssertNotNil(factory)
        
        let factoryService = factory?.makeTestFactoryService(value: "factory test")
        XCTAssertNotNil(factoryService)
        XCTAssertEqual(factoryService?.value, "factory test")
    }
    
    // MARK: - Protocol Registration Validation
    
    func testProtocolAndConcreteRegistration() {
        protocol TestServiceProtocol {
            var identifier: String { get }
        }
        
        @Injectable
        class ConcreteTestService: TestServiceProtocol {
            let identifier = "concrete"
            let dependency: TestDependency
            
            init(dependency: TestDependency) {
                self.dependency = dependency
            }
        }
        
        container.register(TestDependency.self) { _ in TestDependency() }
        ConcreteTestService.register(in: container)
        
        // Register protocol separately (macro doesn't do this automatically)
        container.register(TestServiceProtocol.self) { resolver in
            resolver.resolve(ConcreteTestService.self)!
        }
        
        let concreteService = container.resolve(ConcreteTestService.self)
        let protocolService = container.resolve(TestServiceProtocol.self)
        
        XCTAssertNotNil(concreteService)
        XCTAssertNotNil(protocolService)
        XCTAssertEqual(protocolService?.identifier, "concrete")
        XCTAssertTrue(protocolService is ConcreteTestService)
    }
    
    // MARK: - Generic Type Registration
    
    func testGenericServiceRegistration() {
        @Injectable
        class GenericService<T> {
            let dependency: TestDependency
            let value: T
            
            init(dependency: TestDependency, value: T) {
                self.dependency = dependency
                self.value = value
            }
        }
        
        container.register(TestDependency.self) { _ in TestDependency() }
        
        // Register specific generic instantiation
        container.register(GenericService<String>.self) { resolver in
            GenericService(
                dependency: resolver.resolve(TestDependency.self)!,
                value: "test string"
            )
        }
        
        let stringService = container.resolve(GenericService<String>.self)
        XCTAssertNotNil(stringService)
        XCTAssertEqual(stringService?.value, "test string")
    }
    
    // MARK: - Error Scenarios Validation
    
    func testMissingDependencyFailure() {
        @Injectable
        class ServiceWithMissingDep {
            let dependency: MissingDependency
            
            init(dependency: MissingDependency) {
                self.dependency = dependency
            }
        }
        
        // Don't register MissingDependency
        ServiceWithMissingDep.register(in: container)
        
        let service = container.resolve(ServiceWithMissingDep.self)
        XCTAssertNil(service, "Service should fail to resolve when dependency is missing")
    }
    
    func testCircularDependencyBehavior() {
        @Injectable
        class ServiceA {
            let serviceB: ServiceB
            
            init(serviceB: ServiceB) {
                self.serviceB = serviceB
            }
        }
        
        @Injectable
        class ServiceB {
            let serviceA: ServiceA
            
            init(serviceA: ServiceA) {
                self.serviceA = serviceA
            }
        }
        
        ServiceA.register(in: container)
        ServiceB.register(in: container)
        
        // Swinject should handle circular dependencies according to its rules
        let serviceA = container.resolve(ServiceA.self)
        XCTAssertNil(serviceA, "Circular dependency should fail gracefully")
    }
    
    // MARK: - Thread Safety Validation
    
    func testConcurrentResolution() {
        @Injectable(scope: .container)
        class ThreadSafeService {
            let id = UUID()
            let dependency: TestDependency
            
            init(dependency: TestDependency) {
                self.dependency = dependency
            }
        }
        
        container.register(TestDependency.self) { _ in TestDependency() }
        ThreadSafeService.register(in: container)
        
        let expectation = XCTestExpectation(description: "Concurrent resolution")
        expectation.expectedFulfillmentCount = 10
        
        var resolvedServices: [ThreadSafeService] = []
        let queue = DispatchQueue.global(qos: .default)
        let lock = NSLock()
        
        for _ in 0..<10 {
            queue.async {
                if let service = self.container.resolve(ThreadSafeService.self) {
                    lock.lock()
                    resolvedServices.append(service)
                    lock.unlock()
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(resolvedServices.count, 10)
        
        // All should be the same instance (container scope)
        let firstId = resolvedServices.first?.id
        XCTAssertTrue(resolvedServices.allSatisfy { $0.id == firstId })
    }
}

// MARK: - Test Support Types

class TestDependency {
    let id = UUID()
}

class OptionalTestDependency {
    let id = UUID()
}

class MissingDependency {
    let id = UUID()
}