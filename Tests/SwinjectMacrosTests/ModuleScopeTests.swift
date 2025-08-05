// ModuleScopeTests.swift - Tests for module-level singleton scope
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Swinject
@testable import SwinjectMacros
import XCTest

final class ModuleScopeTests: XCTestCase {

    var container: Container!
    var moduleSystem: ModuleSystem!

    override func setUp() {
        super.setUp()
        container = Container()
        moduleSystem = ModuleSystem()
        ModuleScope.shared.clearAll()
    }

    override func tearDown() {
        ModuleScope.shared.clearAll()
        moduleSystem?.shutdown()
        container = nil
        moduleSystem = nil
        super.tearDown()
    }

    // MARK: - ModuleScope Tests

    func testModuleScopeStorage() {
        let scope = ModuleScope.shared

        // Store instance for module A
        let serviceA = ModuleTestService(id: "A")
        scope.store(instance: serviceA, key: "service", moduleIdentifier: "ModuleA")

        // Store instance for module B
        let serviceB = ModuleTestService(id: "B")
        scope.store(instance: serviceB, key: "service", moduleIdentifier: "ModuleB")

        // Retrieve instances
        let retrievedA: ModuleTestService? = scope.instance(for: "service", moduleIdentifier: "ModuleA")
        let retrievedB: ModuleTestService? = scope.instance(for: "service", moduleIdentifier: "ModuleB")

        XCTAssertEqual(retrievedA?.id, "A")
        XCTAssertEqual(retrievedB?.id, "B")
        XCTAssertNotEqual(retrievedA?.id, retrievedB?.id)
    }

    func testModuleScopeClear() {
        let scope = ModuleScope.shared

        // Store instances
        scope.store(instance: ModuleTestService(id: "A"), key: "service1", moduleIdentifier: "ModuleA")
        scope.store(instance: ModuleTestService(id: "B"), key: "service2", moduleIdentifier: "ModuleA")
        scope.store(instance: ModuleTestService(id: "C"), key: "service", moduleIdentifier: "ModuleB")

        XCTAssertEqual(scope.instanceCount(for: "ModuleA"), 2)
        XCTAssertEqual(scope.instanceCount(for: "ModuleB"), 1)

        // Clear specific module
        scope.clearModule("ModuleA")

        XCTAssertEqual(scope.instanceCount(for: "ModuleA"), 0)
        XCTAssertEqual(scope.instanceCount(for: "ModuleB"), 1)

        // Clear all
        scope.clearAll()
        XCTAssertEqual(scope.instanceCount(for: "ModuleB"), 0)
    }

    func testModuleIdentifiers() {
        let scope = ModuleScope.shared

        scope.store(instance: ModuleTestService(id: "A"), key: "service", moduleIdentifier: "ModuleA")
        scope.store(instance: ModuleTestService(id: "B"), key: "service", moduleIdentifier: "ModuleB")
        scope.store(instance: ModuleTestService(id: "C"), key: "service", moduleIdentifier: "ModuleC")

        let identifiers = scope.moduleIdentifiers.sorted()
        XCTAssertEqual(identifiers, ["ModuleA", "ModuleB", "ModuleC"])
    }

    // MARK: - Container Module Scope Tests

    func testContainerModuleScope() {
        // Register service with module scope
        container.register(ModuleTestService.self) { _ in
            ModuleTestService(id: UUID().uuidString)
        }.inObjectScope(.module)

        // Resolve in different module contexts
        let context1 = ModuleContext(identifier: "Module1")
        let context2 = ModuleContext(identifier: "Module2")

        var service1: ModuleTestService?
        var service2: ModuleTestService?
        var service1Again: ModuleTestService?

        context1.execute {
            service1 = self.container.resolve(ModuleTestService.self)
            service1Again = self.container.resolve(ModuleTestService.self)
        }

        context2.execute {
            service2 = self.container.resolve(ModuleTestService.self)
        }

        // Same instance within module
        XCTAssertNotNil(service1)
        XCTAssertNotNil(service1Again)
        XCTAssertEqual(service1?.id, service1Again?.id)

        // Different instance across modules
        XCTAssertNotNil(service2)
        XCTAssertNotEqual(service1?.id, service2?.id)
    }

    func testRegisterModuleScoped() {
        // Use convenience registration method
        container.registerModuleScoped(ModuleTestService.self) { _ in
            ModuleTestService(id: "scoped")
        }

        let context = ModuleContext(identifier: "TestModule")

        var service1: ModuleTestService?
        var service2: ModuleTestService?

        context.execute {
            service1 = self.container.resolve(ModuleTestService.self)
            service2 = self.container.resolve(ModuleTestService.self)
        }

        XCTAssertNotNil(service1)
        XCTAssertNotNil(service2)
        XCTAssertEqual(service1?.id, service2?.id) // Same instance
    }

    func testResolveWithModule() {
        container.registerModuleScoped(ModuleTestService.self) { _ in
            ModuleTestService(id: "module-specific")
        }

        let service = container.resolveWithModule(
            ModuleTestService.self,
            module: "SpecificModule"
        )

        XCTAssertNotNil(service)
        XCTAssertEqual(service?.id, "module-specific")
    }

    // MARK: - ModuleContext Tests

