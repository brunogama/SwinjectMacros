//: [Previous: Introduction](@previous)
//: # @Injectable Macro
//: ## Automatic Service Registration
//:
//: The `@Injectable` macro analyzes your service's initializer and automatically generates
//: the registration code for Swinject containers.

import Foundation
import Swinject

// In a real project: import SwinJectMacros

//: ## How @Injectable Works
//: 
//: The macro performs compile-time analysis:
//: 1. **AST Parsing**: Examines initializer parameters using SwiftSyntax
//: 2. **Dependency Classification**: Identifies service dependencies vs configuration
//: 3. **Code Generation**: Creates static `register(in:)` method
//: 4. **Protocol Conformance**: Adds `Injectable` protocol via extension

// MARK: - Injectable Protocol (would be provided by SwinJectMacros)

protocol Injectable {
    static func register(in container: Container)
}

// MARK: - Basic @Injectable Example

// What you write:
// @Injectable
class LoggerService: Injectable {
    init() {
        print("📝 LoggerService initialized")
    }
    
    func log(_ message: String) {
        print("📝 LOG: \(message)")
    }
    
    // What the macro generates:
    static func register(in container: Container) {
        container.register(LoggerService.self) { resolver in
            LoggerService()
        }.inObjectScope(.graph)
    }
}

//: ## Service with Dependencies

// What you write:
// @Injectable
class APIClient: Injectable {
    private let logger: LoggerService
    
    init(logger: LoggerService) {
        self.logger = logger
        logger.log("APIClient initialized")
    }
    
    func fetchData<T>(from endpoint: String) -> T? {
        logger.log("Fetching data from: \(endpoint)")
        return nil
    }
    
    // What the macro generates:
    static func register(in container: Container) {
        container.register(APIClient.self) { resolver in
            APIClient(
                logger: resolver.synchronizedResolve(LoggerService.self)!
            )
        }.inObjectScope(.graph)
    }
}

//: ## Complex Service with Multiple Dependencies

// What you write:
// @Injectable
class UserService: Injectable {
    private let apiClient: APIClient
    private let logger: LoggerService
    
    init(apiClient: APIClient, logger: LoggerService) {
        self.apiClient = apiClient
        self.logger = logger
        logger.log("UserService initialized")
    }
    
    func getUser(id: String) -> User? {
        logger.log("Getting user: \(id)")
        let userData: User? = apiClient.fetchData(from: "users/\(id)")
        
        // Mock user for demo
        return User(id: id, name: "John Doe", email: "john@example.com")
    }
    
    // What the macro generates:
    static func register(in container: Container) {
        container.register(UserService.self) { resolver in
            UserService(
                apiClient: resolver.synchronizedResolve(APIClient.self)!,
                logger: resolver.synchronizedResolve(LoggerService.self)!
            )
        }.inObjectScope(.graph)
    }
}

//: ## @Injectable with Scoping

// What you write:
// @Injectable(scope: .container)
class DatabaseService: Injectable {
    private let connectionString: String
    
    init() {
        self.connectionString = "mock://database"
        print("🗄️ DatabaseService initialized (expensive operation)")
    }
    
    func save<T>(_ entity: T) {
        print("🗄️ Saving entity to database")
    }
    
    // What the macro generates:
    static func register(in container: Container) {
        container.register(DatabaseService.self) { resolver in
            DatabaseService()
        }.inObjectScope(.container) // Singleton scope
    }
}

//: ## @Injectable with Optional Dependencies

// What you write:
// @Injectable
class AnalyticsService: Injectable {
    private let logger: LoggerService?
    private let database: DatabaseService
    
    init(logger: LoggerService?, database: DatabaseService) {
        self.logger = logger
        self.database = database
        logger?.log("AnalyticsService initialized")
    }
    
    func track(event: String) {
        logger?.log("Tracking event: \(event)")
        database.save(event)
    }
    
