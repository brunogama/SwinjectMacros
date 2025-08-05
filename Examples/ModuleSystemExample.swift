// ModuleSystemExample.swift - Example usage of the module system
// Copyright © 2025 SwinjectMacros. All rights reserved.

import Foundation
import Swinject
import SwinjectMacros

// MARK: - Module System Example

// This example demonstrates the advanced Module System features introduced in v1.0.1
// including lifecycle management, hot-swapping, performance optimization, and debug tools

// MARK: - Service Definitions

// Define services that will be organized into modules

struct User: Codable {
    let id: String
    let name: String
    let email: String
}

protocol HTTPClientProtocol {
    func request(_ endpoint: String) async throws -> Data
}

protocol DatabaseProtocol {
    func save(_ entity: Any) async throws
    func fetch(id: String) async throws -> Any?
}

protocol UserServiceProtocol {
    func getUser(id: String) async throws -> User?
    func createUser(_ user: User) async throws
}

protocol AnalyticsProtocol {
    func track(event: String, properties: [String: Any])
}

// MARK: - Service Implementations

@Injectable(scope: .container)
class URLSessionHTTPClient: HTTPClientProtocol {
    func request(_ endpoint: String) async throws -> Data {
        print("📡 HTTP Request: \(endpoint)")
        // Mock implementation
        return Data()
    }
}

@Injectable(scope: .container)
class InMemoryDatabase: DatabaseProtocol {
    private var storage: [String: Any] = [:]

    func save(_ entity: Any) async throws {
        if let user = entity as? User {
            storage[user.id] = user
            print("💾 Saved user: \(user.name)")
        }
    }

    func fetch(id: String) async throws -> Any? {
        print("🔍 Fetching entity with id: \(id)")
        return storage[id]
    }
}

@Injectable
class UserService: UserServiceProtocol {
    private let httpClient: HTTPClientProtocol
    private let database: DatabaseProtocol

    init(httpClient: HTTPClientProtocol, database: DatabaseProtocol) {
        self.httpClient = httpClient
        self.database = database
    }

    func getUser(id: String) async throws -> User? {
        // Try database first
        if let cached = try await database.fetch(id: id) as? User {
            return cached
        }

        // Fetch from network
        _ = try await httpClient.request("/users/\(id)")

        // Mock user for demo
        let user = User(id: id, name: "John Doe", email: "john@example.com")
        try await database.save(user)

        return user
    }

    func createUser(_ user: User) async throws {
        _ = try await httpClient.request("/users")
        try await database.save(user)
    }
}

@Injectable(scope: .container)
class Analytics: AnalyticsProtocol {
    func track(event: String, properties: [String: Any]) {
        print("📊 Analytics Event: \(event)")
        for (key, value) in properties {
            print("   - \(key): \(value)")
        }
    }
}

// MARK: - Module Definitions

// Define modules that group related services

@Module
struct NetworkModule {
    static let name = "Network"
    static let priority = 100
    static let dependencies: [String] = []

    static func configure(_ container: Container) {
        print("🌐 Configuring Network Module")

        // Register HTTP client
        URLSessionHTTPClient.register(in: container)

        // Register protocol mapping
        container.register(HTTPClientProtocol.self) { resolver in
            resolver.resolve(URLSessionHTTPClient.self)!
        }
    }
}

@Module
struct DatabaseModule {
    static let name = "Database"
    static let priority = 90
    static let dependencies: [String] = []

    static func configure(_ container: Container) {
        print("🗄️ Configuring Database Module")

        // Register database
        InMemoryDatabase.register(in: container)

        // Register protocol mapping
        container.register(DatabaseProtocol.self) { resolver in
            resolver.resolve(InMemoryDatabase.self)!
        }
    }
}

@Module
struct UserModule {
    static let name = "User"
    static let priority = 50
    static let dependencies = ["Network", "Database"]

    static func configure(_ container: Container) {
        print("👤 Configuring User Module")

        // Register user service
        UserService.register(in: container)

        // Register protocol mapping
        container.register(UserServiceProtocol.self) { resolver in
            resolver.resolve(UserService.self)!
        }
    }
}

@Module
struct AnalyticsModule {
    static let name = "Analytics"
    static let priority = 30
    static let dependencies: [String] = []

    static func configure(_ container: Container) {
        print("📈 Configuring Analytics Module")

        // Register analytics
        Analytics.register(in: container)

        // Register protocol mapping
        container.register(AnalyticsProtocol.self) { resolver in
            resolver.resolve(Analytics.self)!
        }
    }
}

// MARK: - Module System Usage

