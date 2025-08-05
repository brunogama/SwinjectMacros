// RuntimeIntegrationTests.swift - Tests that verify macro-generated code works at runtime
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Swinject
@testable import SwinjectMacros
@testable import SwinjectMacrosImplementation
import XCTest

// MARK: - Test Classes with Macros (must be at file/class level)

@Injectable
class TestInjectableService {
    let dependency: TestDependency

    init(dependency: TestDependency) {
        self.dependency = dependency
    }
}

@Injectable
class MultiDependencyService {
    let apiClient: TestAPIClient
    let database: TestDatabase
    let logger: TestLogger

    init(apiClient: TestAPIClient, database: TestDatabase, logger: TestLogger) {
        self.apiClient = apiClient
        self.database = database
        self.logger = logger
    }
}

@Injectable
class OptionalDependencyService {
    let required: TestDependency
    let optional: TestOptionalDependency?

    init(required: TestDependency, optional: TestOptionalDependency?) {
        self.required = required
        self.optional = optional
    }
}

@Injectable(scope: .container)
class SingletonService {
    let id = UUID()
    let dependency: TestDependency

    init(dependency: TestDependency) {
        self.dependency = dependency
    }
}

@Injectable(name: "primary")
class NamedService {
    let dependency: TestDependency

    init(dependency: TestDependency) {
        self.dependency = dependency
    }
}

@AutoFactory
class FactoryService {
    let dependency: TestDependency
    let runtimeParam: String
    let count: Int

    init(dependency: TestDependency, runtimeParam: String, count: Int) {
        self.dependency = dependency
        self.runtimeParam = runtimeParam
        self.count = count
    }
}

@AutoFactory
class AsyncFactoryService {
    let dependency: TestDependency
    let data: String

    init(dependency: TestDependency, data: String) {
        self.dependency = dependency
        self.data = data
        // Simulate work
        Thread.sleep(forTimeInterval: 0.001) // 1ms
    }
}

@Injectable
class RepositoryService {
    let database: TestDatabase
    init(database: TestDatabase) {
        self.database = database
    }
}

@Injectable
class APIService {
    let client: TestAPIClient
    init(client: TestAPIClient) {
        self.client = client
    }
}

@Injectable
class BusinessService {
    let repository: RepositoryService
    let api: APIService
    let logger: TestLogger

    init(repository: RepositoryService, api: APIService, logger: TestLogger) {
        self.repository = repository
        self.api = api
        self.logger = logger
    }
}

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

@Injectable
class ServiceWithMissingDep {
    let dependency: TestDependency
    init(dependency: TestDependency) {
        self.dependency = dependency
    }
}

protocol TestServiceProtocol {
    func performAction() -> String
}

@Injectable
class ConcreteTestService: TestServiceProtocol {
    let dependency: TestDependency

    init(dependency: TestDependency) {
        self.dependency = dependency
    }

    func performAction() -> String {
        "concrete action"
    }
}

@Injectable
class ServiceWithManyDependencies {
    let dependencies: [TestDependency]

    init() {
        // In real scenario, this would be injected
        dependencies = []
    }
}

// MARK: - Test Class

final class RuntimeIntegrationTests: XCTestCase {

    var container: Container!

