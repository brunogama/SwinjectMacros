//: # SwinJectMacros Playground
//: ## Swift Macro-Powered Dependency Injection
//:
//: This playground demonstrates the capabilities of SwinJectMacros - a compile-time dependency injection framework
//: that leverages Swift 5.9+ macros to generate type-safe Swinject registration code.
//:
//: **What you'll learn:**
//: - How macros eliminate dependency injection boilerplate
//: - Code generation and compilation process
//: - Real-world usage patterns for clean architecture
//: - Testing strategies with automatic mock generation

import Foundation
import Swinject

// Note: In a real project, you would import SwinjectUtilityMacros
// For demonstration purposes, we'll show the equivalent manual code

//: ## Traditional Dependency Injection (Manual Swinject)
//:
//: Let's start by seeing what dependency injection looks like without macros:

// MARK: - Domain Models

struct User {
    let id: String
    let name: String
    let email: String
}

// MARK: - Services (Manual Implementation)

protocol LoggerService {
    func log(_ message: String)
    func error(_ message: String)
}

class ConsoleLoggerService: LoggerService {
    func log(_ message: String) {
        print("📝 LOG: \(message)")
    }

    func error(_ message: String) {
        print("❌ ERROR: \(message)")
    }
}

protocol APIClient {
    func fetchUser(id: String) async throws -> User
}

class NetworkAPIClient: APIClient {
    private let logger: LoggerService

    init(logger: LoggerService) {
        self.logger = logger
    }

    func fetchUser(id: String) async throws -> User {
        logger.log("Fetching user: \(id)")
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(100))
        return User(id: id, name: "John Doe", email: "john@example.com")
    }
}

class UserService {
    private let apiClient: APIClient
    private let logger: LoggerService

    init(apiClient: APIClient, logger: LoggerService) {
        self.apiClient = apiClient
        self.logger = logger
    }

    func getUser(id: String) async throws -> User {
        logger.log("UserService: Getting user \(id)")
        return try await apiClient.fetchUser(id: id)
    }
}

//: ## Manual Container Setup (The Old Way)
//:
//: Without macros, you need to manually register every service:

func setupManualContainer() -> Container {
    let container = Container()

    // Register logger service
    container.register(LoggerService.self) { _ in
        ConsoleLoggerService()
    }.inObjectScope(.container)

    // Register API client with logger dependency
    container.register(APIClient.self) { resolver in
        NetworkAPIClient(logger: resolver.resolve(LoggerService.self)!)
    }.inObjectScope(.container)

    // Register user service with both dependencies
    container.register(UserService.self) { resolver in
        UserService(
            apiClient: resolver.resolve(APIClient.self)!,
            logger: resolver.resolve(LoggerService.self)!
        )
    }

    return container
}

//: ## Testing Manual Setup

let manualContainer = setupManualContainer()
let userService = manualContainer.resolve(UserService.self)!

Task {
    do {
        let user = try await userService.getUser(id: "123")
        print("✅ Retrieved user: \(user.name)")
    } catch {
        print("❌ Failed to get user: \(error)")
    }
}

//: ## Problems with Manual Registration
//:
//: 1. **Boilerplate Code**: Lots of repetitive registration code
//: 2. **Error Prone**: Easy to forget dependencies or get the order wrong
//: 3. **Maintenance**: When you add/remove dependencies, multiple places need updates
//: 4. **Type Safety**: No compile-time verification that dependencies exist
//: 5. **Refactoring**: Hard to refactor service constructors safely

//: ## How SwinJectMacros Solves This
//:
//: The following pages will show how macros eliminate all this boilerplate:
//:
//: - **@Injectable**: Automatic service registration
//: - **@AutoFactory**: Factory pattern for runtime parameters
//: - **@TestContainer**: Automatic test mock generation
//: - **AOP Macros**: Aspect-oriented programming patterns
//:
//: Navigate to the next page to see @Injectable in action!

//: [Next: @Injectable Macro](@next)
