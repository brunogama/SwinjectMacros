// ModuleSystemTests.swift - Tests for the module system
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Swinject
@testable import SwinjectUtilityMacros
@testable import SwinjectUtilityMacrosImplementation
import XCTest

final class ModuleSystemTests: XCTestCase {

    var moduleSystem: ModuleSystem!

    override func setUp() {
        super.setUp()
        moduleSystem = ModuleSystem()
    }

    override func tearDown() {
        moduleSystem?.shutdown()
        moduleSystem = nil
        super.tearDown()
    }

    // MARK: - Module Macro Tests

    func testModuleMacroExpansion() {
        assertMacroExpansion("""
        @Module(name: "Network", priority: 100)
        struct NetworkModule {
            static func configure(_ container: Container) {
                container.register(URLSession.self) { _ in
                    URLSession.shared
                }
            }
        }
        """, expandedSource: """
        struct NetworkModule {
            static func configure(_ container: Container) {
                container.register(URLSession.self) { _ in
                    URLSession.shared
                }
            }
        }

        extension NetworkModule: ModuleProtocol {
            public static var name: String {
                "Network"
            }

            public static var priority: Int {
                100
            }

            public static var dependencies: [ModuleProtocol.Type] {
                []
            }

            public static var exports: [Any.Type] {
                []
            }

            public static func register(in system: ModuleSystem) {
                system.register(module: self)
            }
        }
        """, macros: testMacros)
    }

    func testModuleWithDependencies() {
        assertMacroExpansion("""
        @Module(
            name: "API",
            dependencies: [NetworkModule.self, AuthModule.self]
        )
        struct APIModule {
            static func configure(_ container: Container) {
                // Configuration
            }
        }
        """, expandedSource: """
        struct APIModule {
            static func configure(_ container: Container) {
                // Configuration
            }
        }

        extension APIModule: ModuleProtocol {
            public static var name: String {
                "API"
            }

            public static var priority: Int {
                0
            }

            public static var dependencies: [ModuleProtocol.Type] {
                [NetworkModule.self, AuthModule.self]
            }

            public static var exports: [Any.Type] {
                []
            }

            public static func register(in system: ModuleSystem) {
                system.register(module: self)
            }
        }
        """, macros: testMacros)
    }

    // MARK: - ModuleInterface Macro Tests

