//: [Previous: AOP Macros](@previous)
//: # Advanced Patterns
//: ## Complex Dependency Injection Scenarios
//:
//: This page demonstrates advanced usage patterns, combining multiple macros,
//: and handling complex real-world scenarios with SwinJectMacros.

import Foundation
import Swinject

//: ## Combining Multiple Macros
//:
//: Real-world services often benefit from multiple macro combinations:

// MARK: - Domain Models

struct User {
    let id: String
    let name: String
    let email: String
    let preferences: UserPreferences
}

struct UserPreferences {
    let theme: String
    let notifications: Bool
    let language: String
}

struct Order {
    let id: String
    let userId: String
    let items: [OrderItem]
    let total: Decimal
    let status: OrderStatus
}

struct OrderItem {
    let productId: String
    let quantity: Int
    let price: Decimal
}

enum OrderStatus {
    case pending, processing, shipped, delivered, cancelled
}

// MARK: - Repository Layer (Injectable Services)

protocol UserRepository {
    func findUser(id: String) async throws -> User?
    func saveUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

// @Injectable(scope: .container)
class DatabaseUserRepository: UserRepository {
    private let connectionPool: DatabaseConnectionPool
    private let logger: LoggerService

    init(connectionPool: DatabaseConnectionPool, logger: LoggerService) {
        self.connectionPool = connectionPool
        self.logger = logger
    }

    func findUser(id: String) async throws -> User? {
        logger.log("Finding user: \(id)")
        // Database implementation
        return User(
            id: id,
            name: "John Doe",
            email: "john@example.com",
            preferences: UserPreferences(theme: "dark", notifications: true, language: "en")
        )
    }

    func saveUser(_ user: User) async throws {
        logger.log("Saving user: \(user.id)")
        // Database save implementation
    }

    func deleteUser(id: String) async throws {
        logger.log("Deleting user: \(id)")
        // Database delete implementation
    }
}

protocol OrderRepository {
    func findOrder(id: String) async throws -> Order?
    func saveOrder(_ order: Order) async throws
    func findOrdersByUser(userId: String) async throws -> [Order]
}

// @Injectable(scope: .container)
class DatabaseOrderRepository: OrderRepository {
    private let connectionPool: DatabaseConnectionPool
    private let logger: LoggerService

    init(connectionPool: DatabaseConnectionPool, logger: LoggerService) {
        self.connectionPool = connectionPool
        self.logger = logger
    }

    func findOrder(id: String) async throws -> Order? {
        logger.log("Finding order: \(id)")
        return Order(
            id: id,
            userId: "user123",
            items: [OrderItem(productId: "prod1", quantity: 2, price: 19.99)],
            total: 39.98,
            status: .processing
        )
    }

    func saveOrder(_ order: Order) async throws {
        logger.log("Saving order: \(order.id)")
    }

    func findOrdersByUser(userId: String) async throws -> [Order] {
        logger.log("Finding orders for user: \(userId)")
        return []
    }
}

// MARK: - Infrastructure Services

protocol LoggerService {
    func log(_ message: String)
    func error(_ message: String)
    func debug(_ message: String)
}

// @Injectable(scope: .container)
class ConsoleLoggerService: LoggerService {
    init() {
        print("📝 ConsoleLoggerService initialized")
    }

    func log(_ message: String) {
        print("📝 LOG: \(message)")
    }

    func error(_ message: String) {
        print("❌ ERROR: \(message)")
    }

    func debug(_ message: String) {
        print("🐛 DEBUG: \(message)")
    }
}

// @Injectable(scope: .container)
class DatabaseConnectionPool {
    private let maxConnections: Int

    init() {
        maxConnections = 10
        print("🗄️ DatabaseConnectionPool initialized with \(maxConnections) connections")
    }

    func getConnection() -> String {
        "connection-\(UUID().uuidString.prefix(8))"
    }
}

protocol EmailService {
    func sendEmail(to: String, subject: String, body: String) async throws
}

// @Injectable(scope: .container)
class SMTPEmailService: EmailService {
    private let logger: LoggerService

    init(logger: LoggerService) {
        self.logger = logger
    }

    func sendEmail(to: String, subject: String, body: String) async throws {
        logger.log("Sending email to \(to): \(subject)")
        // SMTP implementation
    }
}

//: ## Business Logic Layer with AOP

// Complex service combining @Injectable, @PerformanceTracked, @Cache, and @Retry
// @Injectable
// @PerformanceTracked
// @Cache(ttl: 300)
// @Retry(maxAttempts: 3)
class UserService {
    private let userRepository: UserRepository
    private let logger: LoggerService
    private let emailService: EmailService

    init(userRepository: UserRepository, logger: LoggerService, emailService: EmailService) {
        self.userRepository = userRepository
        self.logger = logger
        self.emailService = emailService
    }

