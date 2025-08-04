// QuickStart Example - A complete working example demonstrating SwinJectMacros
// Run this with: swift run QuickStartExample

import Foundation
import Swinject

#if canImport(SwinJectMacros)
    import SwinjectUtilityMacros
#endif

// MARK: - Simple Example without Macros (The Old Way)

print("🔥 SwinJectMacros QuickStart Example")
print("=====================================")

// MARK: - Domain Models

struct User {
    let id: String
    let name: String
    let email: String
}

struct Article {
    let id: String
    let title: String
    let content: String
    let authorId: String
}

// MARK: - 1. Basic Services with @Injectable

#if canImport(SwinJectMacros)

    @Injectable
    class LoggerService {
        init() {
            print("📝 LoggerService initialized")
        }

        func log(_ message: String) {
            print("📝 LOG: \(message)")
        }
    }

    @Injectable(scope: .container) // Singleton
    class ConfigurationService {
        let apiBaseURL: String
        let maxRetries: Int

        init() {
            // In real app, this would load from plist, environment, etc.
            apiBaseURL = "https://api.example.com"
            maxRetries = 3
            print("⚙️ ConfigurationService initialized")
        }
    }

    @Injectable(scope: .container) // Expensive to create, so make it singleton
    class NetworkClient {
        private let config: ConfigurationService

        init(config: ConfigurationService) {
            self.config = config
            print("🌍 NetworkClient initialized with base URL: \(config.apiBaseURL)")
        }

        func fetchData<T>(from path: String) -> T? {
            print("🌍 Fetching data from: \(config.apiBaseURL)/\(path)")
            // Mock implementation
            return nil
        }
    }

    // MARK: - 2. Business Logic Services

    @Injectable
    class UserService {
        private let networkClient: NetworkClient
        private let logger: LoggerService

        init(networkClient: NetworkClient, logger: LoggerService) {
            self.networkClient = networkClient
            self.logger = logger
            logger.log("UserService initialized")
        }

        func getUser(id: String) -> User? {
            logger.log("Fetching user with ID: \(id)")

            // In real implementation, this would make a network call
            let userData: User? = networkClient.fetchData(from: "users/\(id)")

            // For demo, return a mock user
            let mockUser = User(id: id, name: "John Doe", email: "john@example.com")
            logger.log("User fetched: \(mockUser.name)")
            return mockUser
        }

        func createUser(name: String, email: String) -> User {
            logger.log("Creating user: \(name)")

            let user = User(id: UUID().uuidString, name: name, email: email)

            // In real implementation, this would save to backend
            logger.log("User created with ID: \(user.id)")
            return user
        }
    }

    // MARK: - 3. Factory Example for Runtime Parameters

    @AutoFactory
    class ArticleSearchService {
        private let networkClient: NetworkClient // Injected dependency
        private let logger: LoggerService // Injected dependency
        private let searchQuery: String // Runtime parameter
        private let maxResults: Int // Runtime parameter

        init(networkClient: NetworkClient, logger: LoggerService, searchQuery: String, maxResults: Int) {
            self.networkClient = networkClient
            self.logger = logger
            self.searchQuery = searchQuery
            self.maxResults = maxResults

            logger.log("ArticleSearchService created for query: '\(searchQuery)' (max: \(maxResults))")
        }

        func search() -> [Article] {
            logger.log("Searching for articles matching: '\(searchQuery)'")

            // In real implementation, this would search via network
            let _: [Article]? = networkClient
                .fetchData(from: "articles/search?q=\(searchQuery)&limit=\(maxResults)")

            // Return mock results for demo
            let mockResults = (1...min(3, maxResults)).map { index in
                Article(
                    id: "article_\(index)",
                    title: "Article \(index) about \(self.searchQuery)",
                    content: "This is the content of article \(index)...",
                    authorId: "author_\(index)"
                )
            }

            logger.log("Found \(mockResults.count) articles")
            return mockResults
        }
    }

    // MARK: - 4. Application Assembly

    class QuickStartAssembly: Assembly {
        func assemble(container: Container) {
            print("🔧 Assembling dependencies...")

            // Register all @Injectable services
            LoggerService.register(in: container)
            ConfigurationService.register(in: container)
            NetworkClient.register(in: container)
            UserService.register(in: container)

            // Register factories for services with runtime parameters
            container.registerFactory(ArticleSearchServiceFactory.self)

            print("✅ All dependencies registered!")
        }
    }

    // MARK: - 5. Demo Application

    func runQuickStartDemo() {
        print("\n🚀 Starting QuickStart Demo...")

        // Set up dependency injection
        let container = Container()
        let assembler = Assembler([QuickStartAssembly()], container: container)

        print("\n--- Testing Basic Services ---")

        // Get services from container
        let userService = container.resolve(UserService.self)!

        // Use the user service
        let user1 = userService.getUser(id: "123")
        print("Retrieved user: \(user1?.name ?? "none")")

        let user2 = userService.createUser(name: "Alice Smith", email: "alice@example.com")
        print("Created user: \(user2.name)")

        print("\n--- Testing Factory Services ---")

        // Get the factory for services that need runtime parameters
        let searchFactory = container.resolve(ArticleSearchServiceFactory.self)!

        // Create search services with different parameters
        let searchService1 = searchFactory.makeArticleSearchService(
            searchQuery: "Swift programming",
            maxResults: 5
        )

        let articles1 = searchService1.search()
        print("First search found \(articles1.count) articles")

        let searchService2 = searchFactory.makeArticleSearchService(
            searchQuery: "iOS development",
            maxResults: 2
        )

        let articles2 = searchService2.search()
        print("Second search found \(articles2.count) articles")
        for article in articles2 {
            print("  - \(article.title)")
        }

        print("\n--- Verifying Scoping ---")

        // Container-scoped services should be the same instance
        let config1 = container.resolve(ConfigurationService.self)!
        let config2 = container.resolve(ConfigurationService.self)!
        print("Configuration services are same instance: \(config1 === config2)")

        let network1 = container.resolve(NetworkClient.self)!
        let network2 = container.resolve(NetworkClient.self)!
        print("Network clients are same instance: \(network1 === network2)")

        // Graph-scoped services should be different instances
        let user1Service = container.resolve(UserService.self)!
        let user2Service = container.resolve(UserService.self)!
        print("User services are different instances: \(user1Service !== user2Service)")

        print("\n✅ QuickStart Demo Complete!")
        print("\nKey Benefits Demonstrated:")
        print("  ✅ Zero boilerplate for service registration")
        print("  ✅ Automatic dependency resolution")
        print("  ✅ Proper object scoping (singleton vs new instances)")
        print("  ✅ Factory pattern for runtime parameters")
        print("  ✅ Clean, maintainable code")
    }

