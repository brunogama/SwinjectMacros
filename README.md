# SwinJectMacros

**Advanced Dependency Injection Utilities for Swift using Compile-Time Macros**

SwinJectMacros brings the power of Swift Macros to dependency injection, dramatically reducing boilerplate code while maintaining type safety and performance. Built on top of the proven [Swinject](https://github.com/Swinject/Swinject) framework, it provides 25+ compile-time macros for modern Swift applications.

[![Swift](https://img.shields.io/badge/swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-lightgrey.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()

## 🎯 Why SwinJectMacros?

Traditional dependency injection in Swift requires significant boilerplate code:

### ❌ **Before: Traditional Swinject (Lots of Boilerplate)**

```swift
// Service Definition
class UserService {
    private let apiClient: APIClient
    private let database: DatabaseService
    private let logger: LoggerService
    
    init(apiClient: APIClient, database: DatabaseService, logger: LoggerService) {
        self.apiClient = apiClient
        self.database = database
        self.logger = logger
    }
}

// Manual Registration (Repetitive & Error-Prone)
class AppAssembly: Assembly {
    func assemble(container: Container) {
        container.register(APIClient.self) { _ in 
            APIClientImpl() 
        }.inObjectScope(.container)
        
        container.register(DatabaseService.self) { _ in 
            DatabaseServiceImpl() 
        }.inObjectScope(.container)
        
        container.register(LoggerService.self) { _ in 
            LoggerServiceImpl() 
        }.inObjectScope(.graph)
        
        container.register(UserService.self) { resolver in
            UserService(
                apiClient: resolver.resolve(APIClient.self)!,
                database: resolver.resolve(DatabaseService.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }.inObjectScope(.graph)
    }
}
```

### ✅ **After: SwinJectMacros (Clean & Concise)**

```swift
// Service Definition with Auto-Registration
@Injectable
class UserService {
    private let apiClient: APIClient
    private let database: DatabaseService  
    private let logger: LoggerService
    
    init(apiClient: APIClient, database: DatabaseService, logger: LoggerService) {
        self.apiClient = apiClient
        self.database = database
        self.logger = logger
    }
}

@Injectable(scope: .container)
class APIClientImpl: APIClient { /* implementation */ }

@Injectable(scope: .container) 
class DatabaseServiceImpl: DatabaseService { /* implementation */ }

@Injectable
class LoggerServiceImpl: LoggerService { /* implementation */ }

// That's it! Registration is automatically generated at compile-time
```

## 🚀 Key Benefits

- **🔥 Zero Runtime Overhead**: All code generation happens at compile-time
- **🎯 Type Safety**: Full Swift type system integration with compile-time validation
- **📝 Dramatically Less Code**: Reduce dependency injection boilerplate by 80%+
- **🔍 Better Error Messages**: Clear, actionable compile-time diagnostics
- **⚡ Performance**: No reflection, no runtime lookups - pure Swift performance
- **🧪 Testing Made Easy**: Automatic mock generation and test container setup
- **🏗️ Factory Patterns**: Automatic factory generation for services with runtime parameters

## 📋 Table of Contents

### 🚀 Getting Started
- [📦 Installation](#-installation)
- [📋 Requirements](#-requirements)
- [🏗️ Complete Example: Real-World Application](#️-complete-example-real-world-application)

### 🎓 Core Macros Guide
- [1. @Injectable - Automatic Service Registration](#1-injectable---automatic-service-registration)
  - [🤔 Why @Injectable?](#-why-injectable)
  - [📖 How It Works](#-how-it-works)
  - [🔧 Basic Usage](#-basic-usage)
  - [⚙️ Advanced Configuration](#️-advanced-configuration)
    - [Object Scopes](#object-scopes)
    - [Named Services](#named-services)
    - [Optional Dependencies](#optional-dependencies)
  - [🎯 Smart Dependency Classification](#-smart-dependency-classification)

- [2. @AutoFactory - Factory Pattern Generation](#2-autofactory---factory-pattern-generation)
  - [🤔 Why @AutoFactory?](#-why-autofactory)
  - [📖 How It Works](#-how-it-works-1)
  - [🔧 Basic Usage](#-basic-usage-1)
  - [⚙️ Advanced Configuration](#️-advanced-configuration-1)
    - [Async/Throws Support](#asyncthrows-support)
    - [Custom Factory Names](#custom-factory-names)
    - [Factory Registration and Usage](#factory-registration-and-usage)

- [3. @TestContainer - Test Mock Generation](#3-testcontainer---test-mock-generation)
  - [🤔 Why @TestContainer?](#-why-testcontainer)
  - [📖 How It Works](#-how-it-works-2)
  - [🔧 Basic Usage](#-basic-usage-2)
  - [⚙️ Advanced Configuration](#️-advanced-configuration-2)
    - [Custom Mock Prefix](#custom-mock-prefix)
    - [Custom Scope](#custom-scope)
    - [Manual Mock Control](#manual-mock-control)
    - [Spy Generation (Future Feature)](#spy-generation-future-feature)

- [4. @Interceptor - Aspect-Oriented Programming](#4-interceptor---aspect-oriented-programming)
  - [🤔 Why @Interceptor?](#-why-interceptor)
  - [📖 How It Works](#-how-it-works-3)
  - [🔧 Basic Usage](#-basic-usage-3)
  - [⚙️ Advanced Configuration](#️-advanced-configuration-3)
    - [Async/Throws Support](#asyncthrows-support-1)
    - [Static Method Interception](#static-method-interception)
  - [🛠️ Creating Custom Interceptors](#️-creating-custom-interceptors)
  - [🏭 Built-in Interceptors](#-built-in-interceptors)
    - [LoggingInterceptor](#logginginterceptor)
    - [PerformanceInterceptor](#performanceinterceptor)
  - [🔄 Interceptor Registration](#-interceptor-registration)
  - [🎯 Real-World Example: E-commerce Service](#-real-world-example-e-commerce-service)
  - [⚡ Performance Benefits](#-performance-benefits)

### 📚 Guides & Best Practices
- [🎯 Best Practices](#-best-practices)
  - [Service Design Guidelines](#1-service-design-guidelines)
  - [Scope Selection](#2-scope-selection)
  - [Factory vs Injectable Decision](#3-factory-vs-injectable-decision)
  - [Testing Strategy](#4-testing-strategy)
- [⚠️ Common Pitfalls & Solutions](#️-common-pitfalls--solutions)
  - [Circular Dependencies](#1-circular-dependencies)
  - [Runtime Parameters in @Injectable](#2-runtime-parameters-in-injectable)
  - [Missing Protocol Registrations](#3-missing-protocol-registrations)

### 🔗 Resources
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [🙏 Acknowledgments](#-acknowledgments)

---

## 📦 Installation

### Swift Package Manager

Add SwinJectMacros to your project via Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/YourUsername/SwinJectMacros.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["SwinJectMacros"]
    )
]
```

## 📋 Requirements

- **Swift 5.9+** (Required for macro support)
- **iOS 15.0+** / **macOS 12.0+** / **watchOS 8.0+** / **tvOS 15.0+**
- **Xcode 15.0+**

## 🎓 Core Macros Guide

### 1. @Injectable - Automatic Service Registration

The `@Injectable` macro automatically generates dependency injection registration code for your services.

#### 🤔 **Why @Injectable?**

**Problem**: Manually writing registration code for every service is:
- Repetitive and error-prone
- Hard to maintain when dependencies change
- Requires updating multiple places when refactoring
- Easy to forget registrations for new services

**Solution**: `@Injectable` analyzes your service's initializer and automatically generates the correct registration code with proper dependency resolution.

#### 📖 **How It Works**

The macro examines your class/struct initializer and:
1. **Identifies service dependencies** (types ending in Service, Repository, Client, etc.)
2. **Generates resolver calls** for each dependency
3. **Creates a static `register(in:)` method** 
4. **Adds `Injectable` protocol conformance**

#### 🔧 **Basic Usage**

```swift
import SwinJectMacros
import Swinject

// Simple service with dependencies
@Injectable
class UserService {
    private let apiClient: APIClient
    private let database: DatabaseService
    
    init(apiClient: APIClient, database: DatabaseService) {
        self.apiClient = apiClient
        self.database = database
    }
    
    func getUser(id: String) async throws -> User {
        let userData = try await apiClient.fetchUser(id: id)
        try await database.save(userData)
        return User(from: userData)
    }
}
```

**Generated Code** (you don't write this!):
```swift
extension UserService: Injectable {
    static func register(in container: Container) {
        container.register(UserService.self) { resolver in
            UserService(
                apiClient: resolver.resolve(APIClient.self)!,
                database: resolver.resolve(DatabaseService.self)!
            )
        }.inObjectScope(.graph)
    }
}
```

#### ⚙️ **Advanced Configuration**

##### Object Scopes

Control the lifecycle of your services:

```swift
@Injectable(scope: .container)  // Singleton - one instance per container
class DatabaseService {
    init() { /* expensive setup */ }
}

@Injectable(scope: .graph)      // Default - new instance per object graph
class UserService {
    init(database: DatabaseService) { /* ... */ }
}

@Injectable(scope: .singleton)  // Global singleton - one instance ever
class ConfigurationService {
    init() { /* app-wide config */ }
}
```

##### Named Services

Register multiple implementations of the same protocol:

```swift
protocol PaymentProcessor {
    func process(payment: Payment) async throws
}

@Injectable(name: "stripe")
class StripePaymentProcessor: PaymentProcessor {
    init(apiKey: String) { /* ... */ }
}

@Injectable(name: "paypal") 
class PayPalPaymentProcessor: PaymentProcessor {
    init(clientId: String, secret: String) { /* ... */ }
}

// Usage
let stripeProcessor = container.resolve(PaymentProcessor.self, name: "stripe")
let paypalProcessor = container.resolve(PaymentProcessor.self, name: "paypal")
```

##### Optional Dependencies

Handle optional dependencies gracefully:

```swift
@Injectable
class AnalyticsService {
    private let logger: LoggerService?  // Optional dependency
    private let database: DatabaseService // Required dependency
    
    init(logger: LoggerService?, database: DatabaseService) {
        self.logger = logger
        self.database = database
    }
}

// Generated registration handles optionals correctly:
// logger: resolver.resolve(LoggerService.self)  // No force unwrap for optionals
// database: resolver.resolve(DatabaseService.self)!  // Force unwrap for required
```

#### 🎯 **Smart Dependency Classification**

The macro automatically classifies your parameters:

| Parameter Type | Classification | Resolution Strategy |
|---|---|---|
| `UserService`, `APIClient` | Service Dependency | `resolver.resolve(Type.self)!` |
| `any DatabaseProtocol` | Protocol Dependency | `resolver.resolve(Protocol.self)!` |
| `String`, `Int`, `Bool` | Runtime Parameter | ⚠️ Warning - consider `@AutoFactory` |
| `String = "default"` | Configuration Parameter | Use default value |

### 2. @AutoFactory - Factory Pattern Generation

The `@AutoFactory` macro generates factory protocols and implementations for services that need runtime parameters.

#### 🤔 **Why @AutoFactory?**

**Problem**: Some services need both injected dependencies AND runtime parameters:
- User input (search terms, user IDs, etc.)
- Dynamic configuration
- Request-specific data
- You can't pre-register these in the container

**Traditional Solution** (lots of boilerplate):
```swift
// Manual factory - lots of repetitive code
protocol UserSearchServiceFactory {
    func makeUserSearchService(query: String, filters: [Filter]) -> UserSearchService
}

class UserSearchServiceFactoryImpl: UserSearchServiceFactory {
    private let resolver: Resolver
    
    init(resolver: Resolver) {
        self.resolver = resolver
    }
    
    func makeUserSearchService(query: String, filters: [Filter]) -> UserSearchService {
        return UserSearchService(
            apiClient: resolver.resolve(APIClient.self)!,
            database: resolver.resolve(DatabaseService.self)!,
            query: query,
            filters: filters
        )
    }
}
```

**SwinJectMacros Solution** (automatic):
```swift
@AutoFactory
class UserSearchService {
    private let apiClient: APIClient      // Injected dependency
    private let database: DatabaseService // Injected dependency
    private let query: String            // Runtime parameter
    private let filters: [Filter]        // Runtime parameter
    
    init(apiClient: APIClient, database: DatabaseService, query: String, filters: [Filter]) {
        // implementation
    }
}
```

#### 📖 **How It Works**

The macro analyzes your initializer and:
1. **Separates injected dependencies** from runtime parameters
2. **Generates a factory protocol** with a `make` method for runtime parameters only
3. **Generates a factory implementation** that resolves dependencies and accepts runtime parameters
4. **Handles async/throws automatically**

#### 🔧 **Basic Usage**

```swift
@AutoFactory
class ReportGenerator {
    private let database: DatabaseService  // Injected
    private let emailService: EmailService // Injected
    private let reportType: ReportType     // Runtime parameter
    private let dateRange: DateRange       // Runtime parameter
    
    init(database: DatabaseService, emailService: EmailService, 
         reportType: ReportType, dateRange: DateRange) {
        self.database = database
        self.emailService = emailService
        self.reportType = reportType
        self.dateRange = dateRange
    }
    
    func generateAndSend() async throws {
        let report = try await database.generateReport(type: reportType, range: dateRange)
        try await emailService.send(report)
    }
}
```

**Generated Code**:
```swift
// Factory Protocol
protocol ReportGeneratorFactory {
    func makeReportGenerator(reportType: ReportType, dateRange: DateRange) -> ReportGenerator
}

// Factory Implementation  
class ReportGeneratorFactoryImpl: ReportGeneratorFactory, BaseFactory {
    let resolver: Resolver
    
    init(resolver: Resolver) {
        self.resolver = resolver
    }
    
    func makeReportGenerator(reportType: ReportType, dateRange: DateRange) -> ReportGenerator {
        ReportGenerator(
            database: resolver.resolve(DatabaseService.self)!,
            emailService: resolver.resolve(EmailService.self)!,
            reportType: reportType,
            dateRange: dateRange
        )
    }
}
```

#### ⚙️ **Advanced Configuration**

##### Async/Throws Support

```swift
@AutoFactory(async: true, throws: true)
class AsyncDataProcessor {
    private let apiClient: APIClient  // Injected
    private let data: Data           // Runtime parameter
    
    init(apiClient: APIClient, data: Data) async throws {
        self.apiClient = apiClient
        // Async initialization logic
        try await apiClient.validateData(data)
    }
}

// Generated factory method signature:
// func makeAsyncDataProcessor(data: Data) async throws -> AsyncDataProcessor
```

##### Custom Factory Names

```swift
@AutoFactory(name: "CustomReportFactory")
class ReportService {
    init(database: DatabaseService, reportId: String) { /* ... */ }
}

// Generates: protocol CustomReportFactory { ... }
// Instead of: protocol ReportServiceFactory { ... }
```

##### Factory Registration and Usage

```swift
// In your assembly
class AppAssembly: Assembly {
    func assemble(container: Container) {
        // Register your services
        container.register(DatabaseService.self) { _ in DatabaseServiceImpl() }
        container.register(EmailService.self) { _ in EmailServiceImpl() }
        
        // Register the factory
        container.registerFactory(ReportGeneratorFactory.self)
    }
}

// Usage in your application
class ReportsViewController: UIViewController {
    private let reportFactory: ReportGeneratorFactory
    
    init(reportFactory: ReportGeneratorFactory) {
        self.reportFactory = reportFactory
        super.init(nibName: nil, bundle: nil)
    }
    
    @IBAction func generateReport() {
        let generator = reportFactory.makeReportGenerator(
            reportType: .monthly,
            dateRange: DateRange(start: startDate, end: endDate)
        )
        
        Task {
            try await generator.generateAndSend()
        }
    }
}
```

### 3. @TestContainer - Test Mock Generation

The `@TestContainer` macro automatically generates test container setup with mocks for your test classes.

#### 🤔 **Why @TestContainer?**

**Problem**: Setting up dependency injection for tests is tedious:
- Creating mock objects for every dependency
- Registering all mocks in the test container  
- Maintaining test setup as dependencies change
- Ensuring test isolation

**Traditional Approach** (lots of test boilerplate):
```swift
class UserServiceTests: XCTestCase {
    var container: Container!
    var mockAPIClient: MockAPIClient!
    var mockDatabase: MockDatabaseService!
    var mockLogger: MockLoggerService!
    var userService: UserService!
    
    override func setUp() {
        super.setUp()
        container = Container()
        
        // Create all mocks manually
        mockAPIClient = MockAPIClient()
        mockDatabase = MockDatabaseService()
        mockLogger = MockLoggerService()
        
        // Register all mocks manually
        container.register(APIClient.self) { _ in self.mockAPIClient }
        container.register(DatabaseService.self) { _ in self.mockDatabase }
        container.register(LoggerService.self) { _ in self.mockLogger }
        
        userService = container.resolve(UserService.self)!
    }
}
```

**SwinJectMacros Approach** (automatic):
```swift
@TestContainer
class UserServiceTests: XCTestCase {
    var apiClient: APIClient!
    var database: DatabaseService!
    var logger: LoggerService!
    
    // Container setup is automatically generated!
}
```

#### 📖 **How It Works**

The macro scans your test class properties and:
1. **Identifies service properties** (types ending in Service, Repository, Client, etc.)
2. **Generates a `setupTestContainer()` method** that creates and configures a container
3. **Generates mock registration helpers** for each service type
4. **Supports custom mock prefixes and scopes**

#### 🔧 **Basic Usage**

```swift
import XCTest
import SwinJectMacros

@TestContainer
class UserServiceTests: XCTestCase {
    var container: Container!
    
    // These properties are detected as services needing mocks
    var apiClient: APIClient!
    var database: DatabaseService!
    var logger: LoggerService!
    
    override func setUp() {
        super.setUp()
        container = setupTestContainer() // Generated method!
        
        // Services are automatically registered with mocks
        apiClient = container.resolve(APIClient.self)!
        database = container.resolve(DatabaseService.self)!
        logger = container.resolve(LoggerService.self)!
    }
    
    func testUserCreation() {
        // Your test logic here
        // All dependencies are automatically mocked
    }
}
```

**Generated Code**:
```swift
extension UserServiceTests {
    func setupTestContainer() -> Container {
        let container = Container()
        
        registerAPIClient(mock: MockAPIClient())
        registerDatabaseService(mock: MockDatabaseService())
        registerLoggerService(mock: MockLoggerService())
        
        return container
    }
    
    func registerAPIClient(mock: APIClient) {
        container.register(APIClient.self) { _ in mock }.inObjectScope(.graph)
    }
    
    func registerDatabaseService(mock: DatabaseService) {
        container.register(DatabaseService.self) { _ in mock }.inObjectScope(.graph)
    }
    
    func registerLoggerService(mock: LoggerService) {
        container.register(LoggerService.self) { _ in mock }.inObjectScope(.graph)
    }
}
```

#### ⚙️ **Advanced Configuration**

##### Custom Mock Prefix

```swift
@TestContainer(mockPrefix: "Stub")
class UserServiceTests: XCTestCase {
    var apiClient: APIClient!
    var database: DatabaseService!
}

// Generates: StubAPIClient(), StubDatabaseService()
// Instead of: MockAPIClient(), MockDatabaseService()
```

##### Custom Scope

```swift
@TestContainer(scope: .container)
class UserServiceTests: XCTestCase {
    var database: DatabaseService! // Will be registered as singleton
}
```

##### Manual Mock Control

```swift
@TestContainer(autoMock: false)
class UserServiceTests: XCTestCase {
    var apiClient: APIClient!
    
    override func setUp() {
        super.setUp()
        container = setupTestContainer()
        
        // Provide your own mock implementation
        let customMock = MyCustomAPIClientMock()
        registerAPIClient(mock: customMock)
        
        apiClient = container.resolve(APIClient.self)!
    }
}
```

##### Spy Generation (Future Feature)

```swift
@TestContainer(generateSpies: true)
class UserServiceTests: XCTestCase {
    var apiClient: APIClient!
    
    func testAPIClientCalled() {
        // Generated spy functionality
        userService.performAction()
        
        XCTAssertEqual(apiClientSpy.fetchUserCalls.count, 1)
        XCTAssertEqual(apiClientSpy.fetchUserCalls.first?.userId, "123")
    }
}
```

### 4. @Interceptor - Aspect-Oriented Programming

The `@Interceptor` macro brings powerful aspect-oriented programming (AOP) capabilities to Swift, allowing you to implement cross-cutting concerns like logging, security, caching, and validation without cluttering your business logic.

#### 🤔 **Why @Interceptor?**

**Problem**: Cross-cutting concerns create code duplication and coupling:

- Logging scattered throughout business methods
- Security checks mixed with business logic
- Performance monitoring code everywhere
- Error handling repeated in every method
- Caching logic coupled to business operations

**Traditional Approach** (scattered concerns):

```swift
class PaymentService {
    func processPayment(amount: Double, cardToken: String) -> PaymentResult {
        // Logging
        logger.log("Processing payment: \(amount)")
        let startTime = Date()
        
        // Security validation
        guard SecurityValidator.validateToken(cardToken) else {
            logger.error("Invalid card token")
            throw PaymentError.invalidToken
        }
        
        // Business logic (buried in boilerplate)
        let result = doActualPaymentProcessing(amount: amount, token: cardToken)
        
        // More logging
        let duration = Date().timeIntervalSince(startTime)
        logger.log("Payment completed in \(duration)ms")
        
        // Audit logging
        auditLogger.log("Payment processed: \(result)")
        
        return result
    }
}
```

#### ✅ **With @Interceptor** (clean separation):

```swift
class PaymentService {
    @Interceptor(
        before: ["SecurityInterceptor", "LoggingInterceptor"],
        after: ["AuditInterceptor", "PerformanceInterceptor"]
    )
    func processPayment(amount: Double, cardToken: String) -> PaymentResult {
        // Pure business logic - no clutter!
        return doActualPaymentProcessing(amount: amount, token: cardToken)
    }
}
```

#### 📖 **How It Works**

The `@Interceptor` macro generates an intercepted version of your method that:

1. **Creates rich context** with method name, parameters, types, and execution metadata
2. **Executes before interceptors** in specified order for setup/validation
3. **Calls your original method** with full error handling
4. **Executes after interceptors** in reverse order (LIFO) for cleanup
5. **Handles errors** with dedicated error interceptors
6. **Provides performance metrics** with execution timing

#### 🔧 **Basic Usage**

```swift
// Simple logging interceptor
@Interceptor(before: ["LoggingInterceptor"])
func createUser(userData: UserData) -> User {
    return UserRepository.create(userData)
}

// Multiple interceptor types
@Interceptor(
    before: ["ValidationInterceptor", "SecurityInterceptor"],
    after: ["CacheInterceptor", "NotificationInterceptor"],
    onError: ["ErrorReportingInterceptor"]
)
func updateUserProfile(userId: String, profile: UserProfile) throws -> UserProfile {
    return try UserRepository.update(userId: userId, profile: profile)
}
```

#### ⚙️ **Advanced Configuration**

##### Async/Throws Support

```swift
// Async method interception
@Interceptor(before: ["AsyncSecurityInterceptor"])
func fetchUserData(userId: String) async throws -> UserData {
    return try await APIClient.fetchUser(userId)
}

// Error handling with interceptors
@Interceptor(onError: ["ErrorTransformInterceptor", "AlertingInterceptor"])
func riskyOperation() throws -> Result {
    return try performRiskyWork()
}
```

##### Static Method Interception

```swift
class UtilityService {
    @Interceptor(before: ["LoggingInterceptor"])
    static func validateInput(data: String) -> Bool {
        return InputValidator.validate(data)
    }
}
```

#### 🛠️ **Creating Custom Interceptors**

All interceptors must conform to the `MethodInterceptor` protocol:

```swift
class CustomLoggingInterceptor: MethodInterceptor {
    func before(context: InterceptorContext) throws {
        print("🚀 [\(context.executionId.uuidString.prefix(8))] Starting \(context.methodName)")
        print("   Parameters: \(context.parameters)")
    }
    
    func after(context: InterceptorContext, result: Any?) throws {
        print("✅ [\(context.executionId.uuidString.prefix(8))] Completed in \(context.executionTime)ms")
        if let result = result {
            print("   Result: \(result)")
        }
    }
    
    func onError(context: InterceptorContext, error: Error) throws {
        print("❌ [\(context.executionId.uuidString.prefix(8))] Failed: \(error)")
        // Transform or re-throw error as needed
        throw error
    }
}
```

#### 🏭 **Built-in Interceptors**

SwinJectMacros provides several production-ready interceptors:

##### LoggingInterceptor
```swift
// Provides structured logging with execution IDs
InterceptorRegistry.register(interceptor: LoggingInterceptor(), name: "LoggingInterceptor")

// Output:
// 🚀 [A1B2C3D4] Entering PaymentService.processPayment
//    Parameters: ["amount": 100.0, "cardToken": "tok_..."]
// ✅ [A1B2C3D4] Completed PaymentService.processPayment in 45.23ms
//    Result: PaymentResult(id: "pay_123", status: "success")
```

##### PerformanceInterceptor
```swift
// Tracks execution times and identifies slow methods
InterceptorRegistry.register(interceptor: PerformanceInterceptor(), name: "PerformanceInterceptor")

// Get performance statistics
if let stats = PerformanceInterceptor.getStats(for: "PaymentService.processPayment") {
    print("Average: \(stats.avg)ms, Min: \(stats.min)ms, Max: \(stats.max)ms")
}

// Print comprehensive performance report
PerformanceInterceptor.printPerformanceReport()
```

#### 🔄 **Interceptor Registration**

Register your interceptors with the global registry:

```swift
// App startup - register all interceptors
InterceptorRegistry.registerDefaults()  // Registers built-in interceptors

// Register custom interceptors
InterceptorRegistry.register(
    interceptor: CustomSecurityInterceptor(), 
    name: "SecurityInterceptor"
)
InterceptorRegistry.register(
    interceptor: CustomCacheInterceptor(), 
    name: "CacheInterceptor"
)
```

#### 🎯 **Real-World Example: E-commerce Service**

```swift
class OrderService {
    @Interceptor(
        before: ["SecurityInterceptor", "ValidationInterceptor", "LoggingInterceptor"],
        after: ["InventoryInterceptor", "EmailInterceptor", "MetricsInterceptor"],
        onError: ["ErrorReportingInterceptor", "CompensationInterceptor"]
    )
    func createOrder(customerId: String, items: [OrderItem]) throws -> Order {
        // Pure business logic - all concerns handled by interceptors
        return try OrderProcessor.createOrder(customerId: customerId, items: items)
    }
    
    @Interceptor(before: ["CacheInterceptor"])
    func getOrderHistory(customerId: String) async -> [Order] {
        return await OrderRepository.findByCustomer(customerId)
    }
}
```

**Generated method calls:**
```swift
// The macro generates intercepted versions you can call explicitly
let order = orderService.createOrderIntercepted(customerId: "123", items: orderItems)

// Or use the original method - interceptors only run on the *Intercepted version
let order = orderService.createOrder(customerId: "123", items: orderItems)  // No interception
```

#### ⚡ **Performance Benefits**

- **Zero Overhead When Unused**: No interceptors = no performance impact
- **Compile-Time Validation**: Invalid interceptor references caught at build time
- **Minimal Runtime Cost**: Registry lookup + method calls only
- **Memory Efficient**: No reflection, no dynamic proxies
- **Thread Safe**: Built-in concurrent access to interceptor registry

## 🏗️ Complete Example: Real-World Application

Here's a complete example showing how all three macros work together in a real iOS application:

### Domain Layer

```swift
import SwinJectMacros

// MARK: - Core Services

@Injectable(scope: .container)
class NetworkClient: APIClient {
    init() {
        // Network configuration
    }
    
    func fetchUser(id: String) async throws -> UserData {
        // Network implementation
    }
}

@Injectable(scope: .container) 
class DatabaseManager: DatabaseService {
    init() {
        // Database setup
    }
    
    func save(_ user: UserData) async throws {
        // Database implementation  
    }
}

@Injectable
class LoggerService {
    init() {
        // Logger setup
    }
    
    func log(_ message: String) {
        print("📱 \(message)")
    }
}

// MARK: - Business Logic

@Injectable
class UserService {
    private let apiClient: APIClient
    private let database: DatabaseService
    private let logger: LoggerService
    
    init(apiClient: APIClient, database: DatabaseService, logger: LoggerService) {
        self.apiClient = apiClient
        self.database = database  
        self.logger = logger
    }
    
    func getUser(id: String) async throws -> User {
        logger.log("Fetching user: \(id)")
        let userData = try await apiClient.fetchUser(id: id)
        try await database.save(userData)
        return User(from: userData)
    }
}

// MARK: - Factory Services (Need Runtime Parameters)

@AutoFactory
class UserSearchService {
    private let apiClient: APIClient    // Injected
    private let database: DatabaseService // Injected 
    private let query: String           // Runtime parameter
    private let filters: [SearchFilter] // Runtime parameter
    
    init(apiClient: APIClient, database: DatabaseService, 
         query: String, filters: [SearchFilter]) {
        self.apiClient = apiClient
        self.database = database
        self.query = query
        self.filters = filters
    }
    
    func search() async throws -> [User] {
        // Search implementation
        return []
    }
}
```

### Application Setup

```swift
import Swinject
import SwinJectMacros

class AppAssembly: Assembly {
    func assemble(container: Container) {
        // All @Injectable services register themselves!
        NetworkClient.register(in: container)
        DatabaseManager.register(in: container)  
        LoggerService.register(in: container)
        UserService.register(in: container)
        
        // Register factories for services with runtime parameters
        container.registerFactory(UserSearchServiceFactory.self)
    }
}

@main
struct MyApp: App {
    let container = Container()
    
    init() {
        let assembler = Assembler([AppAssembly()], container: container)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container.resolve(UserService.self)!)
        }
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var userService: UserService
    @State private var searchQuery = ""
    @State private var users: [User] = []
    
    // Inject the factory for services with runtime parameters
    private let searchFactory: UserSearchServiceFactory
    
    init(searchFactory: UserSearchServiceFactory = Container.shared.resolve(UserSearchServiceFactory.self)!) {
        self.searchFactory = searchFactory
    }
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchQuery, onSearchButtonClicked: performSearch)
                
                List(users, id: \.id) { user in
                    UserRow(user: user)
                }
            }
            .navigationTitle("Users")
        }
    }
    
    private func performSearch() {
        Task {
            let searchService = searchFactory.makeUserSearchService(
                query: searchQuery,
                filters: [.active, .verified]
            )
            
            do {
                users = try await searchService.search()
            } catch {
                print("Search failed: \(error)")
            }
        }
    }
}
```

### Testing

```swift
import XCTest
@testable import MyApp

@TestContainer
class UserServiceTests: XCTestCase {
    var container: Container!
    
    // Service properties automatically detected
    var apiClient: APIClient!
    var database: DatabaseService!
    var logger: LoggerService!
    
    var userService: UserService!
    
    override func setUp() {
        super.setUp()
        
        // Generated method creates container with mocks
        container = setupTestContainer()
        
        // Resolve mocked dependencies
        apiClient = container.resolve(APIClient.self)!
        database = container.resolve(DatabaseService.self)!
        logger = container.resolve(LoggerService.self)!
        
        // Your service under test gets the mocks automatically
        UserService.register(in: container)
        userService = container.resolve(UserService.self)!
    }
    
    func testGetUser() async throws {
        // Setup mock behavior
        let mockAPI = apiClient as! MockAPIClient
        mockAPI.fetchUserResult = UserData(id: "123", name: "John Doe")
        
        // Test your service
        let user = try await userService.getUser(id: "123")
        
        // Verify behavior
        XCTAssertEqual(user.name, "John Doe")
        XCTAssertTrue(mockAPI.fetchUserCalled)
        
        let mockDB = database as! MockDatabaseService
        XCTAssertTrue(mockDB.saveCalled)
    }
}
```

## 🎯 Best Practices

### 1. **Service Design Guidelines**

```swift
// ✅ GOOD: Clear service boundaries
@Injectable
class UserAuthenticationService {
    private let apiClient: APIClient
    private let tokenStorage: TokenStorage
    
    init(apiClient: APIClient, tokenStorage: TokenStorage) {
        self.apiClient = apiClient
        self.tokenStorage = tokenStorage
    }
}

// ❌ AVOID: Too many dependencies (code smell)
@Injectable  
class GodService {
    // 15+ dependencies - consider breaking this down
    init(dep1: Dep1, dep2: Dep2, /* ... */, dep15: Dep15) { }
}
```

### 2. **Scope Selection**

```swift
// Use .container for expensive resources
@Injectable(scope: .container)
class DatabaseConnection { }

// Use .graph (default) for business logic
@Injectable  // scope: .graph is default
class UserService { }

// Use .singleton sparingly for app-wide state
@Injectable(scope: .singleton)
class AppConfiguration { }
```

### 3. **Factory vs Injectable Decision**

```swift
// ✅ Use @Injectable for pure services
@Injectable
class EmailService {
    init(smtpClient: SMTPClient) { }
}

// ✅ Use @AutoFactory for services needing runtime data
@AutoFactory
class EmailComposer {
    init(emailService: EmailService, recipient: String, subject: String) { }
}
```

### 4. **Testing Strategy**

```swift
// ✅ GOOD: Focused test setup
@TestContainer
class UserServiceTests: XCTestCase {
    var apiClient: APIClient!
    var database: DatabaseService!
    // Only dependencies you need
}

// ✅ GOOD: Custom mocks when needed
@TestContainer(autoMock: false)
class ComplexServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        container = setupTestContainer()
        
        // Use sophisticated mocks
        registerAPIClient(mock: RecordingMockAPIClient())
    }
}
```

## ⚠️ Common Pitfalls & Solutions

### 1. **Circular Dependencies**

```swift
// ❌ PROBLEM: Circular dependency
@Injectable
class ServiceA {
    init(serviceB: ServiceB) { }
}

@Injectable  
class ServiceB {
    init(serviceA: ServiceA) { }  // Circular!
}

// ✅ SOLUTION: Break the cycle with protocols or refactoring
protocol ServiceAProtocol { }

@Injectable
class ServiceA: ServiceAProtocol {
    init(serviceB: ServiceB) { }
}

@Injectable
class ServiceB {
    init(serviceA: ServiceAProtocol) { }  // Now uses protocol
}
```

### 2. **Runtime Parameters in @Injectable**

```swift
// ❌ PROBLEM: Runtime parameters in @Injectable
@Injectable  // ⚠️ Compiler warning
class ReportService {
    init(database: DatabaseService, reportType: String) { }
    //                                ^^^^^^^^^^^ Runtime parameter!
}

// ✅ SOLUTION: Use @AutoFactory instead
@AutoFactory
class ReportService {
    init(database: DatabaseService, reportType: String) { }
}
```

### 3. **Missing Protocol Registrations**

```swift
// ❌ PROBLEM: Concrete type but need protocol
@Injectable
class ConcreteAPIClient: APIClient {
    init() { }
}

// Later...
let client = container.resolve(APIClient.self)  // nil! Not registered

// ✅ SOLUTION: Register both concrete and protocol
class AppAssembly: Assembly {
    func assemble(container: Container) {
        ConcreteAPIClient.register(in: container)
        
        // Also register the protocol
        container.register(APIClient.self) { resolver in
            resolver.resolve(ConcreteAPIClient.self)!
        }
    }
}
```

## 🔮 Roadmap

SwinJectMacros is actively developed with 25+ macros planned. Here's what's coming:

### ✅ **Phase 1: Complete** (Current)
- `@Injectable` - Service registration
- `@AutoFactory` - Factory pattern generation  
- `@TestContainer` - Test mock setup

### 🚧 **Phase 2: AOP & Interceptors** (Next)
- `@Interceptor` - Method interception with before/after/onError hooks
- `@PerformanceTracked` - Automatic performance monitoring
- `@Retry` - Automatic retry logic with backoff strategies
- `@CircuitBreaker` - Circuit breaker pattern implementation

### 📋 **Phase 3: Advanced DI Patterns**
- `@LazyInject` - Lazy dependency resolution
- `@WeakInject` - Weak reference injection
- `@AsyncInject` - Async dependency initialization
- `@OptionalInject` - Optional dependency handling
- `@NamedInject` - Named dependency injection

### 🧪 **Phase 4: Testing & Validation**
- `@Spy` - Automatic spy generation
- `@MockResponse` - HTTP response mocking
- `@StubService` - Service stubbing utilities
- `@ValidatedContainer` - Container validation at compile-time

### ⚙️ **Phase 5: Configuration & Features**
- `@FeatureToggle` - Feature flag integration
- `@ConfigurableService` - Configuration-driven services
- `@ConditionalRegistration` - Conditional service registration
- `@EnvironmentService` - Environment-specific implementations

### 🔧 **Phase 6: SwiftUI & Combine**
- `@EnvironmentInject` - SwiftUI Environment integration
- `@ViewModelInject` - MVVM pattern support
- `@InjectedStateObject` - State management integration
- `@PublisherInject` - Combine publishers injection

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```bash
git clone https://github.com/YourUsername/SwinJectMacros.git
cd SwinJectMacros
swift build
swift test
```

## 📄 License

SwinJectMacros is released under the MIT License. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Built on top of the excellent [Swinject](https://github.com/Swinject/Swinject) framework
- Powered by Swift Macros introduced in Swift 5.9
- Inspired by dependency injection frameworks from other ecosystems

---

**Ready to eliminate dependency injection boilerplate?** Get started with SwinJectMacros today! 🚀