    override func setUp() {
        super.setUp()
        container = Container()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    // MARK: - @Injectable Runtime Tests

    func testInjectableServiceRegistersAndResolves() {
        // Register dependency first
        container.register(TestDependency.self) { _ in
            TestDependency()
        }

        // When: The @Injectable service registers itself
        TestInjectableService.register(in: container)

        // Then: It should resolve correctly with dependencies injected
        let service = container.resolve(TestInjectableService.self)
        XCTAssertNotNil(service)
        XCTAssertNotNil(service?.dependency)
    }

    func testInjectableWithMultipleDependencies() {
        // Register all dependencies
        container.register(TestAPIClient.self) { _ in TestAPIClient() }
        container.register(TestDatabase.self) { _ in TestDatabase() }
        container.register(TestLogger.self) { _ in TestLogger() }

        // Register the service
        MultiDependencyService.register(in: container)

        // Verify resolution
        let service = container.resolve(MultiDependencyService.self)
        XCTAssertNotNil(service)
        XCTAssertNotNil(service?.apiClient)
        XCTAssertNotNil(service?.database)
        XCTAssertNotNil(service?.logger)
    }

    func testInjectableWithOptionalDependencies() {
        // Register only required dependency
        container.register(TestDependency.self) { _ in TestDependency() }
        // Intentionally don't register TestOptionalDependency

        OptionalDependencyService.register(in: container)

        let service = container.resolve(OptionalDependencyService.self)
        XCTAssertNotNil(service)
        XCTAssertNotNil(service?.required)
        XCTAssertNil(service?.optional)
    }

    func testInjectableWithCustomScope() {
        container.register(TestDependency.self) { _ in TestDependency() }
        SingletonService.register(in: container)

        let service1 = container.resolve(SingletonService.self)
        let service2 = container.resolve(SingletonService.self)

        XCTAssertNotNil(service1)
        XCTAssertNotNil(service2)
        XCTAssertEqual(service1?.id, service2?.id, "Container scope should return same instance")
    }

    func testInjectableWithNamedService() {
        container.register(TestDependency.self) { _ in TestDependency() }
        NamedService.register(in: container)

        let service = container.resolve(NamedService.self, name: "primary")
        let unnamedService = container.resolve(NamedService.self)

        XCTAssertNotNil(service)
        XCTAssertNil(unnamedService, "Unnamed resolution should fail for named service")
    }

    // MARK: - @AutoFactory Runtime Tests

    func testAutoFactoryGeneratesWorkingFactory() {
        // Register dependency
        container.register(TestDependency.self) { _ in TestDependency() }

        // Register factory
        container.register(FactoryServiceFactory.self) { _ in
            FactoryServiceFactoryImpl(container: self.container)
        }

        // Test factory usage
        let factory = container.resolve(FactoryServiceFactory.self)
        XCTAssertNotNil(factory)

        let service = factory?.makeFactoryService(runtimeParam: "test", count: 42)
        XCTAssertNotNil(service)
        XCTAssertNotNil(service?.dependency)
        XCTAssertEqual(service?.runtimeParam, "test")
        XCTAssertEqual(service?.count, 42)
    }

    func testAutoFactoryWithAsyncInitialization() async {
        container.register(TestDependency.self) { _ in TestDependency() }
        container.register(AsyncFactoryServiceFactory.self) { _ in
            AsyncFactoryServiceFactoryImpl(container: self.container)
        }

        let factory = container.resolve(AsyncFactoryServiceFactory.self)
        XCTAssertNotNil(factory)

        let service = factory?.makeAsyncFactoryService(data: "async test")
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.data, "async test")
    }

    // MARK: - Complex Dependency Graph Tests

    func testComplexDependencyGraph() {
        // Register leaf dependencies
        container.register(TestDatabase.self) { _ in TestDatabase() }
        container.register(TestAPIClient.self) { _ in TestAPIClient() }
        container.register(TestLogger.self) { _ in TestLogger() }

        // Register services in order
        RepositoryService.register(in: container)
        APIService.register(in: container)
        BusinessService.register(in: container)

        // Verify complex resolution
        let businessService = container.resolve(BusinessService.self)
        XCTAssertNotNil(businessService)
        XCTAssertNotNil(businessService?.repository)
        XCTAssertNotNil(businessService?.api)
        XCTAssertNotNil(businessService?.logger)
        XCTAssertNotNil(businessService?.repository.database)
        XCTAssertNotNil(businessService?.api.client)
    }

    func testCircularDependencyDetection() {
        ServiceA.register(in: container)
        ServiceB.register(in: container)

        // This should fail due to circular dependency
        let serviceA = container.resolve(ServiceA.self)
        XCTAssertNil(serviceA, "Circular dependency should fail to resolve")
    }

    // MARK: - Error Scenarios

    func testMissingDependencyFailure() {
        // Don't register the dependency
        ServiceWithMissingDep.register(in: container)

        let service = container.resolve(ServiceWithMissingDep.self)
        XCTAssertNil(service, "Service should fail to resolve when dependency is missing")
    }

    func testProtocolAndConcreteTypeResolution() {
        container.register(TestDependency.self) { _ in TestDependency() }
        ConcreteTestService.register(in: container)

        // Also register protocol
        container.register(TestServiceProtocol.self) { resolver in
            resolver.resolve(ConcreteTestService.self)!
        }

        let concreteService = container.resolve(ConcreteTestService.self)
        let protocolService = container.resolve(TestServiceProtocol.self)

        XCTAssertNotNil(concreteService)
        XCTAssertNotNil(protocolService)
        XCTAssertEqual(protocolService?.performAction(), "concrete action")
    }

    // MARK: - Performance Tests

    func testLargeScaleResolution() {
        // Test performance with many services
        let serviceCount = 100

        for i in 0..<serviceCount {
            container.register(TestDependency.self, name: "dep\(i)") { _ in
                TestDependency()
            }
        }

        ServiceWithManyDependencies.register(in: container)

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<100 {
            let service = container.resolve(ServiceWithManyDependencies.self)
            XCTAssertNotNil(service)
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(duration, 1.0, "Large scale resolution should complete in under 1 second")
    }
}

// MARK: - Test Support Types

class TestOptionalDependency {
    let id = UUID()
}

class TestAPIClient {
    func fetchData() -> String { "test data" }
}

class TestDatabase {
    func save(_ data: String) { /* mock save */ }
}

class TestLogger {
    func log(_ message: String) { /* mock log */ }
}