    // What the macro generates:
    static func register(in container: Container) {
        container.register(AnalyticsService.self) { resolver in
            AnalyticsService(
                logger: resolver.synchronizedResolve(LoggerService.self), // No force unwrap for optionals
                database: resolver.synchronizedResolve(DatabaseService.self)!
            )
        }.inObjectScope(.graph)
    }
}

//: ## @Injectable with Named Registration

// What you write:
// @Injectable(name: "primary")
class PrimaryEmailService: Injectable {
    init() {
        print("📧 Primary EmailService initialized")
    }
    
    func sendEmail(to: String, subject: String) {
        print("📧 Sending email to \(to): \(subject)")
    }
    
    // What the macro generates:
    static func register(in container: Container) {
        container.register(EmailService.self, name: "primary") { resolver in
            PrimaryEmailService()
        }.inObjectScope(.graph)
    }
}

// What you write:
// @Injectable(name: "backup")
class BackupEmailService: Injectable {
    init() {
        print("📧 Backup EmailService initialized")
    }
    
    func sendEmail(to: String, subject: String) {
        print("📧 [BACKUP] Sending email to \(to): \(subject)")
    }
    
    // What the macro generates:
    static func register(in container: Container) {
        container.register(EmailService.self, name: "backup") { resolver in
            BackupEmailService()
        }.inObjectScope(.graph)
    }
}

protocol EmailService {
    func sendEmail(to: String, subject: String)
}

extension PrimaryEmailService: EmailService {}
extension BackupEmailService: EmailService {}

//: ## Automatic Container Setup

class InjectableAssembly: Assembly {
    func assemble(container: Container) {
        // Instead of manual registration, just call the generated methods:
        LoggerService.register(in: container)
        APIClient.register(in: container)
        UserService.register(in: container)
        DatabaseService.register(in: container)
        AnalyticsService.register(in: container)
        PrimaryEmailService.register(in: container)
        BackupEmailService.register(in: container)
    }
}

//: ## Testing the Injectable Services

let container = Container()
let assembler = Assembler([InjectableAssembly()], container: container)

print("=== Testing @Injectable Services ===")

// Test basic service
let logger = container.resolve(LoggerService.self)!
logger.log("Testing logger service")

// Test service with dependencies
let userService = container.resolve(UserService.self)!
let user = userService.getUser(id: "123")
print("Retrieved user: \(user?.name ?? "none")")

// Test singleton scoping
let db1 = container.resolve(DatabaseService.self)!
let db2 = container.resolve(DatabaseService.self)!
print("Database services are same instance: \(db1 === db2)")

// Test optional dependencies
let analytics = container.resolve(AnalyticsService.self)!
analytics.track(event: "user_login")

// Test named services
let primaryEmail = container.resolve(EmailService.self, name: "primary")!
let backupEmail = container.resolve(EmailService.self, name: "backup")!
primaryEmail.sendEmail(to: "user@example.com", subject: "Welcome!")
backupEmail.sendEmail(to: "user@example.com", subject: "Backup notification")

//: ## Key Benefits of @Injectable
//: 
//: 1. **Zero Boilerplate**: No manual registration code needed
//: 2. **Type Safety**: Compile-time verification of dependencies
//: 3. **Automatic Updates**: Adding/removing dependencies updates registration automatically
//: 4. **Smart Classification**: Automatically distinguishes service dependencies from config
//: 5. **Scope Control**: Easy configuration of object lifetimes
//: 6. **Named Services**: Support for multiple implementations

//: ## Dependency Classification Rules
//: 
//: The macro uses these heuristics to classify parameters:
//: 
//: | Parameter Pattern | Classification | Resolution |
//: |---|---|---|
//: | `*Service`, `*Repository`, `*Client` | Service Dependency | `resolver.resolve(Type.self)!` |
//: | `any Protocol`, `some Protocol` | Protocol Dependency | `resolver.resolve(Protocol.self)!` |
//: | Optional types (`Type?`) | Optional Dependency | `resolver.resolve(Type.self)` |
//: | Parameters with defaults | Configuration | Use default value |

print("\n✅ @Injectable demonstration complete!")

//: [Next: @AutoFactory Macro](@next)