    func testModuleContext() {
        let context = ModuleContext(identifier: "TestModule")

        XCTAssertNil(ModuleContext.current)

        context.execute {
            XCTAssertNotNil(ModuleContext.current)
            XCTAssertEqual(ModuleContext.current?.identifier, "TestModule")
        }

        XCTAssertNil(ModuleContext.current)
    }

    func testNestedModuleContext() {
        let parent = ModuleContext(identifier: "Parent")
        let child = ModuleContext(identifier: "Child", parent: parent)

        parent.execute {
            XCTAssertEqual(ModuleContext.current?.identifier, "Parent")

            child.execute {
                XCTAssertEqual(ModuleContext.current?.identifier, "Child")
                XCTAssertEqual(ModuleContext.current?.parent?.identifier, "Parent")
            }

            XCTAssertEqual(ModuleContext.current?.identifier, "Parent")
        }
    }

    func testAsyncModuleContext() async {
        let context = ModuleContext(identifier: "AsyncModule")

        await context.execute {
            XCTAssertEqual(ModuleContext.current?.identifier, "AsyncModule")

            // Simulate async work
            try? await Task.sleep(nanoseconds: 100_000)

            XCTAssertEqual(ModuleContext.current?.identifier, "AsyncModule")
        }

        XCTAssertNil(ModuleContext.current)
    }

    // MARK: - @ModuleScoped Property Wrapper Tests

    func testModuleScopedPropertyWrapper() {
        // Register services in module system
        struct TestModule: ModuleProtocol {
            static let name = "Test"
            static let priority = 0
            static let dependencies: [ModuleProtocol.Type] = []
            static let exports: [Any.Type] = []

            static func configure(_ container: Container) {
                container.register(ModuleTestService.self) { _ in
                    ModuleTestService(id: "wrapped")
                }
            }
        }

        moduleSystem.register(module: TestModule.self)
        try? moduleSystem.initialize()

        // Use property wrapper
        struct TestViewModel {
            @ModuleScoped(ModuleTestService.self, module: "Test")
            var service: ModuleTestService
        }

        var viewModel = TestViewModel()
        XCTAssertEqual(viewModel.service.id, "wrapped")
    }

    // MARK: - Thread Safety Tests

    func testModuleScopeThreadSafety() {
        let scope = ModuleScope.shared
        let expectation = expectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = 100

        let queue = DispatchQueue(label: "test", attributes: .concurrent)

        for i in 0..<100 {
            queue.async {
                let service = ModuleTestService(id: "\(i)")
                scope.store(
                    instance: service,
                    key: "service-\(i)",
                    moduleIdentifier: "Module-\(i % 10)"
                )

                let retrieved: ModuleTestService? = scope.instance(
                    for: "service-\(i)",
                    moduleIdentifier: "Module-\(i % 10)"
                )

                XCTAssertEqual(retrieved?.id, "\(i)")
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 5)
    }

    func testThreadLocalStorage() {
        let threadLocal = ThreadLocal<String>()

        XCTAssertNil(threadLocal.value)

        threadLocal.value = "main"
        XCTAssertEqual(threadLocal.value, "main")

        let expectation = expectation(description: "Thread local")

        DispatchQueue.global().async {
            XCTAssertNil(threadLocal.value)
            threadLocal.value = "background"
            XCTAssertEqual(threadLocal.value, "background")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
        XCTAssertEqual(threadLocal.value, "main")
    }

    // MARK: - Integration Tests

    func testModuleScopeInModuleSystem() {
        // Create modules with module-scoped services
        struct DatabaseModule: ModuleProtocol {
            static let name = "Database"
            static let priority = 100
            static let dependencies: [ModuleProtocol.Type] = []
            static let exports: [Any.Type] = []

            static func configure(_ container: Container) {
                container.register(Connection.self) { _ in
                    Connection(id: "db-connection")
                }.inObjectScope(.module)
            }
        }

        struct UserModule: ModuleProtocol {
            static let name = "User"
            static let priority = 50
            static let dependencies: [ModuleProtocol.Type] = []
            static let exports: [Any.Type] = []

            static func configure(_ container: Container) {
                container.register(Connection.self) { _ in
                    Connection(id: "user-connection")
                }.inObjectScope(.module)
            }
        }

        moduleSystem.register(module: DatabaseModule.self)
        moduleSystem.register(module: UserModule.self)
        try? moduleSystem.initialize()

        // Resolve in different module contexts
        let dbContext = ModuleContext(identifier: "Database")
        let userContext = ModuleContext(identifier: "User")

        var dbConnection: Connection?
        var userConnection: Connection?

        dbContext.execute {
            dbConnection = self.moduleSystem.rootContainer.resolve(Connection.self)
        }

        userContext.execute {
            userConnection = self.moduleSystem.rootContainer.resolve(Connection.self)
        }

        // Different instances for different modules
        XCTAssertNotNil(dbConnection)
        XCTAssertNotNil(userConnection)
        XCTAssertNotEqual(dbConnection?.id, userConnection?.id)
    }
}

// MARK: - Test Types

private class ModuleTestService {
    let id: String

    init(id: String) {
        self.id = id
    }
}

private class Connection {
    let id: String

    init(id: String) {
        self.id = id
    }
}