#else

    func runQuickStartDemo() {
        print("❌ SwinJectMacros not available - this example requires the macro library")
        print("This would normally show how much boilerplate code you avoid with SwinJectMacros!")

        // Show what you'd have to write manually without macros
        print("\n--- Without SwinJectMacros (Manual Registration) ---")

        let container = Container()

        // Manual registration - lots of boilerplate!
        container.register(LoggerService.self) { _ in
            LoggerService()
        }

        container.register(ConfigurationService.self) { _ in
            ConfigurationService()
        }.inObjectScope(.container)

        container.register(NetworkClient.self) { resolver in
            NetworkClient(config: resolver.resolve(ConfigurationService.self)!)
        }.inObjectScope(.container)

        container.register(UserService.self) { resolver in
            UserService(
                networkClient: resolver.resolve(NetworkClient.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }

        // And you'd need to manually create factories too...

        print("Manual registration complete - but look at all that boilerplate code!")
        print("With SwinJectMacros, all of this is generated automatically! 🎉")
    }

#endif

// MARK: - Run the Demo

runQuickStartDemo()

print("\n🎯 Next Steps:")
print("1. Check out Examples/GettingStarted.md for detailed tutorials")
print("2. Read the main README.md for complete macro documentation")
print("3. Try integrating SwinJectMacros into your own project!")
print("4. Explore the test files to see how testing works")

// MARK: - Supporting Classes for Non-Macro Example

#if !canImport(SwinJectMacros)

    class LoggerService {
        init() {
            print("📝 LoggerService initialized")
        }

        func log(_ message: String) {
            print("📝 LOG: \(message)")
        }
    }

    class ConfigurationService {
        let apiBaseURL: String
        let maxRetries: Int

        init() {
            apiBaseURL = "https://api.example.com"
            maxRetries = 3
            print("⚙️ ConfigurationService initialized")
        }
    }

    class NetworkClient {
        private let config: ConfigurationService

        init(config: ConfigurationService) {
            self.config = config
            print("🌍 NetworkClient initialized with base URL: \(config.apiBaseURL)")
        }

        func fetchData<T>(from path: String) -> T? {
            print("🌍 Fetching data from: \(config.apiBaseURL)/\(path)")
            return nil
        }
    }

    class UserService {
        private let networkClient: NetworkClient
        private let logger: LoggerService

        init(networkClient: NetworkClient, logger: LoggerService) {
            self.networkClient = networkClient
            self.logger = logger
            logger.log("UserService initialized")
        }

        func getUser(id: String) -> User? {
            logger.log("Fetching user with ID: \(id)")
            let mockUser = User(id: id, name: "John Doe", email: "john@example.com")
            logger.log("User fetched: \(mockUser.name)")
            return mockUser
        }

        func createUser(name: String, email: String) -> User {
            logger.log("Creating user: \(name)")
            let user = User(id: UUID().uuidString, name: name, email: email)
            logger.log("User created with ID: \(user.id)")
            return user
        }
    }

#endif
