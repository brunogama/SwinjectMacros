//: [Previous: Advanced Patterns](@previous)
//: # Real World Example
//: ## Complete E-Commerce Application with SwinJectMacros
//:
//: This comprehensive example demonstrates a production-ready e-commerce application
//: using all SwinJectMacros features across clean architecture layers.

import Foundation
import Swinject

//: ## Domain Layer - Core Business Logic

// MARK: - Domain Entities

struct Product {
    let id: String
    let name: String
    let price: Decimal
    let category: String
    let stockQuantity: Int
    let imageURL: String?
}

struct User {
    let id: String
    let email: String
    let name: String
    let address: Address?
    let preferences: UserPreferences
}

struct Address {
    let street: String
    let city: String
    let state: String
    let zipCode: String
    let country: String
}

struct UserPreferences {
    let currency: String
    let language: String
    let emailNotifications: Bool
    let theme: String
}

struct Order {
    let id: String
    let userId: String
    let items: [OrderItem]
    let total: Decimal
    let status: OrderStatus
    let createdAt: Date
    let shippingAddress: Address
}

struct OrderItem {
    let productId: String
    let productName: String
    let quantity: Int
    let unitPrice: Decimal
    let totalPrice: Decimal
}

enum OrderStatus {
    case pending, confirmed, processing, shipped, delivered, cancelled
}

struct CartItem {
    let productId: String
    let quantity: Int
}

// MARK: - Domain Services (Business Logic Layer)

// @Injectable
// @PerformanceTracked
// @Cache(ttl: 300)
class ProductCatalogService {
    private let productRepository: ProductRepository
    private let logger: LoggerService

    init(productRepository: ProductRepository, logger: LoggerService) {
        self.productRepository = productRepository
        self.logger = logger
    }

    func searchProducts(query: String, category: String? = nil) async throws -> [Product] {
        logger.log("Searching products: '\(query)' in category: \(category ?? "all")")
        return try await productRepository.searchProducts(query: query, category: category)
    }

    func getProduct(id: String) async throws -> Product? {
        logger.log("Getting product: \(id)")
        return try await productRepository.getProduct(id: id)
    }

    func getFeaturedProducts() async throws -> [Product] {
        logger.log("Getting featured products")
        return try await productRepository.getFeaturedProducts()
    }
}

// @Injectable
class UserAccountService {
    private let userRepository: UserRepository
    private let emailService: EmailService
    private let logger: LoggerService

    init(userRepository: UserRepository, emailService: EmailService, logger: LoggerService) {
        self.userRepository = userRepository
        self.emailService = emailService
        self.logger = logger
    }

    func createAccount(email: String, name: String, password: String) async throws -> User {
        logger.log("Creating account for: \(email)")

        // Check if user already exists
        if let _ = try await userRepository.getUserByEmail(email) {
            throw AccountError.userAlreadyExists
        }

        let user = User(
            id: UUID().uuidString,
            email: email,
            name: name,
            address: nil,
            preferences: UserPreferences(
                currency: "USD",
                language: "en",
                emailNotifications: true,
                theme: "light"
            )
        )

        try await userRepository.saveUser(user)

        // Send welcome email
        try await emailService.sendWelcomeEmail(to: user)

        logger.log("Account created successfully for: \(email)")
        return user
    }

    func updateProfile(userId: String, name: String?, address: Address?) async throws {
        logger.log("Updating profile for user: \(userId)")

        guard let user = try await userRepository.getUser(id: userId) else {
            throw AccountError.userNotFound
        }

        let updatedUser = User(
            id: user.id,
            email: user.email,
            name: name ?? user.name,
            address: address ?? user.address,
            preferences: user.preferences
        )

        try await userRepository.saveUser(updatedUser)
        logger.log("Profile updated for user: \(userId)")
    }
}

// @AutoFactory
class OrderProcessingService {
    private let orderRepository: OrderRepository
    private let productRepository: ProductRepository
    private let userRepository: UserRepository
    private let paymentService: PaymentService
    private let inventoryService: InventoryService
    private let emailService: EmailService
    private let logger: LoggerService

    // Runtime parameters
    private let userId: String
    private let cartItems: [CartItem]
    private let shippingAddress: Address
    private let paymentMethod: PaymentMethod

