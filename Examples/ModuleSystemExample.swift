// ModuleSystemExample.swift - Example usage of the module system
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import Swinject
import SwinjectUtilityMacros

// MARK: - Module Interfaces

/// Define interfaces that can be shared across modules
@ModuleInterface
protocol HTTPClientInterface {
    func request(_ endpoint: String) async throws -> Data
}

@ModuleInterface
protocol DatabaseInterface {
    func save(_ entity: Any) async throws
    func fetch(id: String) async throws -> Any?
}

@ModuleInterface
protocol UserServiceInterface {
    func getUser(id: String) async throws -> User?
    func createUser(_ user: User) async throws
}

@ModuleInterface
protocol AnalyticsInterface {
    func track(event: String, properties: [String: Any])
}

// MARK: - Network Module

@Module(
    name: "Network",
    priority: 100,
    exports: [HTTPClientInterface.self]
)
struct NetworkModule {

    @Provides(scope: .singleton)
    static func httpClient() -> HTTPClientInterface {
        URLSessionHTTPClient()
    }

    @Provides
    static func urlSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }

    static func configure(_ container: Container) {
        // Additional network-specific configurations
        container.register(NetworkReachability.self) { _ in
            NetworkReachability()
        }
    }
}

// MARK: - Database Module

@Module(
    name: "Database",
    priority: 90,
    exports: [DatabaseInterface.self]
)
struct DatabaseModule {

    @Provides(scope: .singleton)
    static func database() -> DatabaseInterface {
        #if DEBUG
            return InMemoryDatabase()
        #else
            return SQLiteDatabase()
        #endif
    }

    @Provides
    static func migrationManager() -> DatabaseMigrationManager {
        DatabaseMigrationManager()
    }
}

// MARK: - User Module

@Module(
    name: "User",
    priority: 50,
    dependencies: [NetworkModule.self, DatabaseModule.self],
    exports: [UserServiceInterface.self]
)
struct UserModule {

    static func configure(_ container: Container) {
        // Register user service with dependencies from other modules
        container.register(UserServiceInterface.self) { resolver in
            let httpClient = resolver.resolve(HTTPClientInterface.self)!
            let database = resolver.resolve(DatabaseInterface.self)!
            return UserService(httpClient: httpClient, database: database)
        }.inObjectScope(.container)

        // Register other user-related services
        container.register(UserValidator.self) { _ in
            UserValidator()
        }

        container.register(UserCache.self) { _ in
            UserCache()
        }.inObjectScope(.container)
    }
}

// MARK: - Analytics Module

@Module(
    name: "Analytics",
    priority: 30,
    dependencies: [NetworkModule.self]
)
struct AnalyticsModule {

    @Provides(scope: .singleton)
    static func analytics() -> AnalyticsInterface {
        #if DEBUG
            return DebugAnalytics()
        #else
            return ProductionAnalytics()
        #endif
    }

    @Provides
    static func analyticsQueue() -> AnalyticsQueue {
        AnalyticsQueue(maxBatchSize: 100)
    }
}

// MARK: - Feature Modules

@Module(name: "Payment")
struct PaymentModule {
    static func configure(_ container: Container) {
        container.register(PaymentProcessor.self) { resolver in
            let httpClient = resolver.resolve(HTTPClientInterface.self)!
            return StripePaymentProcessor(httpClient: httpClient)
        }
    }
}

@Module(name: "Chat")
struct ChatModule {
    static func configure(_ container: Container) {
        container.register(ChatService.self) { resolver in
            let httpClient = resolver.resolve(HTTPClientInterface.self)!
            let database = resolver.resolve(DatabaseInterface.self)!
            return ChatService(httpClient: httpClient, database: database)
        }
    }
}

// MARK: - App Module (Composition Root)

@Module(
    name: "App",
    priority: 0
)
struct AppModule {

    // Include core modules
    @Include(NetworkModule.self)
    @Include(DatabaseModule.self)
    @Include(UserModule.self)
    @Include(AnalyticsModule.self)

    // Conditionally include feature modules
    @Include(PaymentModule.self, condition: .featureFlag("payments_enabled"))
    @Include(ChatModule.self, condition: .featureFlag("chat_enabled"))

    static func configure(_ container: Container) {
        // App-level service registrations
        container.register(AppCoordinator.self) { resolver in
            AppCoordinator(
                userService: resolver.resolve(UserServiceInterface.self)!,
                analytics: resolver.resolve(AnalyticsInterface.self)!
            )
        }
    }
}