    func getUser(id: String) async throws -> User? {
        logger.log("UserService: Getting user \(id)")
        return try await userRepository.findUser(id: id)
    }

    func createUser(name: String, email: String) async throws -> User {
        logger.log("UserService: Creating user \(name)")

        let user = User(
            id: UUID().uuidString,
            name: name,
            email: email,
            preferences: UserPreferences(theme: "light", notifications: true, language: "en")
        )

        try await userRepository.saveUser(user)

        // Send welcome email
        try await emailService.sendEmail(
            to: email,
            subject: "Welcome!",
            body: "Welcome to our service, \(name)!"
        )

        return user
    }

    func updateUserPreferences(userId: String, preferences: UserPreferences) async throws {
        logger.log("UserService: Updating preferences for user \(userId)")

        guard var user = try await userRepository.findUser(id: userId) else {
            throw ServiceError.userNotFound
        }

        user = User(
            id: user.id,
            name: user.name,
            email: user.email,
            preferences: preferences
        )

        try await userRepository.saveUser(user)
    }
}

enum ServiceError: Error, LocalizedError {
    case userNotFound
    case invalidInput
    case operationFailed

    var errorDescription: String? {
        switch self {
        case .userNotFound: "User not found"
        case .invalidInput: "Invalid input provided"
        case .operationFailed: "Operation failed"
        }
    }
}

//: ## Factory Services for Complex Business Logic

// Service that needs both dependencies and runtime parameters
// @AutoFactory
class OrderProcessingService {
    private let orderRepository: OrderRepository
    private let userRepository: UserRepository
    private let emailService: EmailService
    private let logger: LoggerService

    // Runtime parameters
    private let orderId: String
    private let processingOptions: ProcessingOptions

    struct ProcessingOptions {
        let sendNotifications: Bool
        let validateInventory: Bool
        let calculateTax: Bool
    }

    init(
        orderRepository: OrderRepository,
        userRepository: UserRepository,
        emailService: EmailService,
        logger: LoggerService,
        orderId: String,
        processingOptions: ProcessingOptions
    ) {
        self.orderRepository = orderRepository
        self.userRepository = userRepository
        self.emailService = emailService
        self.logger = logger
        self.orderId = orderId
        self.processingOptions = processingOptions

        logger.log("OrderProcessingService created for order: \(orderId)")
    }

    func processOrder() async throws -> Order {
        logger.log("Processing order: \(orderId)")

        guard let order = try await orderRepository.findOrder(id: orderId) else {
            throw ServiceError.userNotFound
        }

        if processingOptions.validateInventory {
            try await validateInventory(for: order)
        }

        if processingOptions.calculateTax {
            let _ = calculateTax(for: order)
        }

        let processedOrder = Order(
            id: order.id,
            userId: order.userId,
            items: order.items,
            total: order.total,
            status: .processing
        )

        try await orderRepository.saveOrder(processedOrder)

        if processingOptions.sendNotifications {
            try await sendProcessingNotification(for: processedOrder)
        }

        return processedOrder
    }

    private func validateInventory(for order: Order) async throws {
        logger.log("Validating inventory for order: \(order.id)")
        // Inventory validation logic
    }

    private func calculateTax(for order: Order) -> Decimal {
        logger.log("Calculating tax for order: \(order.id)")
        return order.total * 0.08 // 8% tax
    }

    private func sendProcessingNotification(for order: Order) async throws {
        logger.log("Sending processing notification for order: \(order.id)")

        guard let user = try await userRepository.findUser(id: order.userId) else {
            return
        }

        try await emailService.sendEmail(
            to: user.email,
            subject: "Order Processing Started",
            body: "Your order \(order.id) is now being processed."
        )
    }
}

// Generated factory protocol and implementation
protocol OrderProcessingServiceFactory {
    func makeOrderProcessingService(
        orderId: String,
        processingOptions: OrderProcessingService.ProcessingOptions
    ) -> OrderProcessingService
}

class OrderProcessingServiceFactoryImpl: OrderProcessingServiceFactory {
    private let resolver: Resolver

    init(resolver: Resolver) {
        self.resolver = resolver
    }