    init(
        orderRepository: OrderRepository,
        productRepository: ProductRepository,
        userRepository: UserRepository,
        paymentService: PaymentService,
        inventoryService: InventoryService,
        emailService: EmailService,
        logger: LoggerService,
        userId: String,
        cartItems: [CartItem],
        shippingAddress: Address,
        paymentMethod: PaymentMethod
    ) {
        self.orderRepository = orderRepository
        self.productRepository = productRepository
        self.userRepository = userRepository
        self.paymentService = paymentService
        self.inventoryService = inventoryService
        self.emailService = emailService
        self.logger = logger
        self.userId = userId
        self.cartItems = cartItems
        self.shippingAddress = shippingAddress
        self.paymentMethod = paymentMethod

        logger.log("OrderProcessingService created for user: \(userId)")
    }

    func processOrder() async throws -> Order {
        logger.log("Processing order for user: \(userId)")

        // Validate user
        guard let user = try await userRepository.getUser(id: userId) else {
            throw OrderError.userNotFound
        }

        // Validate and reserve inventory
        var orderItems: [OrderItem] = []
        var total: Decimal = 0

        for cartItem in cartItems {
            guard let product = try await productRepository.getProduct(id: cartItem.productId) else {
                throw OrderError.productNotFound(cartItem.productId)
            }

            // Check inventory
            guard try await inventoryService.reserveStock(
                productId: product.id,
                quantity: cartItem.quantity
            ) else {
                throw OrderError.insufficientStock(product.id)
            }

            let itemTotal = product.price * Decimal(cartItem.quantity)
            let orderItem = OrderItem(
                productId: product.id,
                productName: product.name,
                quantity: cartItem.quantity,
                unitPrice: product.price,
                totalPrice: itemTotal
            )

            orderItems.append(orderItem)
            total += itemTotal
        }

        // Process payment
        let paymentResult = try await paymentService.processPayment(
            amount: total,
            method: paymentMethod,
            description: "Order payment for user \(userId)"
        )

        guard paymentResult.success else {
            // Release reserved inventory
            for item in orderItems {
                try await inventoryService.releaseStock(productId: item.productId, quantity: item.quantity)
            }
            throw OrderError.paymentFailed(paymentResult.error)
        }

        // Create order
        let order = Order(
            id: UUID().uuidString,
            userId: userId,
            items: orderItems,
            total: total,
            status: .confirmed,
            createdAt: Date(),
            shippingAddress: shippingAddress
        )

        try await orderRepository.saveOrder(order)

        // Send confirmation email
        try await emailService.sendOrderConfirmation(order: order, to: user)

        logger.log("Order processed successfully: \(order.id)")
        return order
    }
}

// Generated factory protocol and implementation
protocol OrderProcessingServiceFactory {
    func makeOrderProcessingService(
        userId: String,
        cartItems: [CartItem],
        shippingAddress: Address,
        paymentMethod: PaymentMethod
    ) -> OrderProcessingService
}

class OrderProcessingServiceFactoryImpl: OrderProcessingServiceFactory {
    private let resolver: Resolver

    init(resolver: Resolver) {
        self.resolver = resolver
    }

    func makeOrderProcessingService(
        userId: String,
        cartItems: [CartItem],
        shippingAddress: Address,
        paymentMethod: PaymentMethod
    ) -> OrderProcessingService {
        OrderProcessingService(
            orderRepository: resolver.synchronizedResolve(OrderRepository.self)!,
            productRepository: resolver.synchronizedResolve(ProductRepository.self)!,
            userRepository: resolver.synchronizedResolve(UserRepository.self)!,
            paymentService: resolver.synchronizedResolve(PaymentService.self)!,
            inventoryService: resolver.synchronizedResolve(InventoryService.self)!,
            emailService: resolver.synchronizedResolve(EmailService.self)!,
            logger: resolver.synchronizedResolve(LoggerService.self)!,
            userId: userId,
            cartItems: cartItems,
            shippingAddress: shippingAddress,
            paymentMethod: paymentMethod
        )
    }
}

//: ## Infrastructure Layer - External Dependencies

// MARK: - Repository Protocols

protocol ProductRepository {
    func getProduct(id: String) async throws -> Product?
    func searchProducts(query: String, category: String?) async throws -> [Product]
    func getFeaturedProducts() async throws -> [Product]
    func updateStock(productId: String, quantity: Int) async throws
}

protocol UserRepository {
    func getUser(id: String) async throws -> User?
    func getUserByEmail(_ email: String) async throws -> User?
    func saveUser(_ user: User) async throws
    func deleteUser(id: String) async throws
}

