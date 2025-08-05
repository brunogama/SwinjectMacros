// APIValidationTests.swift - Tests to validate generated code compiles against actual Swinject API
// Copyright © 2025 SwinJectMacros. All rights reserved.

import Swinject
@testable import SwinjectUtilityMacros
import XCTest

// MARK: - Test Service Types (Must be at file level for macros)

@Injectable
class APIValidationService {
    let dependency: TestDependency

    init(dependency: TestDependency) {
        self.dependency = dependency
    }
}

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

@Injectable(scope: .weak)
class WeakScopedService {
    let id = UUID()
    init() {}
}

@Injectable(name: "primaryDataService")
class NamedDataService {
    let data: String
    init(data: String = "default") {
        self.data = data
    }
}

@Injectable(name: "secondaryDataService")
class AlternateDataService {
    let data: String
    init(data: String = "alternate") {
        self.data = data
    }
}

@Injectable
class APIOptionalDependencyService {
    let requiredDep: TestDependency
    let optionalDep: TestDependency?
    let optionalWithDefault: TestDependency?

    init(
        requiredDep: TestDependency,
        optionalDep: TestDependency? = nil,
        optionalWithDefault: TestDependency? = TestDependency()
    ) {
        self.requiredDep = requiredDep
        self.optionalDep = optionalDep
        self.optionalWithDefault = optionalWithDefault
    }
}

@Injectable
class ProtocolBasedService {
    let apiClient: APIClientProtocol
    let database: DatabaseProtocol

    init(apiClient: APIClientProtocol, database: DatabaseProtocol) {
        self.apiClient = apiClient
        self.database = database
    }
}

@Injectable
class GenericService<T: Codable> {
    let value: T
    let dependency: TestDependency

    init(value: T, dependency: TestDependency) {
        self.value = value
        self.dependency = dependency
    }
}

@AutoFactory
class FactoryValidationService {
    let dependency: TestDependency
    let runtimeParameter: String

    init(dependency: TestDependency, runtimeParameter: String) {
        self.dependency = dependency
        self.runtimeParameter = runtimeParameter
    }
}

@AutoFactory
class CustomNamedFactoryService {
    let dependency: TestDependency
    let config: String

    init(dependency: TestDependency, config: String) {
        self.dependency = dependency
        self.config = config
    }
}

