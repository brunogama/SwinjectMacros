//: [Previous: @Injectable Macro](@previous)
//: # @AutoFactory Macro
//: ## Factory Pattern Generation for Runtime Parameters
//:
//: The `@AutoFactory` macro generates factory protocols and implementations for services
//: that need both dependency injection AND runtime parameters.

import Foundation
import Swinject

//: ## When to Use @AutoFactory
//:
//: Use `@AutoFactory` when your service needs:
//: - Injected dependencies (services, repositories, etc.)
//: - Runtime parameters (user input, request data, dynamic config)
//:
//: **Problem**: You can't pre-register services with runtime parameters in the container
//: **Solution**: Generate factories that inject dependencies but accept runtime parameters

// Supporting types
struct User {
    let id: String
    let name: String
    let email: String
}

struct ReportType {
    let name: String
    let format: String
}

struct SearchFilter {
    let category: String
    let minDate: Date?
    let maxDate: Date?
}

// MARK: - Services for Dependency Injection

protocol DatabaseService {
    func query<T>(_ query: String) -> [T]
    func save(_ entity: some Any)
}

class MockDatabaseService: DatabaseService {
    func query<T>(_ query: String) -> [T] {
        print("🗄️ Executing query: \(query)")
        return []
    }

    func save<T>(_ entity: T) {
        print("🗄️ Saving entity: \(T.self)")
    }
}

protocol LoggerService {
    func log(_ message: String)
}

class ConsoleLoggerService: LoggerService {
    func log(_ message: String) {
        print("📝 \(message)")
    }
}

//: ## Basic @AutoFactory Example

// What you write:
// @AutoFactory
class ReportGenerator {
    private let database: DatabaseService // Injected dependency
    private let logger: LoggerService // Injected dependency
    private let reportType: ReportType // Runtime parameter
    private let userId: String // Runtime parameter

    init(database: DatabaseService, logger: LoggerService, reportType: ReportType, userId: String) {
        self.database = database
        self.logger = logger
        self.reportType = reportType
        self.userId = userId

        logger.log("ReportGenerator created for user \(userId), type: \(reportType.name)")
    }

    func generateReport() -> String {
        logger.log("Generating \(reportType.name) report for user \(userId)")
        let data: [String] = database.query("SELECT * FROM reports WHERE user_id = '\(userId)'")
        return "Report generated with \(data.count) records"
    }
}

// What the macro generates:

// 1. Factory Protocol
protocol ReportGeneratorFactory {
    func makeReportGenerator(reportType: ReportType, userId: String) -> ReportGenerator
}

// 2. Factory Implementation
class ReportGeneratorFactoryImpl: ReportGeneratorFactory {
    private let resolver: Resolver

    init(resolver: Resolver) {
        self.resolver = resolver
    }

    func makeReportGenerator(reportType: ReportType, userId: String) -> ReportGenerator {
        ReportGenerator(
            database: resolver.synchronizedResolve(DatabaseService.self)!, // Injected
            logger: resolver.synchronizedResolve(LoggerService.self)!, // Injected
            reportType: reportType, // Runtime param
            userId: userId // Runtime param
        )
    }
}

//: ## @AutoFactory with Async Support

// What you write:
// @AutoFactory(async: true)
class AsyncDataProcessor {
    private let database: DatabaseService // Injected dependency
    private let logger: LoggerService // Injected dependency
    private let data: Data // Runtime parameter

    init(database: DatabaseService, logger: LoggerService, data: Data) async {
        self.database = database
        self.logger = logger
        self.data = data

        // Async initialization
        logger.log("AsyncDataProcessor initializing with \(data.count) bytes")
        await Task.sleep(UInt64(0.1 * 1_000_000_000)) // 0.1 seconds
        logger.log("AsyncDataProcessor initialization complete")
    }

    func process() async -> String {
        logger.log("Processing data...")
        await Task.sleep(UInt64(0.2 * 1_000_000_000)) // 0.2 seconds
        database.save(data)
        return "Processed \(data.count) bytes"
    }
}

// What the macro generates:

protocol AsyncDataProcessorFactory {
    func makeAsyncDataProcessor(data: Data) async -> AsyncDataProcessor
}

