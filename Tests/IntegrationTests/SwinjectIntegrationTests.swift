// SwinjectIntegrationTests.swift - Integration tests with real Swinject containers
// Copyright © 2025 SwinJectMacros. All rights reserved.

import XCTest
import Swinject
@testable import SwinjectUtilityMacros

final class SwinjectIntegrationTests: XCTestCase {
    
    var container: Container!
    
    override func setUp() {
        super.setUp()
        container = Container()
    }
    
    override func tearDown() {
        container = nil
        super.tearDown()
    }
    
    func testBasicServiceRegistration() {
        // Test basic container functionality works
        container.register(TestProtocol.self) { _ in
            TestService()
        }
        
        let service = container.resolve(TestProtocol.self)
        XCTAssertNotNil(service)
    }
    
    func testManualServiceRegistration() {
        // Test manual registration pattern that @Injectable should generate
        container.register(APIClient.self) { _ in
            MockAPIClient()
        }
        
        container.register(Database.self) { _ in
            MockDatabase()
        }
        
        // This simulates what @Injectable would generate
        container.register(UserService.self) { resolver in
            UserService(
                apiClient: resolver.resolve(APIClient.self)!,
                database: resolver.resolve(Database.self)!
            )
        }
        
        let userService = container.resolve(UserService.self)
        XCTAssertNotNil(userService)
    }
    
    func testDependencyResolution() {
        // Test that complex dependency graphs resolve correctly
        registerTestServices()
        
        let service = container.resolve(ComplexService.self)
        XCTAssertNotNil(service)
        
        // Verify dependencies were injected
        XCTAssertNotNil(service?.userService)
        XCTAssertNotNil(service?.apiClient)
    }
    
    func testObjectScopes() {
        // Test different object scopes
        container.register(SingletonService.self) { _ in
            SingletonService()
        }.inObjectScope(.container)
        
        let service1 = container.resolve(SingletonService.self)
        let service2 = container.resolve(SingletonService.self)
        
        XCTAssertNotNil(service1)
        XCTAssertNotNil(service2)
        XCTAssertTrue(service1 === service2, "Container scope should return same instance")
    }
    
    func testNamedServices() {
        // Test named service registration
        container.register(APIClient.self, name: "production") { _ in
            ProductionAPIClient()
        }
        
        container.register(APIClient.self, name: "test") { _ in
            MockAPIClient()
        }
        
        let prodClient = container.resolve(APIClient.self, name: "production")
        let testClient = container.resolve(APIClient.self, name: "test")
        
        XCTAssertNotNil(prodClient)
        XCTAssertNotNil(testClient)
        XCTAssertTrue(prodClient is ProductionAPIClient)
        XCTAssertTrue(testClient is MockAPIClient)
    }
    
    func testOptionalDependencies() {
        // Test optional dependency resolution
        container.register(RequiredService.self) { _ in
            RequiredService()
        }
        
        // OptionalService is not registered - should be nil
        container.register(ServiceWithOptionalDependency.self) { resolver in
            ServiceWithOptionalDependency(
                required: resolver.resolve(RequiredService.self)!,
                optional: resolver.resolve(OptionalService.self)
            )
        }
        
        let service = container.resolve(ServiceWithOptionalDependency.self)
        XCTAssertNotNil(service)
        XCTAssertNotNil(service?.required)
        XCTAssertNil(service?.optional)
    }
    
    // MARK: - Helper Methods
    
    private func registerTestServices() {
        container.register(APIClient.self) { _ in MockAPIClient() }
        container.register(Database.self) { _ in MockDatabase() }
        
        container.register(UserService.self) { resolver in
            UserService(
                apiClient: resolver.resolve(APIClient.self)!,
                database: resolver.resolve(Database.self)!
            )
        }
        
        container.register(ComplexService.self) { resolver in
            ComplexService(
                userService: resolver.resolve(UserService.self)!,
                apiClient: resolver.resolve(APIClient.self)!
            )
        }
    }
}

// MARK: - Test Types

protocol TestProtocol {
    func performAction()
}

class TestService: TestProtocol {
    func performAction() {
        // Test implementation
    }
}

protocol APIClient {
    func fetchData() -> String
}

class MockAPIClient: APIClient {
    func fetchData() -> String {
        return "mock data"
    }
}

class ProductionAPIClient: APIClient {
    func fetchData() -> String {
        return "production data"
    }
}

protocol Database {
    func save(_ data: String)
}

class MockDatabase: Database {
    func save(_ data: String) {
        // Mock implementation
    }
}

class UserService {
    let apiClient: APIClient
    let database: Database
    
    init(apiClient: APIClient, database: Database) {
        self.apiClient = apiClient
        self.database = database
    }
}

class ComplexService {
    let userService: UserService
    let apiClient: APIClient
    
    init(userService: UserService, apiClient: APIClient) {
        self.userService = userService
        self.apiClient = apiClient
    }
}

class SingletonService {
    let id = UUID()
}

class RequiredService {
    // Required dependency
}

class OptionalService {
    // Optional dependency
}

class ServiceWithOptionalDependency {
    let required: RequiredService
    let optional: OptionalService?
    
    init(required: RequiredService, optional: OptionalService?) {
        self.required = required
        self.optional = optional
    }
}