// MARK: - Test Class

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
        ContainerScopedService.register(in: container)
        GraphScopedService.register(in: container)
        WeakScopedService.register(in: container)

        // Container scope - same instance
        let containerScoped1 = container.resolve(ContainerScopedService.self)
        let containerScoped2 = container.resolve(ContainerScopedService.self)
        XCTAssertNotNil(containerScoped1)
        XCTAssertEqual(containerScoped1?.id, containerScoped2?.id)

        // Graph scope - different instances
        let graphScoped1 = container.resolve(GraphScopedService.self)
        let graphScoped2 = container.resolve(GraphScopedService.self)
        XCTAssertNotNil(graphScoped1)
        XCTAssertNotEqual(graphScoped1?.id, graphScoped2?.id)

        // Weak scope
        var weakScoped: WeakScopedService? = container.resolve(WeakScopedService.self)
        XCTAssertNotNil(weakScoped)
        let weakId = weakScoped?.id
        weakScoped = nil // Release reference
        let weakScoped2 = container.resolve(WeakScopedService.self)
        XCTAssertNotEqual(weakId, weakScoped2?.id, "Should create new instance after weak reference released")
    }

    func testNamedServiceRegistration() {
        NamedDataService.register(in: container)
        AlternateDataService.register(in: container)

        let primaryService = container.resolve(NamedDataService.self, name: "primaryDataService")
        let secondaryService = container.resolve(AlternateDataService.self, name: "secondaryDataService")

        XCTAssertNotNil(primaryService)
        XCTAssertNotNil(secondaryService)
        XCTAssertEqual(primaryService?.data, "default")
        XCTAssertEqual(secondaryService?.data, "alternate")
    }

    func testOptionalDependencyHandling() {
        // Register only required dependency
        container.register(TestDependency.self) { _ in TestDependency() }

        APIOptionalDependencyService.register(in: container)

        let service = container.resolve(APIOptionalDependencyService.self)
        XCTAssertNotNil(service)
        XCTAssertNotNil(service?.requiredDep, "Required dependency should be injected")
        XCTAssertNil(service?.optionalDep, "Optional dependency should remain nil when not registered")
        XCTAssertNotNil(service?.optionalWithDefault, "Optional with default should have value")
    }

    func testProtocolBasedInjection() {
        // Register concrete implementations for protocols
        container.register(APIClientProtocol.self) { _ in MockAPIClient() }
        container.register(DatabaseProtocol.self) { _ in MockDatabase() }

        ProtocolBasedService.register(in: container)

        let service = container.resolve(ProtocolBasedService.self)
        XCTAssertNotNil(service)
        XCTAssertTrue(service?.apiClient is MockAPIClient)
        XCTAssertTrue(service?.database is MockDatabase)
    }

    func testGenericServiceRegistration() {
        container.register(TestDependency.self) { _ in TestDependency() }

        // Register specific generic type
        container.register(GenericService<String>.self) { resolver in
            GenericService(value: "test", dependency: resolver.resolve(TestDependency.self)!)
        }

        let service = container.resolve(GenericService<String>.self)
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.value, "test")
    }

    // MARK: - Factory Validation

    func testAutoFactoryGeneration() {
        container.register(TestDependency.self) { _ in TestDependency() }
        container.register(FactoryValidationServiceFactory.self) { resolver in
            FactoryValidationServiceFactoryImpl(container: self.container)
        }

        let factory = container.resolve(FactoryValidationServiceFactory.self)
        XCTAssertNotNil(factory)

        let service = factory?.makeFactoryValidationService(runtimeParameter: "test123")
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.runtimeParameter, "test123")
        XCTAssertNotNil(service?.dependency)
    }

    func testCustomNamedFactory() {
        container.register(TestDependency.self) { _ in TestDependency() }
        container.register(CustomNamedFactoryServiceFactory.self) { resolver in
            CustomNamedFactoryServiceFactoryImpl(container: self.container)
        }

        let factory = container.resolve(CustomNamedFactoryServiceFactory.self)
        XCTAssertNotNil(factory)

        let service = factory?.makeCustomNamedFactoryService(config: "custom-config")
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.config, "custom-config")
    }

    // MARK: - Thread Safety

    func testConcurrentResolution() {
        GraphScopedService.register(in: container)

        // Use synchronized resolver for thread-safe access
        let synchronizedResolver = container.synchronize()

        let expectation = expectation(description: "Concurrent resolution")
        expectation.expectedFulfillmentCount = 100

        let queue = DispatchQueue(label: "test", attributes: .concurrent)
        var services: [GraphScopedService] = []
        let lock = NSLock()

        for _ in 0..<100 {
            queue.async {
                if let service = synchronizedResolver.resolve(GraphScopedService.self) {
                    lock.lock()
                    services.append(service)
                    lock.unlock()
                }
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(services.count, 100, "All concurrent resolutions should succeed")
    }

    // MARK: - Assembly Integration

    func testAssemblyIntegration() {
        class TestAssembly: Assembly {
            func assemble(container: Container) {
                container.register(TestDependency.self) { _ in TestDependency() }
                APIValidationService.register(in: container)
                ContainerScopedService.register(in: container)
            }
        }

        let testAssembly = TestAssembly()
        assembler.apply(assembly: testAssembly)

        let service = container.resolve(APIValidationService.self)
        XCTAssertNotNil(service, "Service should be available through assembly")

        let scopedService = container.resolve(ContainerScopedService.self)
        XCTAssertNotNil(scopedService, "Scoped service should be available through assembly")
    }
}