class AsyncDataProcessorFactoryImpl: AsyncDataProcessorFactory {
    private let resolver: Resolver

    init(resolver: Resolver) {
        self.resolver = resolver
    }

    func makeAsyncDataProcessor(data: Data) async -> AsyncDataProcessor {
        await AsyncDataProcessor(
            database: resolver.synchronizedResolve(DatabaseService.self)!,
            logger: resolver.synchronizedResolve(LoggerService.self)!,
            data: data
        )
    }
}

//: ## @AutoFactory with Throws Support

// What you write:
// @AutoFactory(throws: true)
class ValidatedUserService {
    private let database: DatabaseService // Injected dependency
    private let logger: LoggerService // Injected dependency
    private let userEmail: String // Runtime parameter

    enum ValidationError: Error, LocalizedError {
        case invalidEmail
        case userExists

        var errorDescription: String? {
            switch self {
            case .invalidEmail: "Invalid email format"
            case .userExists: "User already exists"
            }
        }
    }

    init(database: DatabaseService, logger: LoggerService, userEmail: String) throws {
        self.database = database
        self.logger = logger

        // Validation logic
        guard userEmail.contains("@") && userEmail.contains(".") else {
            logger.log("Invalid email format: \(userEmail)")
            throw ValidationError.invalidEmail
        }

        let existingUsers: [User] = database.query("SELECT * FROM users WHERE email = '\(userEmail)'")
        guard existingUsers.isEmpty else {
            logger.log("User already exists: \(userEmail)")
            throw ValidationError.userExists
        }

        self.userEmail = userEmail
        logger.log("ValidatedUserService created for: \(userEmail)")
    }

    func createUser(name: String) -> User {
        logger.log("Creating user: \(name) (\(userEmail))")
        let user = User(id: UUID().uuidString, name: name, email: userEmail)
        database.save(user)
        return user
    }
}

// What the macro generates:

protocol ValidatedUserServiceFactory {
    func makeValidatedUserService(userEmail: String) throws -> ValidatedUserService
}

class ValidatedUserServiceFactoryImpl: ValidatedUserServiceFactory {
    private let resolver: Resolver

    init(resolver: Resolver) {
        self.resolver = resolver
    }

    func makeValidatedUserService(userEmail: String) throws -> ValidatedUserService {
        try ValidatedUserService(
            database: resolver.synchronizedResolve(DatabaseService.self)!,
            logger: resolver.synchronizedResolve(LoggerService.self)!,
            userEmail: userEmail
        )
    }
}

//: ## @AutoFactory with Multiple Runtime Parameters

// What you write:
// @AutoFactory
class SearchService {
    private let database: DatabaseService // Injected dependency
    private let logger: LoggerService // Injected dependency
    private let query: String // Runtime parameter
    private let filters: [SearchFilter] // Runtime parameter
    private let limit: Int // Runtime parameter

    init(database: DatabaseService, logger: LoggerService, query: String, filters: [SearchFilter], limit: Int) {
        self.database = database
        self.logger = logger
        self.query = query
        self.filters = filters
        self.limit = limit

        logger.log("SearchService created - Query: '\(query)', Filters: \(filters.count), Limit: \(limit)")
    }

    func search() -> [String] {
        logger.log("Executing search: '\(query)' with \(filters.count) filters")

        var sqlQuery = "SELECT * FROM items WHERE title LIKE '%\(query)%'"

        for filter in filters {
            sqlQuery += " AND category = '\(filter.category)'"
        }

        sqlQuery += " LIMIT \(limit)"

        let results: [String] = database.query(sqlQuery)
        logger.log("Search returned \(results.count) results")

        // Mock results for demo
        return (0..<min(limit, 3)).map { "Result \($0 + 1) for '\(query)'" }
    }
}

// What the macro generates:

protocol SearchServiceFactory {
    func makeSearchService(query: String, filters: [SearchFilter], limit: Int) -> SearchService
}

class SearchServiceFactoryImpl: SearchServiceFactory {
    private let resolver: Resolver

    init(resolver: Resolver) {
        self.resolver = resolver
    }

    func makeSearchService(query: String, filters: [SearchFilter], limit: Int) -> SearchService {
        SearchService(
            database: resolver.synchronizedResolve(DatabaseService.self)!,
            logger: resolver.synchronizedResolve(LoggerService.self)!,
            query: query,
            filters: filters,
            limit: limit
        )
    }
}