func demonstrateModuleSystem() async {
    print("🚀 Module System Example")
    print("========================\n")

    // Initialize module system
    let moduleSystem = ModuleSystem.shared

    // Register modules
    print("📦 Registering Modules...")
    moduleSystem.register(module: NetworkModule.self)
    moduleSystem.register(module: DatabaseModule.self)
    moduleSystem.register(module: UserModule.self)
    moduleSystem.register(module: AnalyticsModule.self)

    do {
        // Initialize all modules
        print("\n🔧 Initializing Modules...")
        try moduleSystem.initialize()

        // Start all modules
        print("\n▶️ Starting Modules...")
        try await moduleSystem.startAll()

        // Use services from modules
        print("\n💼 Using Services...")
        let container = moduleSystem.rootContainer

        let userService = container.resolve(UserServiceProtocol.self)!
        let analytics = container.resolve(AnalyticsProtocol.self)!

        // Track module usage
        analytics.track(event: "module_system_demo", properties: [
            "modules_count": 4,
            "status": "running"
        ])

        // Use user service
        if let user = try await userService.getUser(id: "123") {
            print("✅ Retrieved user: \(user.name)")

            analytics.track(event: "user_retrieved", properties: [
                "user_id": user.id,
                "user_name": user.name
            ])
        }

        // Demonstrate module lifecycle
        print("\n🔄 Module Lifecycle Demo...")

        // Get module info
        if let userModuleInfo = moduleSystem.getModuleInfo("User") {
            print("User Module State: \(userModuleInfo.state)")
            print("Dependencies: \(userModuleInfo.dependencies)")
        }

        // Hot-swap a module (replace Analytics with a new implementation)
        print("\n🔥 Hot-Swapping Analytics Module...")

        // Define a new analytics implementation
        @Module
        struct EnhancedAnalyticsModule {
            static let name = "Analytics" // Same name to replace
            static let priority = 30
            static let dependencies: [String] = []

            static func configure(_ container: Container) {
                print("📊 Configuring Enhanced Analytics Module")

                // Register enhanced analytics
                container.register(AnalyticsProtocol.self) { _ in
                    EnhancedAnalytics()
                }
            }
        }

        class EnhancedAnalytics: AnalyticsProtocol {
            func track(event: String, properties: [String: Any]) {
                print("📊✨ Enhanced Analytics Event: \(event)")
                print("   Timestamp: \(Date())")
                for (key, value) in properties {
                    print("   - \(key): \(value)")
                }
            }
        }

        try await moduleSystem.hotSwapModule(
            moduleName: "Analytics",
            newModule: EnhancedAnalyticsModule.self
        )

        // Use the new analytics
        let newAnalytics = container.resolve(AnalyticsProtocol.self)!
        newAnalytics.track(event: "module_hot_swapped", properties: [
            "module": "Analytics",
            "version": "enhanced"
        ])

        // Performance optimization demo
        print("\n⚡ Performance Optimization Demo...")

        let optimizer = ModulePerformanceOptimizer()

        // Profile module performance
        let profile = try await optimizer.profileModule("User", in: moduleSystem)
        print("User Module Performance:")
        print("  - Initialization: \(profile.initializationTime)ms")
        print("  - Memory: \(profile.memoryFootprint) bytes")
        print("  - CPU: \(profile.cpuUsage)%")

        // Get optimization recommendations
        let recommendations = try await optimizer.analyzeAndRecommend(moduleSystem)
        print("\nOptimization Recommendations:")
        for recommendation in recommendations {
            print("  - \(recommendation)")
        }

        // Debug tools demo
        print("\n🔍 Debug Tools Demo...")

        let debugTools = ModuleDebugTools()

        // Get module debug info
        let debugInfo = debugTools.getDebugInfo(for: "User", in: moduleSystem)
        print("User Module Debug Info:")
        print("  - Container Count: \(debugInfo.containerInfo.containerCount)")
        print("  - Service Count: \(debugInfo.containerInfo.serviceCount)")
        print("  - Dependencies: \(debugInfo.dependencyGraph.nodeCount) nodes")

        // Monitor module health
        let healthReport = debugTools.healthCheck(moduleSystem)
        print("\nModule System Health:")
        print("  - Overall Health: \(healthReport.overallHealth)")
        print("  - Active Modules: \(healthReport.activeModules)")
        if !healthReport.issues.isEmpty {
            print("  - Issues:")
            for issue in healthReport.issues {
                print("    • \(issue)")
            }
        }

        // Module scope demo
        print("\n🔒 Module Scope Demo...")

        // Services can be scoped to modules
        let moduleScope = ModuleScope(moduleId: "User")

        // Create a module-scoped service
        let scopedService = moduleScope.resolve { container in
            ModuleScopedLogger(module: "User")
        }

        scopedService.log("This is a module-scoped logger")

        // Cleanup
        print("\n🧹 Cleaning up...")
        try await moduleSystem.stopAll()

        print("\n✅ Module System Example Complete!")

    } catch {
        print("❌ Error: \(error)")
    }
}

// Helper class for module-scoped services
class ModuleScopedLogger {
    let module: String

    init(module: String) {
        self.module = module
    }

    func log(_ message: String) {
        print("[\(module)] \(message)")
    }
}

// MARK: - Run the Example

// To run this example:
// 1. Ensure SwinjectMacros is properly imported
// 2. Call demonstrateModuleSystem() from your main function or app entry point

// Example main function:
@main
struct ModuleSystemExampleApp {
    static func main() async {
        await demonstrateModuleSystem()
    }
}