protocol OrderRepository {
    func getOrder(id: String) async throws -> Order?
    func getOrdersByUser(userId: String) async throws -> [Order]
    func saveOrder(_ order: Order) async throws
    func updateOrderStatus(orderId: String, status: OrderStatus) async throws
}

// MARK: - Service Protocols

protocol EmailService {
    func sendWelcomeEmail(to user: User) async throws
    func sendOrderConfirmation(order: Order, to user: User) async throws
    func sendShippingNotification(order: Order, to user: User) async throws
}

protocol PaymentService {
    func processPayment(amount: Decimal, method: PaymentMethod, description: String) async throws -> PaymentResult
    func refundPayment(transactionId: String, amount: Decimal) async throws -> PaymentResult
}

protocol InventoryService {
    func getStock(productId: String) async throws -> Int
    func reserveStock(productId: String, quantity: Int) async throws -> Bool
    func releaseStock(productId: String, quantity: Int) async throws
    func updateStock(productId: String, quantity: Int) async throws
}

protocol LoggerService {
    func log(_ message: String)
    func error(_ message: String)
    func debug(_ message: String)
}

// MARK: - Supporting Types

struct PaymentMethod {
    let type: PaymentType
    let details: [String: String]
}

enum PaymentType {
    case creditCard, debitCard, paypal, applePay
}

struct PaymentResult {
    let success: Bool
    let transactionId: String?
    let error: String?
}

enum AccountError: Error, LocalizedError {
    case userAlreadyExists
    case userNotFound
    case invalidCredentials

    var errorDescription: String? {
        switch self {
        case .userAlreadyExists: "User already exists"
        case .userNotFound: "User not found"
        case .invalidCredentials: "Invalid credentials"
        }
    }
}

enum OrderError: Error, LocalizedError {
    case userNotFound
    case productNotFound(String)
    case insufficientStock(String)
    case paymentFailed(String?)
    case orderNotFound

    var errorDescription: String? {
        switch self {
        case .userNotFound: "User not found"
        case .productNotFound(let id): "Product not found: \(id)"
        case .insufficientStock(let id): "Insufficient stock for product: \(id)"
        case .paymentFailed(let error): "Payment failed: \(error ?? "unknown error")"
        case .orderNotFound: "Order not found"
        }
    }
}

// MARK: - Infrastructure Implementations

// @Injectable(scope: .container)
// @Retry(maxAttempts: 3)
class DatabaseProductRepository: ProductRepository {
    private let database: DatabaseConnection
    private let logger: LoggerService

    init(database: DatabaseConnection, logger: LoggerService) {
        self.database = database
        self.logger = logger
    }

    func getProduct(id: String) async throws -> Product? {
        logger.log("Fetching product: \(id)")
        // Mock implementation
        return Product(
            id: id,
            name: "Sample Product",
            price: 29.99,
            category: "electronics",
            stockQuantity: 100,
            imageURL: "https://example.com/product.jpg"
        )
    }

    func searchProducts(query: String, category: String?) async throws -> [Product] {
        logger.log("Searching products: '\(query)' in category: \(category ?? "all")")
        // Mock implementation
        return [
            Product(
                id: "1",
                name: "iPhone 15",
                price: 999.99,
                category: "electronics",
                stockQuantity: 50,
                imageURL: nil
            ),
            Product(
                id: "2",
                name: "MacBook Pro",
                price: 1999.99,
                category: "electronics",
                stockQuantity: 25,
                imageURL: nil
            )
        ]
    }

    func getFeaturedProducts() async throws -> [Product] {
        logger.log("Fetching featured products")
        return try await searchProducts(query: "", category: nil)
    }

    func updateStock(productId: String, quantity: Int) async throws {
        logger.log("Updating stock for product \(productId): \(quantity)")
    }
}

// @Injectable(scope: .container)
class DatabaseUserRepository: UserRepository {
    private let database: DatabaseConnection
    private let logger: LoggerService

    init(database: DatabaseConnection, logger: LoggerService) {
        self.database = database
        self.logger = logger
    }

    func getUser(id: String) async throws -> User? {
        logger.log("Fetching user: \(id)")
        return User(
            id: id,
            email: "user@example.com",
            name: "John Doe",
            address: Address(street: "123 Main St", city: "Anytown", state: "CA", zipCode: "12345", country: "USA"),
            preferences: UserPreferences(currency: "USD", language: "en", emailNotifications: true, theme: "light")
        )
    }