//: ## Container Setup for Factories

class FactoryAssembly: Assembly {
    func assemble(container: Container) {
        // Register dependencies first
        container.register(DatabaseService.self) { _ in
            MockDatabaseService()
        }.inObjectScope(.container)

        container.register(LoggerService.self) { _ in
            ConsoleLoggerService()
        }.inObjectScope(.container)

        // Register factories (IMPORTANT: Not automatic - must be manual)
        container.register(ReportGeneratorFactory.self) { resolver in
            ReportGeneratorFactoryImpl(resolver: resolver)
        }

        container.register(AsyncDataProcessorFactory.self) { resolver in
            AsyncDataProcessorFactoryImpl(resolver: resolver)
        }

        container.register(ValidatedUserServiceFactory.self) { resolver in
            ValidatedUserServiceFactoryImpl(resolver: resolver)
        }

        container.register(SearchServiceFactory.self) { resolver in
            SearchServiceFactoryImpl(resolver: resolver)
        }
    }
}

//: ## Testing AutoFactory Services

let container = Container()
let assembler = Assembler([FactoryAssembly()], container: container)

print("=== Testing @AutoFactory Services ===")

// Test basic factory
let reportFactory = container.resolve(ReportGeneratorFactory.self)!
let reportType = ReportType(name: "Sales Report", format: "PDF")
let reportGenerator = reportFactory.makeReportGenerator(reportType: reportType, userId: "user123")
let report = reportGenerator.generateReport()
print("Generated: \(report)")

// Test async factory
let asyncFactory = container.resolve(AsyncDataProcessorFactory.self)!
let testData = "Hello, World!".data(using: .utf8)!

Task {
    let processor = await asyncFactory.makeAsyncDataProcessor(data: testData)
    let result = await processor.process()
    print("Async processing result: \(result)")
}

// Test throwing factory
let userFactory = container.resolve(ValidatedUserServiceFactory.self)!

do {
    let validUserService = try userFactory.makeValidatedUserService(userEmail: "valid@example.com")
    let user = validUserService.createUser(name: "John Doe")
    print("Created valid user: \(user.name)")
} catch {
    print("Failed to create user service: \(error)")
}

do {
    _ = try userFactory.makeValidatedUserService(userEmail: "invalid-email")
} catch {
    print("Expected validation error: \(error.localizedDescription)")
}

// Test multi-parameter factory
let searchFactory = container.resolve(SearchServiceFactory.self)!
let filters = [SearchFilter(category: "electronics", minDate: nil, maxDate: nil)]
let searchService = searchFactory.makeSearchService(query: "iPhone", filters: filters, limit: 5)
let searchResults = searchService.search()
print("Search results: \(searchResults)")

//: ## Key Benefits of @AutoFactory
//:
//: 1. **Separation of Concerns**: Dependencies vs runtime parameters are clearly separated
//: 2. **Type Safety**: Factory methods are strongly typed
//: 3. **Async/Throws Support**: Preserves original initializer characteristics
//: 4. **Clean API**: Generated factory methods have intuitive signatures
//: 5. **Dependency Injection**: Services are automatically resolved from container
//: 6. **Testing**: Easy to mock factories for unit testing

//: ## Factory vs Injectable Decision Matrix
//:
//: | Service Type | Dependencies Only | Runtime Parameters | Use |
//: |---|---|---|---|
//: | Logger, Database, API Client | ✅ | ❌ | `@Injectable` |
//: | Report Generator | ✅ | ✅ (report type, user) | `@AutoFactory` |
//: | Search Service | ✅ | ✅ (query, filters) | `@AutoFactory` |
//: | Configuration Service | ✅ | ❌ | `@Injectable` |

//: ## Important Notes
//:
//: - **Factory Registration**: Factories must be manually registered (not automatic)
//: - **Target Placement**: Generated code lives in the same SPM target as your service
//: - **Clean Architecture**: Works across Domain/Infrastructure/Presentation layers
//: - **Dependency Resolution**: Automatically resolves services from any layer

print("\n✅ @AutoFactory demonstration complete!")

//: [Next: @TestContainer Macro](@next)