// MARK: - Application Setup

class Application {

    let moduleSystem = ModuleSystem.shared

    func setup() async throws {
        // Configure feature flags
        configureFeatureFlags()

        // Register the app module (which includes all others)
        AppModule.register(in: moduleSystem)

        // Initialize the module system
        try moduleSystem.initialize()

        // Log module information
        logModuleInfo()
    }

    private func configureFeatureFlags() {
        // Enable features based on configuration
        if ProcessInfo.processInfo.environment["ENABLE_PAYMENTS"] == "true" {
            FeatureFlags.enable("payments_enabled")
        }

        if ProcessInfo.processInfo.environment["ENABLE_CHAT"] == "true" {
            FeatureFlags.enable("chat_enabled")
        }
    }

    private func logModuleInfo() {
        print("Initialized Modules:")
        for moduleName in moduleSystem.moduleNames {
            if let info = moduleSystem.info(for: moduleName) {
                print("  - \(info.name) (priority: \(info.priority))")
                if !info.dependencies.isEmpty {
                    print("    Dependencies: \(info.dependencies.joined(separator: ", "))")
                }
                if !info.exports.isEmpty {
                    print("    Exports: \(info.exports.joined(separator: ", "))")
                }
            }
        }
    }

    // Service resolution examples
    func resolveServices() {
        // Resolve from any module
        let userService = moduleSystem.resolve(UserServiceInterface.self)

        // Resolve from specific module
        let httpClient = moduleSystem.resolve(
            HTTPClientInterface.self,
            from: "Network"
        )

        // Resolve optional feature services
        let paymentProcessor = moduleSystem.resolve(PaymentProcessor.self)
        if paymentProcessor != nil {
            print("Payment processing is available")
        }
    }
}

// MARK: - Service Implementations (Simplified)

struct User: Codable {
    let id: String
    let name: String
    let email: String
}

class URLSessionHTTPClient: HTTPClientInterface {
    func request(_ endpoint: String) async throws -> Data {
        // Implementation
        Data()
    }
}

class InMemoryDatabase: DatabaseInterface {
    private var storage: [String: Any] = [:]

    func save(_ entity: Any) async throws {
        // Implementation
    }

    func fetch(id: String) async throws -> Any? {
        storage[id]
    }
}

class SQLiteDatabase: DatabaseInterface {
    func save(_ entity: Any) async throws {
        // Implementation
    }

    func fetch(id: String) async throws -> Any? {
        // Implementation
        nil
    }
}

class UserService: UserServiceInterface {
    private let httpClient: HTTPClientInterface
    private let database: DatabaseInterface

    init(httpClient: HTTPClientInterface, database: DatabaseInterface) {
        self.httpClient = httpClient
        self.database = database
    }

    func getUser(id: String) async throws -> User? {
        // Try cache first
        if let cached = try await database.fetch(id: id) as? User {
            return cached
        }

        // Fetch from API
        let data = try await httpClient.request("/users/\(id)")
        let user = try JSONDecoder().decode(User.self, from: data)

        // Cache result
        try await database.save(user)

        return user
    }

    func createUser(_ user: User) async throws {
        let data = try JSONEncoder().encode(user)
        _ = try await httpClient.request("/users")
        try await database.save(user)
    }
}

class DebugAnalytics: AnalyticsInterface {
    func track(event: String, properties: [String: Any]) {
        print("📊 [DEBUG] Analytics: \(event) - \(properties)")
    }
}

class ProductionAnalytics: AnalyticsInterface {
    func track(event: String, properties: [String: Any]) {
        // Send to analytics service
    }
}

// Placeholder types
class NetworkReachability {}
class DatabaseMigrationManager {}
class UserValidator {}
class UserCache {}
class AnalyticsQueue {
    init(maxBatchSize: Int) {}
}

class PaymentProcessor {}
class StripePaymentProcessor: PaymentProcessor {
    init(httpClient: HTTPClientInterface) {}
}

class ChatService {
    init(httpClient: HTTPClientInterface, database: DatabaseInterface) {}
}

class AppCoordinator {
    init(userService: UserServiceInterface, analytics: AnalyticsInterface) {}
}

// MARK: - Usage Example

@main
struct ModuleSystemApp {
    static func main() async throws {
        let app = Application()
        try await app.setup()
        app.resolveServices()

        print("\n✅ Module system successfully initialized!")
    }
}