    func getUserByEmail(_ email: String) async throws -> User? {
        logger.log("Fetching user by email: \(email)")
        return nil // Mock: user not found
    }

    func saveUser(_ user: User) async throws {
        logger.log("Saving user: \(user.email)")
    }

    func deleteUser(id: String) async throws {
        logger.log("Deleting user: \(id)")
    }
}

// @Injectable(scope: .container)
class DatabaseOrderRepository: OrderRepository {
    private let database: DatabaseConnection
    private let logger: LoggerService

    init(database: DatabaseConnection, logger: LoggerService) {
        self.database = database
        self.logger = logger
    }

    func getOrder(id: String) async throws -> Order? {
        logger.log("Fetching order: \(id)")
        return nil
    }

    func getOrdersByUser(userId: String) async throws -> [Order] {
        logger.log("Fetching orders for user: \(userId)")
        return []
    }

    func saveOrder(_ order: Order) async throws {
        logger.log("Saving order: \(order.id)")
    }

    func updateOrderStatus(orderId: String, status: OrderStatus) async throws {
        logger.log("Updating order \(orderId) status to: \(status)")
    }
}

// @Injectable(scope: .container)
class SMTPEmailService: EmailService {
    private let logger: LoggerService

    init(logger: LoggerService) {
        self.logger = logger
    }

    func sendWelcomeEmail(to user: User) async throws {
        logger.log("Sending welcome email to: \(user.email)")
        // Mock SMTP implementation
    }

    func sendOrderConfirmation(order: Order, to user: User) async throws {
        logger.log("Sending order confirmation to: \(user.email) for order: \(order.id)")
    }

    func sendShippingNotification(order: Order, to user: User) async throws {
        logger.log("Sending shipping notification to: \(user.email) for order: \(order.id)")
    }
}

// @Injectable(scope: .container)
// @CircuitBreaker(failureThreshold: 5, timeout: 60)
class StripePaymentService: PaymentService {
    private let apiKey: String
    private let logger: LoggerService

    init(logger: LoggerService) {
        apiKey = "mock_stripe_key"
        self.logger = logger
    }

    func processPayment(amount: Decimal, method: PaymentMethod, description: String) async throws -> PaymentResult {
        logger.log("Processing payment: $\(amount) via \(method.type)")

        // Mock payment processing
        await Task.sleep(UInt64(0.5 * 1_000_000_000)) // 0.5 seconds

        return PaymentResult(
            success: true,
            transactionId: "txn_\(UUID().uuidString.prefix(8))",
            error: nil
        )
    }

    func refundPayment(transactionId: String, amount: Decimal) async throws -> PaymentResult {
        logger.log("Processing refund: $\(amount) for transaction: \(transactionId)")

        return PaymentResult(
            success: true,
            transactionId: "refund_\(UUID().uuidString.prefix(8))",
            error: nil
        )
    }
}

// @Injectable(scope: .container)
class RedisInventoryService: InventoryService {
    private let redis: RedisConnection
    private let logger: LoggerService

    init(redis: RedisConnection, logger: LoggerService) {
        self.redis = redis
        self.logger = logger
    }

    func getStock(productId: String) async throws -> Int {
        logger.log("Getting stock for product: \(productId)")
        return 100 // Mock stock level
    }

    func reserveStock(productId: String, quantity: Int) async throws -> Bool {
        logger.log("Reserving \(quantity) units of product: \(productId)")
        let currentStock = try await getStock(productId: productId)
        return currentStock >= quantity
    }

    func releaseStock(productId: String, quantity: Int) async throws {
        logger.log("Releasing \(quantity) units of product: \(productId)")
    }

    func updateStock(productId: String, quantity: Int) async throws {
        logger.log("Updating stock for product \(productId) to: \(quantity)")
    }
}