    func makeOrderProcessingService(
        orderId: String,
        processingOptions: OrderProcessingService.ProcessingOptions
    ) -> OrderProcessingService {
        OrderProcessingService(
            orderRepository: resolver.synchronizedResolve(OrderRepository.self)!,
            userRepository: resolver.synchronizedResolve(UserRepository.self)!,
            emailService: resolver.synchronizedResolve(EmailService.self)!,
            logger: resolver.synchronizedResolve(LoggerService.self)!,
            orderId: orderId,
            processingOptions: processingOptions
        )
    }
}

//: ## Multi-Layer Assembly with Clean Architecture

// Domain layer assembly
class DomainAssembly: Assembly {
    func assemble(container: Container) {
        // Register domain services
        container.register(UserService.self) { resolver in
            UserService(
                userRepository: resolver.resolve(UserRepository.self)!,
                logger: resolver.resolve(LoggerService.self)!,
                emailService: resolver.resolve(EmailService.self)!
            )
        }

        // Register factories
        container.register(OrderProcessingServiceFactory.self) { resolver in
            OrderProcessingServiceFactoryImpl(resolver: resolver)
        }
    }
}

// Infrastructure layer assembly
class InfrastructureAssembly: Assembly {
    func assemble(container: Container) {
        // Register infrastructure services
        container.register(LoggerService.self) { _ in
            ConsoleLoggerService()
        }.inObjectScope(.container)

        container.register(DatabaseConnectionPool.self) { _ in
            DatabaseConnectionPool()
        }.inObjectScope(.container)

        container.register(EmailService.self) { resolver in
            SMTPEmailService(logger: resolver.resolve(LoggerService.self)!)
        }.inObjectScope(.container)

        // Register repositories
        container.register(UserRepository.self) { resolver in
            DatabaseUserRepository(
                connectionPool: resolver.resolve(DatabaseConnectionPool.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }.inObjectScope(.container)

        container.register(OrderRepository.self) { resolver in
            DatabaseOrderRepository(
                connectionPool: resolver.resolve(DatabaseConnectionPool.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }.inObjectScope(.container)
    }
}

//: ## Advanced Testing Patterns

// @TestContainer
class UserServiceIntegrationTests {
    var container: Container!

    // Dependencies to mock
    var userRepository: UserRepository!
    var logger: LoggerService!
    var emailService: EmailService!

    // Service under test
    var userService: UserService!

    func setUp() {
        container = setupTestContainer()

        userRepository = container.resolve(UserRepository.self)!
        logger = container.resolve(LoggerService.self)!
        emailService = container.resolve(EmailService.self)!

        userService = UserService(
            userRepository: userRepository,
            logger: logger,
            emailService: emailService
        )
    }

    // Generated by @TestContainer macro
    func setupTestContainer() -> Container {
        let container = Container()

        registerUserRepository(in: container, mock: MockUserRepository())
        registerLoggerService(in: container, mock: MockLoggerService())
        registerEmailService(in: container, mock: MockEmailService())

        return container
    }

    func registerUserRepository(in container: Container, mock: UserRepository) {
        container.register(UserRepository.self) { _ in mock }.inObjectScope(.graph)
    }

    func registerLoggerService(in container: Container, mock: LoggerService) {
        container.register(LoggerService.self) { _ in mock }.inObjectScope(.graph)
    }

    func registerEmailService(in container: Container, mock: EmailService) {
        container.register(EmailService.self) { _ in mock }.inObjectScope(.graph)
    }
}

// Mock implementations for testing
class MockUserRepository: UserRepository {
    var findUserResult: User?
    var findUserError: Error?
    var saveUserCalled = false
    var deleteUserCalled = false

    func findUser(id: String) async throws -> User? {
        if let error = findUserError {
            throw error
        }
        return findUserResult
    }

    func saveUser(_ user: User) async throws {
        saveUserCalled = true
    }

    func deleteUser(id: String) async throws {
        deleteUserCalled = true
    }
}

class MockLoggerService: LoggerService {
    var logMessages: [String] = []
    var errorMessages: [String] = []
    var debugMessages: [String] = []

    func log(_ message: String) {
        logMessages.append(message)
    }

    func error(_ message: String) {
        errorMessages.append(message)
    }

    func debug(_ message: String) {
        debugMessages.append(message)
    }
}

class MockEmailService: EmailService {
    var sendEmailCalled = false
    var sentEmails: [(to: String, subject: String, body: String)] = []
    var sendEmailError: Error?

    func sendEmail(to: String, subject: String, body: String) async throws {
        sendEmailCalled = true
        if let error = sendEmailError {
            throw error
        }
        sentEmails.append((to: to, subject: subject, body: body))
    }
}

//: ## Configuration-Driven Service Registration

class ConfigurableAssembly: Assembly {
    private let config: AppConfiguration

    init(config: AppConfiguration) {
        self.config = config
    }

    func assemble(container: Container) {
        // Configure logger based on environment
        if config.environment == .development {
            container.register(LoggerService.self) { _ in
                VerboseLoggerService() // More detailed logging for development
            }.inObjectScope(.container)
        } else {
            container.register(LoggerService.self) { _ in
                ConsoleLoggerService() // Standard logging for production
            }.inObjectScope(.container)
        }

        // Configure email service based on environment
        if config.environment == .testing {
            container.register(EmailService.self) { resolver in
                MockEmailService() // No real emails in tests
            }.inObjectScope(.container)
        } else {
            container.register(EmailService.self) { resolver in
                SMTPEmailService(logger: resolver.resolve(LoggerService.self)!)
            }.inObjectScope(.container)
        }
    }
}

struct AppConfiguration {
    enum Environment {
        case development, testing, staging, production
    }

    let environment: Environment
    let databaseURL: String
    let emailProvider: String

    static let development = AppConfiguration(
        environment: .development,
        databaseURL: "sqlite://dev.db",
        emailProvider: "console"
    )

    static let production = AppConfiguration(
        environment: .production,
        databaseURL: "postgresql://prod.db",
        emailProvider: "smtp"
    )
}

class VerboseLoggerService: LoggerService {
    init() {
        print("📝 VerboseLoggerService initialized for development")
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        print("📝 [\(timestamp)] LOG: \(message)")
    }

    func error(_ message: String) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        print("❌ [\(timestamp)] ERROR: \(message)")
    }

    func debug(_ message: String) {
        let timestamp = DateFormatter.iso8601.string(from: Date())
        print("🐛 [\(timestamp)] DEBUG: \(message)")
    }
}

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter
    }()
}

//: ## Testing Advanced Patterns

print("=== Testing Advanced Patterns ===")

// Set up container with multiple assemblies
let container = Container()
let config = AppConfiguration.development

let assembler = Assembler([
    InfrastructureAssembly(),
    DomainAssembly(),
    ConfigurableAssembly(config: config)
], container: container)

print("Container assembled with \(assembler.resolver.container.synchronize { $0.services.count }) services")

// Test user service
let userService = container.resolve(UserService.self)!

Task {
    do {
        // Create a new user
        let newUser = try await userService.createUser(name: "Alice Johnson", email: "alice@example.com")
        print("Created user: \(newUser.name)")

        // Get the user
        let retrievedUser = try await userService.getUser(id: newUser.id)
        print("Retrieved user: \(retrievedUser?.name ?? "none")")

        // Update preferences
        let newPreferences = UserPreferences(theme: "dark", notifications: false, language: "es")
        try await userService.updateUserPreferences(userId: newUser.id, preferences: newPreferences)
        print("Updated user preferences")

    } catch {
        print("User service error: \(error)")
    }
}

// Test factory service
let orderFactory = container.resolve(OrderProcessingServiceFactory.self)!
let processingOptions = OrderProcessingService.ProcessingOptions(
    sendNotifications: true,
    validateInventory: true,
    calculateTax: true
)

let orderProcessor = orderFactory.makeOrderProcessingService(
    orderId: "order-123",
    processingOptions: processingOptions
)

Task {
    do {
        let processedOrder = try await orderProcessor.processOrder()
        print("Processed order: \(processedOrder.id) - Status: \(processedOrder.status)")
    } catch {
        print("Order processing error: \(error)")
    }
}

// Test integration testing setup
let testSuite = UserServiceIntegrationTests()
testSuite.setUp()

let mockRepo = testSuite.userRepository as! MockUserRepository
mockRepo.findUserResult = User(
    id: "test-123",
    name: "Test User",
    email: "test@example.com",
    preferences: UserPreferences(theme: "light", notifications: true, language: "en")
)

Task {
    do {
        let testUser = try await testSuite.userService.getUser(id: "test-123")
        print("Test user retrieved: \(testUser?.name ?? "none")")

        let mockLogger = testSuite.logger as! MockLoggerService
        print("Logger captured \(mockLogger.logMessages.count) messages")
    } catch {
        print("Test error: \(error)")
    }
}

//: ## Best Practices for Advanced Patterns
//:
//: 1. **Layer Separation**: Keep domain logic separate from infrastructure concerns
//: 2. **Factory Usage**: Use factories for services requiring runtime parameters
//: 3. **Scope Management**: Choose appropriate scopes for different service types
//: 4. **Testing Strategy**: Use comprehensive mocking for integration tests
//: 5. **Configuration**: Make service selection configurable for different environments
//: 6. **AOP Integration**: Combine AOP macros thoughtfully for cross-cutting concerns

//: ## Common Patterns
//:
//: - **Repository Pattern**: Data access abstraction with @Injectable
//: - **Factory Pattern**: Dynamic service creation with @AutoFactory
//: - **Observer Pattern**: Event-driven architectures with proper DI
//: - **Decorator Pattern**: Enhanced functionality with AOP macros
//: - **Strategy Pattern**: Configurable algorithms with dependency injection

print("\n✅ Advanced Patterns demonstration complete!")

//: [Next: Real World Example](@next)