    func testModuleInterfaceMacro() {
        assertMacroExpansion("""
        @ModuleInterface
        protocol UserServiceInterface {
            func getUser(id: String) async throws -> User
        }
        """, expandedSource: """
        protocol UserServiceInterface {
            func getUser(id: String) async throws -> User
        }

        extension UserServiceInterface {
            /// Unique identifier for cross-module resolution
            public static var moduleInterfaceIdentifier: String {
                "\\(String(reflecting: Self.self))"
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Module System Tests

    func testModuleRegistration() {
        // Create test modules
        struct TestModule1: ModuleProtocol {
            static let name = "TestModule1"
            static let priority = 0
            static let dependencies: [ModuleProtocol.Type] = []
            static let exports: [Any.Type] = []

            static func configure(_ container: Container) {
                container.register(String.self, name: "test1") { _ in "Module1" }
            }
        }

        // Register module
        moduleSystem.register(module: TestModule1.self)

        // Verify registration
        XCTAssertTrue(moduleSystem.moduleNames.contains("TestModule1"))

        // Initialize system
        XCTAssertNoThrow(try moduleSystem.initialize())

        // Resolve service
        let resolved = moduleSystem.resolve(String.self, name: "test1")
        XCTAssertEqual(resolved, "Module1")
    }

    func testModuleDependencies() {
        // Create modules with dependencies
        struct DatabaseModule: ModuleProtocol {
            static let name = "Database"
            static let priority = 10
            static let dependencies: [ModuleProtocol.Type] = []
            static let exports: [Any.Type] = [DatabaseProtocol.self]

            static func configure(_ container: Container) {
                container.register(DatabaseProtocol.self) { _ in
                    MockDatabase()
                }
            }
        }

        struct UserModule: ModuleProtocol {
            static let name = "User"
            static let priority = 5
            static let dependencies: [ModuleProtocol.Type] = [DatabaseModule.self]
            static let exports: [Any.Type] = []

            static func configure(_ container: Container) {
                container.register(UserService.self) { resolver in
                    let db = resolver.resolve(DatabaseProtocol.self)!
                    let api = MockAPIClient()
                    let logger = MockLogger()
                    return UserService(apiClient: api, database: db, logger: logger)
                }
            }
        }

        // Register modules
        moduleSystem.register(module: UserModule.self)
        moduleSystem.register(module: DatabaseModule.self)

        // Initialize should succeed
        XCTAssertNoThrow(try moduleSystem.initialize())

        // Verify services are available
        let userService = moduleSystem.resolve(UserService.self)
        XCTAssertNotNil(userService)
    }

    func testCircularDependencyDetection() {
        // Create modules with circular dependency
        struct ModuleA: ModuleProtocol {
            static let name = "ModuleA"
            static let priority = 0
            static let dependencies: [ModuleProtocol.Type] = [ModuleB.self]
            static let exports: [Any.Type] = []
            static func configure(_ container: Container) {}
        }

        struct ModuleB: ModuleProtocol {
            static let name = "ModuleB"
            static let priority = 0
            static let dependencies: [ModuleProtocol.Type] = [ModuleA.self]
            static let exports: [Any.Type] = []
            static func configure(_ container: Container) {}
        }

        moduleSystem.register(module: ModuleA.self)
        moduleSystem.register(module: ModuleB.self)

        // Initialize should fail with circular dependency error
        XCTAssertThrowsError(try moduleSystem.initialize()) { error in
            if let moduleError = error as? ModuleError {
                switch moduleError {
                case .circularDependency:
                    break // Expected
                default:
                    XCTFail("Expected circular dependency error, got: \(moduleError)")
                }
            } else {
                XCTFail("Expected ModuleError, got: \(error)")
            }
        }
    }

    func testModulePriority() {
        var initializationOrder: [String] = []

        struct HighPriorityModule: ModuleProtocol {
            static let name = "HighPriority"
            static let priority = 100
            static let dependencies: [ModuleProtocol.Type] = []
            static let exports: [Any.Type] = []
            static func configure(_ container: Container) {
                container.register(String.self, name: "high") { _ in "high" }
            }
        }

        struct LowPriorityModule: ModuleProtocol {
            static let name = "LowPriority"
            static let priority = 10
            static let dependencies: [ModuleProtocol.Type] = []
            static let exports: [Any.Type] = []
            static func configure(_ container: Container) {
                container.register(String.self, name: "low") { _ in "low" }
            }
        }

        moduleSystem.register(module: LowPriorityModule.self)
        moduleSystem.register(module: HighPriorityModule.self)

        XCTAssertNoThrow(try moduleSystem.initialize())

        // High priority module should be checked first for resolution
        let highPriority = moduleSystem.resolve(String.self, name: "high", from: "HighPriority")
        XCTAssertEqual(highPriority, "high")
    }

    func testModuleLifecycle() {
        struct TestModule: ModuleProtocol {
            static let name = "TestModule"
            static let priority = 0
            static let dependencies: [ModuleProtocol.Type] = []
            static let exports: [Any.Type] = []

            static func configure(_ container: Container) {
                container.register(String.self) { _ in "test" }
            }
        }

        // Register and initialize
        moduleSystem.register(module: TestModule.self)
        XCTAssertNoThrow(try moduleSystem.initialize())

        // Verify service is available
        XCTAssertNotNil(moduleSystem.resolve(String.self))

        // Shutdown
        moduleSystem.shutdown()

        // After shutdown, new initialization should be required
        moduleSystem.reset()
        XCTAssertNil(moduleSystem.resolve(String.self))
    }

    func testModuleInfo() {
        struct InfoModule: ModuleProtocol {
            static let name = "InfoModule"
            static let priority = 50
            static let dependencies: [ModuleProtocol.Type] = []
            static let exports: [Any.Type] = [String.self, Int.self]
            static func configure(_ container: Container) {}
        }

        moduleSystem.register(module: InfoModule.self)

        let info = moduleSystem.info(for: "InfoModule")
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.name, "InfoModule")
        XCTAssertEqual(info?.priority, 50)
        XCTAssertEqual(info?.dependencies.count, 0)
        XCTAssertEqual(info?.exports.count, 2)
        XCTAssertEqual(info?.isInitialized, false)

        // After initialization
        XCTAssertNoThrow(try moduleSystem.initialize())
        let infoAfter = moduleSystem.info(for: "InfoModule")
        XCTAssertEqual(infoAfter?.isInitialized, true)
    }

    // MARK: - Feature Flag Tests

    func testFeatureFlags() {
        // Initially disabled
        XCTAssertFalse(FeatureFlags.isEnabled("test_feature"))

        // Enable feature
        FeatureFlags.enable("test_feature")
        XCTAssertTrue(FeatureFlags.isEnabled("test_feature"))

        // Disable feature
        FeatureFlags.disable("test_feature")
        XCTAssertFalse(FeatureFlags.isEnabled("test_feature"))

        // Reset
        FeatureFlags.enable("feature1")
        FeatureFlags.enable("feature2")
        FeatureFlags.reset()
        XCTAssertFalse(FeatureFlags.isEnabled("feature1"))
        XCTAssertFalse(FeatureFlags.isEnabled("feature2"))
    }

    func testModuleConditions() {
        // Always condition
        XCTAssertTrue(ModuleCondition.always.isMet)

        // Debug condition
        #if DEBUG
            XCTAssertTrue(ModuleCondition.debug.isMet)
            XCTAssertFalse(ModuleCondition.release.isMet)
        #else
            XCTAssertFalse(ModuleCondition.debug.isMet)
            XCTAssertTrue(ModuleCondition.release.isMet)
        #endif

        // Feature flag condition
        FeatureFlags.enable("test_flag")
        XCTAssertTrue(ModuleCondition.featureFlag("test_flag").isMet)
        XCTAssertFalse(ModuleCondition.featureFlag("other_flag").isMet)

        // Custom condition
        var customValue = false
        let customCondition = ModuleCondition.custom { customValue }
        XCTAssertFalse(customCondition.isMet)
        customValue = true
        XCTAssertTrue(customCondition.isMet)
    }

    // MARK: - Test Utilities

    private let testMacros: [String: Macro.Type] = [
        "Module": ModuleMacro.self
        // "ModuleInterface": ModuleInterfaceMacro.self, // Not implemented yet
        // "Provides": ProvidesMacro.self,               // Not implemented yet
        // "Include": IncludeMacro.self                  // Not implemented yet
    ]
}

// MARK: - Mock Types for Testing

// DatabaseProtocol already declared in TestUtilities.swift