// @Injectable(scope: .container)
class ConsoleLoggerService: LoggerService {
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

// MARK: - Infrastructure Support

class DatabaseConnection {
    func query(_ sql: String) -> [Any] { [] }
    func execute(_ sql: String) -> Bool { true }
}

class RedisConnection {
    func get(_ key: String) -> String? { nil }
    func set(_ key: String, value: String) -> Bool { true }
}

//: ## Application Layer - Assembly and Configuration

// MARK: - Layer Assemblies

class DomainAssembly: Assembly {
    func assemble(container: Container) {
        // Register domain services
        container.register(ProductCatalogService.self) { resolver in
            ProductCatalogService(
                productRepository: resolver.resolve(ProductRepository.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }

        container.register(UserAccountService.self) { resolver in
            UserAccountService(
                userRepository: resolver.resolve(UserRepository.self)!,
                emailService: resolver.resolve(EmailService.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }

        // Register factories
        container.register(OrderProcessingServiceFactory.self) { resolver in
            OrderProcessingServiceFactoryImpl(resolver: resolver)
        }
    }
}

class InfrastructureAssembly: Assembly {
    func assemble(container: Container) {
        // Register infrastructure dependencies
        container.register(DatabaseConnection.self) { _ in
            DatabaseConnection()
        }.inObjectScope(.container)

        container.register(RedisConnection.self) { _ in
            RedisConnection()
        }.inObjectScope(.container)

        // Register repositories
        container.register(ProductRepository.self) { resolver in
            DatabaseProductRepository(
                database: resolver.resolve(DatabaseConnection.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }.inObjectScope(.container)

        container.register(UserRepository.self) { resolver in
            DatabaseUserRepository(
                database: resolver.resolve(DatabaseConnection.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }.inObjectScope(.container)

        container.register(OrderRepository.self) { resolver in
            DatabaseOrderRepository(
                database: resolver.resolve(DatabaseConnection.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }.inObjectScope(.container)

        // Register services
        container.register(EmailService.self) { resolver in
            SMTPEmailService(logger: resolver.resolve(LoggerService.self)!)
        }.inObjectScope(.container)

        container.register(PaymentService.self) { resolver in
            StripePaymentService(logger: resolver.resolve(LoggerService.self)!)
        }.inObjectScope(.container)

        container.register(InventoryService.self) { resolver in
            RedisInventoryService(
                redis: resolver.resolve(RedisConnection.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }.inObjectScope(.container)

        container.register(LoggerService.self) { _ in
            ConsoleLoggerService()
        }.inObjectScope(.container)
    }
}

//: ## Testing with @TestContainer

// @TestContainer
class OrderProcessingIntegrationTests {
    var container: Container!

    // Mock dependencies
    var orderRepository: OrderRepository!
    var productRepository: ProductRepository!
    var userRepository: UserRepository!
    var paymentService: PaymentService!
    var inventoryService: InventoryService!
    var emailService: EmailService!
    var logger: LoggerService!

    // Factory under test
    var orderFactory: OrderProcessingServiceFactory!

    func setUp() {
        container = setupTestContainer()

        orderRepository = container.resolve(OrderRepository.self)!
        productRepository = container.resolve(ProductRepository.self)!
        userRepository = container.resolve(UserRepository.self)!
        paymentService = container.resolve(PaymentService.self)!
        inventoryService = container.resolve(InventoryService.self)!
        emailService = container.resolve(EmailService.self)!
        logger = container.resolve(LoggerService.self)!

        orderFactory = container.resolve(OrderProcessingServiceFactory.self)!
    }

    // Generated by @TestContainer macro
    func setupTestContainer() -> Container {
        let container = Container()

        registerOrderRepository(in: container, mock: MockOrderRepository())
        registerProductRepository(in: container, mock: MockProductRepository())
        registerUserRepository(in: container, mock: MockUserRepository())
        registerPaymentService(in: container, mock: MockPaymentService())
        registerInventoryService(in: container, mock: MockInventoryService())
        registerEmailService(in: container, mock: MockEmailService())
        registerLoggerService(in: container, mock: MockLoggerService())

        container.register(OrderProcessingServiceFactory.self) { resolver in
            OrderProcessingServiceFactoryImpl(resolver: resolver)
        }

        return container
    }

    func registerOrderRepository(in container: Container, mock: OrderRepository) {
        container.register(OrderRepository.self) { _ in mock }.inObjectScope(.graph)
    }

    func registerProductRepository(in container: Container, mock: ProductRepository) {
        container.register(ProductRepository.self) { _ in mock }.inObjectScope(.graph)
    }

    func registerUserRepository(in container: Container, mock: UserRepository) {
        container.register(UserRepository.self) { _ in mock }.inObjectScope(.graph)
    }

    func registerPaymentService(in container: Container, mock: PaymentService) {
        container.register(PaymentService.self) { _ in mock }.inObjectScope(.graph)
    }

    func registerInventoryService(in container: Container, mock: InventoryService) {
        container.register(InventoryService.self) { _ in mock }.inObjectScope(.graph)
    }

    func registerEmailService(in container: Container, mock: EmailService) {
        container.register(EmailService.self) { _ in mock }.inObjectScope(.graph)
    }

    func registerLoggerService(in container: Container, mock: LoggerService) {
        container.register(LoggerService.self) { _ in mock }.inObjectScope(.graph)
    }

    func testSuccessfulOrderProcessing() async throws {
        // Given
        let mockUser = userRepository as! MockUserRepository
        let mockProduct = productRepository as! MockProductRepository
        let mockInventory = inventoryService as! MockInventoryService
        let mockPayment = paymentService as! MockPaymentService

        mockUser.getUserResult = User(
            id: "user123",
            email: "test@example.com",
            name: "Test User",
            address: nil,
            preferences: UserPreferences(currency: "USD", language: "en", emailNotifications: true, theme: "light")
        )

        mockProduct.getProductResult = Product(
            id: "prod123",
            name: "Test Product",
            price: 29.99,
            category: "test",
            stockQuantity: 100,
            imageURL: nil
        )

        mockInventory.reserveStockResult = true
        mockPayment.processPaymentResult = PaymentResult(success: true, transactionId: "txn123", error: nil)

        // When
        let cartItems = [CartItem(productId: "prod123", quantity: 2)]
        let shippingAddress = Address(
            street: "123 Main St",
            city: "Test City",
            state: "TS",
            zipCode: "12345",
            country: "USA"
        )
        let paymentMethod = PaymentMethod(type: .creditCard, details: [:])

        let orderProcessor = orderFactory.makeOrderProcessingService(
            userId: "user123",
            cartItems: cartItems,
            shippingAddress: shippingAddress,
            paymentMethod: paymentMethod
        )

        let order = try await orderProcessor.processOrder()

        // Then
        assert(order.userId == "user123")
        assert(order.items.count == 1)
        assert(order.status == .confirmed)
        assert(mockInventory.reserveStockCalled)
        assert(mockPayment.processPaymentCalled)
    }
}

// MARK: - Mock Implementations for Testing

class MockOrderRepository: OrderRepository {
    var saveOrderCalled = false
    var savedOrder: Order?

    func getOrder(id: String) async throws -> Order? { nil }
    func getOrdersByUser(userId: String) async throws -> [Order] { [] }
    func saveOrder(_ order: Order) async throws {
        saveOrderCalled = true
        savedOrder = order
    }

    func updateOrderStatus(orderId: String, status: OrderStatus) async throws {}
}

class MockProductRepository: ProductRepository {
    var getProductResult: Product?
    var getProductCalled = false

    func getProduct(id: String) async throws -> Product? {
        getProductCalled = true
        return getProductResult
    }

    func searchProducts(query: String, category: String?) async throws -> [Product] { [] }
    func getFeaturedProducts() async throws -> [Product] { [] }
    func updateStock(productId: String, quantity: Int) async throws {}
}

class MockUserRepository: UserRepository {
    var getUserResult: User?
    var getUserCalled = false

    func getUser(id: String) async throws -> User? {
        getUserCalled = true
        return getUserResult
    }

    func getUserByEmail(_ email: String) async throws -> User? { nil }
    func saveUser(_ user: User) async throws {}
    func deleteUser(id: String) async throws {}
}

class MockPaymentService: PaymentService {
    var processPaymentResult = PaymentResult(success: true, transactionId: "mock", error: nil)
    var processPaymentCalled = false

    func processPayment(amount: Decimal, method: PaymentMethod, description: String) async throws -> PaymentResult {
        processPaymentCalled = true
        return processPaymentResult
    }

    func refundPayment(transactionId: String, amount: Decimal) async throws -> PaymentResult {
        PaymentResult(success: true, transactionId: "refund", error: nil)
    }
}

class MockInventoryService: InventoryService {
    var reserveStockResult = true
    var reserveStockCalled = false

    func getStock(productId: String) async throws -> Int { 100 }
    func reserveStock(productId: String, quantity: Int) async throws -> Bool {
        reserveStockCalled = true
        return reserveStockResult
    }

    func releaseStock(productId: String, quantity: Int) async throws {}
    func updateStock(productId: String, quantity: Int) async throws {}
}

class MockEmailService: EmailService {
    var sendWelcomeEmailCalled = false
    var sendOrderConfirmationCalled = false

    func sendWelcomeEmail(to user: User) async throws {
        sendWelcomeEmailCalled = true
    }

    func sendOrderConfirmation(order: Order, to user: User) async throws {
        sendOrderConfirmationCalled = true
    }

    func sendShippingNotification(order: Order, to user: User) async throws {}
}

class MockLoggerService: LoggerService {
    var logMessages: [String] = []

    func log(_ message: String) { logMessages.append(message) }
    func error(_ message: String) { logMessages.append("ERROR: \(message)") }
    func debug(_ message: String) { logMessages.append("DEBUG: \(message)") }
}

//: ## Complete Application Demo

print("=== E-Commerce Application Demo ===")

// Set up the complete application
let container = Container()
let assembler = Assembler([
    InfrastructureAssembly(),
    DomainAssembly()
], container: container)

print("Container assembled with \(assembler.resolver.container.synchronize { $0.services.count }) services")

// Test user account creation
let userAccountService = container.resolve(UserAccountService.self)!

Task {
    do {
        // Create new user account
        let newUser = try await userAccountService.createAccount(
            email: "john.doe@example.com",
            name: "John Doe",
            password: "secure123"
        )
        print("✅ Created user account: \(newUser.name) (\(newUser.email))")

        // Update user profile
        let address = Address(
            street: "456 Oak Street",
            city: "San Francisco",
            state: "CA",
            zipCode: "94102",
            country: "USA"
        )
        try await userAccountService.updateProfile(
            userId: newUser.id,
            name: "John A. Doe",
            address: address
        )
        print("✅ Updated user profile")

        // Search for products
        let catalogService = container.resolve(ProductCatalogService.self)!
        let products = try await catalogService.searchProducts(query: "iPhone", category: "electronics")
        print("✅ Found \(products.count) products")

        // Process an order
        let orderFactory = container.resolve(OrderProcessingServiceFactory.self)!
        let cartItems = [CartItem(productId: "1", quantity: 1)]
        let paymentMethod = PaymentMethod(type: .creditCard, details: ["last4": "1234"])

        let orderProcessor = orderFactory.makeOrderProcessingService(
            userId: newUser.id,
            cartItems: cartItems,
            shippingAddress: address,
            paymentMethod: paymentMethod
        )

        let order = try await orderProcessor.processOrder()
        print("✅ Processed order: \(order.id) - Total: $\(order.total)")

    } catch {
        print("❌ Application error: \(error)")
    }
}

// Test integration testing
let integrationTests = OrderProcessingIntegrationTests()
integrationTests.setUp()

Task {
    do {
        try await integrationTests.testSuccessfulOrderProcessing()
        print("✅ Integration tests passed")
    } catch {
        print("❌ Integration test failed: \(error)")
    }
}

//: ## Key Architecture Benefits
//:
//: 1. **Clean Architecture**: Clear separation between Domain, Infrastructure, and Application layers
//: 2. **Dependency Inversion**: High-level modules don't depend on low-level modules
//: 3. **Testability**: Easy to mock dependencies for unit and integration testing
//: 4. **Maintainability**: Changes to infrastructure don't affect business logic
//: 5. **Scalability**: New features can be added without modifying existing code
//: 6. **Type Safety**: Compile-time verification of all dependencies

//: ## Production Deployment Considerations
//:
//: - **Environment Configuration**: Use different assemblies for dev/staging/production
//: - **Database Connections**: Implement proper connection pooling and retry logic
//: - **API Rate Limiting**: Add circuit breakers and retry policies for external services
//: - **Monitoring**: Integrate with APM tools for performance tracking
//: - **Caching**: Implement Redis or in-memory caching for frequently accessed data
//: - **Security**: Add authentication, authorization, and input validation layers

print("\n✅ Real World E-Commerce Application demonstration complete!")

//: ## Summary
//:
//: This example demonstrates how SwinJectMacros enables building complex, production-ready
//: applications with clean architecture principles:
//:
//: - **@Injectable**: For stateless services and repositories
//: - **@AutoFactory**: For services needing runtime parameters (order processing)
//: - **@TestContainer**: For comprehensive integration testing
//: - **AOP Macros**: For cross-cutting concerns (logging, performance, caching, retry, circuit breaking)
//:
//: The result is maintainable, testable, and scalable code that follows SOLID principles
//: while minimizing boilerplate through compile-time code generation.
