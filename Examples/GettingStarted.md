# Getting Started with SwinJectMacros

This guide provides step-by-step examples to help you understand and use SwinJectMacros effectively.

## 📚 Table of Contents

1. [Your First Injectable Service](#1-your-first-injectable-service)
2. [Building a Service Layer](#2-building-a-service-layer) 
3. [Working with Factories](#3-working-with-factories)
4. [Setting Up Tests](#4-setting-up-tests)
5. [Adding Cross-Cutting Concerns with Interceptors](#5-adding-cross-cutting-concerns-with-interceptors)
6. [Real-World iOS Example](#6-real-world-ios-example)

## 1. Your First Injectable Service

Let's start with the simplest possible example and build from there.

### Step 1: Basic Service Without Dependencies

```swift
import SwinJectMacros
import Swinject

// This is a simple service with no dependencies
@Injectable
class GreetingService {
    init() {
        print("GreetingService initialized!")
    }
    
    func greet(name: String) -> String {
        return "Hello, \(name)! 👋"
    }
}
```

**What happens:** The `@Injectable` macro generates:
- A static `register(in:)` method
- `Injectable` protocol conformance
- Proper container registration code

### Step 2: Using Your Service

```swift
import Swinject

// Set up your container
let container = Container()

// Register your service (this is the generated method)
GreetingService.register(in: container)

// Use your service
let greetingService = container.resolve(GreetingService.self)!
print(greetingService.greet(name: "World")) // "Hello, World! 👋"
```

### Step 3: Adding Dependencies

Now let's add some dependencies to make it more realistic:

```swift
// A simple logger service
@Injectable
class LoggerService {
    init() {}
    
    func log(_ message: String) {
        print("📝 LOG: \(message)")
    }
}

// An enhanced greeting service with dependencies
@Injectable  
class EnhancedGreetingService {
    private let logger: LoggerService
    
    init(logger: LoggerService) {
        self.logger = logger
        logger.log("EnhancedGreetingService initialized")
    }
    
    func greet(name: String) -> String {
        logger.log("Greeting user: \(name)")
        return "Hello, \(name)! 🌟"
    }
}
```

### Step 4: Registering Multiple Services

```swift
let container = Container()

// Register both services
LoggerService.register(in: container)
EnhancedGreetingService.register(in: container)

// The enhanced service automatically gets the logger injected!
let service = container.resolve(EnhancedGreetingService.self)!
print(service.greet(name: "Alice"))

// Output:
// 📝 LOG: EnhancedGreetingService initialized  
// 📝 LOG: Greeting user: Alice
// Hello, Alice! 🌟
```

**Key Learning:** The macro automatically detected that `LoggerService` is a dependency and generated the correct resolver code!

## 2. Building a Service Layer

Let's build a more realistic example with multiple layers of services.

### Step 1: Define Your Protocols

```swift
import Swinject
import SwinJectMacros

// Domain protocols (contracts)
protocol UserRepository {
    func fetchUser(id: String) async throws -> User
    func saveUser(_ user: User) async throws
}

protocol NotificationService {
    func sendWelcomeNotification(to user: User) async throws
}

protocol APIClient {
    func get<T: Codable>(path: String, type: T.Type) async throws -> T
    func post<T: Codable>(path: String, body: T) async throws
}
```

### Step 2: Implement Infrastructure Services

```swift
// Concrete implementations with @Injectable

@Injectable(scope: .container) // Singleton - expensive to create
class HTTPAPIClient: APIClient {
    private let baseURL: URL
    
    init() {
        self.baseURL = URL(string: "https://api.example.com")!
        print("🌍 HTTPAPIClient initialized")
    }
    
    func get<T: Codable>(path: String, type: T.Type) async throws -> T {
        // Real HTTP implementation would go here
        print("🌍 GET \(baseURL)/\(path)")
        // Mock response for example
        throw APIError.notImplemented
    }
    
    func post<T: Codable>(path: String, body: T) async throws {
        print("🌍 POST \(baseURL)/\(path)")
        // Mock implementation
    }
}

@Injectable(scope: .container) // Expensive database connections
class CoreDataUserRepository: UserRepository {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
        print("💾 CoreDataUserRepository initialized")
    }
    
    func fetchUser(id: String) async throws -> User {
        print("💾 Fetching user \(id) from database")
        return try await apiClient.get(path: "users/\(id)", type: User.self)
    }
    
    func saveUser(_ user: User) async throws {
        print("💾 Saving user \(user.id) to database")
        try await apiClient.post(path: "users/\(user.id)", body: user)
    }
}

@Injectable
class PushNotificationService: NotificationService {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
        print("📱 PushNotificationService initialized")
    }
    
    func sendWelcomeNotification(to user: User) async throws {
        print("📱 Sending welcome notification to \(user.name)")
        let notification = WelcomeNotification(userId: user.id, message: "Welcome \(user.name)!")
        try await apiClient.post(path: "notifications", body: notification)
    }
}
```

### Step 3: Build Your Business Logic Layer

```swift
@Injectable
class UserService {
    private let userRepository: UserRepository
    private let notificationService: NotificationService
    private let logger: LoggerService
    
    init(userRepository: UserRepository, 
         notificationService: NotificationService, 
         logger: LoggerService) {
        self.userRepository = userRepository
        self.notificationService = notificationService
        self.logger = logger
        logger.log("UserService initialized with dependencies")
    }
    
    func createUser(name: String, email: String) async throws -> User {
        logger.log("Creating user: \(name)")
        
        let user = User(id: UUID().uuidString, name: name, email: email)
        
        try await userRepository.saveUser(user)
        logger.log("User saved to repository")
        
        try await notificationService.sendWelcomeNotification(to: user)
        logger.log("Welcome notification sent")
        
        return user
    }
    
    func getUser(id: String) async throws -> User {
        logger.log("Fetching user: \(id)")
        return try await userRepository.fetchUser(id: id)
    }
}
```

### Step 4: Assembly and Registration

```swift
class AppAssembly: Assembly {
    func assemble(container: Container) {
        // Infrastructure layer
        LoggerService.register(in: container)
        HTTPAPIClient.register(in: container)
        
        // Register concrete implementations for protocols
        CoreDataUserRepository.register(in: container)
        container.register(UserRepository.self) { resolver in
            resolver.resolve(CoreDataUserRepository.self)!
        }
        
        PushNotificationService.register(in: container)
        container.register(NotificationService.self) { resolver in
            resolver.resolve(PushNotificationService.self)!
        }
        
        container.register(APIClient.self) { resolver in
            resolver.resolve(HTTPAPIClient.self)!
        }
        
        // Business logic layer
        UserService.register(in: container)
    }
}

// Usage
let container = Container()
let assembler = Assembler([AppAssembly()], container: container)

let userService = container.resolve(UserService.self)!

Task {
    do {
        let user = try await userService.createUser(name: "John Doe", email: "john@example.com")
        print("Created user: \(user)")
    } catch {
        print("Error: \(error)")
    }
}
```

**Output:**
```
📝 LOG: LoggerService initialized
🌍 HTTPAPIClient initialized  
💾 CoreDataUserRepository initialized
📱 PushNotificationService initialized
📝 LOG: UserService initialized with dependencies
📝 LOG: Creating user: John Doe
💾 Saving user [uuid] to database
🌍 POST https://api.example.com/users/[uuid]
📝 LOG: User saved to repository
📱 Sending welcome notification to John Doe
🌍 POST https://api.example.com/notifications
📝 LOG: Welcome notification sent
```

**Key Learning:** Notice how:
- Services are created in the right order (dependencies first)
- Scoped services (`.container`) are created once and reused
- The dependency graph is resolved automatically

## 3. Working with Factories

Factories are perfect when your services need runtime parameters that can't be pre-registered.

### Step 1: Identify the Need for a Factory

```swift
// ❌ This WON'T work with @Injectable because of runtime parameters
class SearchService {
    private let apiClient: APIClient      // Injected dependency
    private let userRepository: UserRepository // Injected dependency  
    private let query: String            // Runtime parameter!
    private let filters: [SearchFilter]  // Runtime parameter!
    
    init(apiClient: APIClient, userRepository: UserRepository,
         query: String, filters: [SearchFilter]) {
        // Can't pre-register this - query and filters come from user input!
    }
}
```

### Step 2: Use @AutoFactory

```swift
@AutoFactory
class SearchService {
    private let apiClient: APIClient      // ✅ Will be injected
    private let userRepository: UserRepository // ✅ Will be injected
    private let query: String            // ✅ Runtime parameter
    private let filters: [SearchFilter]  // ✅ Runtime parameter
    
    init(apiClient: APIClient, userRepository: UserRepository,
         query: String, filters: [SearchFilter]) {
        self.apiClient = apiClient
        self.userRepository = userRepository
        self.query = query
        self.filters = filters
        print("🔍 SearchService created for query: '\(query)'")
    }
    
    func search() async throws -> [User] {
        print("🔍 Searching with \(filters.count) filters")
        
        // Use injected dependencies for data access
        let results = try await apiClient.get(
            path: "search?q=\(query)&filters=\(filters)", 
            type: [User].self
        )
        
        // Maybe cache results in repository
        for user in results {
            try await userRepository.saveUser(user)
        }
        
        return results
    }
}

// The macro generates:
// protocol SearchServiceFactory {
//     func makeSearchService(query: String, filters: [SearchFilter]) -> SearchService
// }
//
// class SearchServiceFactoryImpl: SearchServiceFactory, BaseFactory { ... }
```

### Step 3: Register and Use the Factory

```swift
class SearchAssembly: Assembly {
    func assemble(container: Container) {
        // Register dependencies first
        HTTPAPIClient.register(in: container)
        CoreDataUserRepository.register(in: container)
        
        // Register protocol bindings
        container.register(APIClient.self) { resolver in
            resolver.resolve(HTTPAPIClient.self)!
        }
        container.register(UserRepository.self) { resolver in
            resolver.resolve(CoreDataUserRepository.self)!
        }
        
        // Register the factory
        container.registerFactory(SearchServiceFactory.self)
    }
}

// Usage in your view controller or SwiftUI view
class SearchViewController: UIViewController {
    private let searchFactory: SearchServiceFactory
    private var currentSearchService: SearchService?
    
    init(searchFactory: SearchServiceFactory) {
        self.searchFactory = searchFactory
        super.init(nibName: nil, bundle: nil)
    }
    
    @IBAction func searchButtonTapped() {
        let query = searchTextField.text ?? ""
        let filters = selectedFilters // from UI
        
        // Create a new search service with current parameters
        currentSearchService = searchFactory.makeSearchService(
            query: query,
            filters: filters
        )
        
        Task {
            do {
                let results = try await currentSearchService!.search()
                await MainActor.run {
                    displayResults(results)
                }
            } catch {
                await MainActor.run {
                    showError(error)
                }
            }
        }
    }
}
```

### Step 4: Advanced Factory Example - File Processing

```swift
// More complex factory with async initialization
@AutoFactory(async: true, throws: true)
class FileProcessor {
    private let fileService: FileService      // Injected
    private let validationService: ValidationService // Injected
    private let filePath: URL               // Runtime parameter
    private let processingOptions: ProcessingOptions // Runtime parameter
    
    init(fileService: FileService, 
         validationService: ValidationService,
         filePath: URL, 
         processingOptions: ProcessingOptions) async throws {
        self.fileService = fileService
        self.validationService = validationService
        self.filePath = filePath
        self.processingOptions = processingOptions
        
        // Async validation during initialization
        let isValid = try await validationService.validateFile(at: filePath)
        guard isValid else {
            throw FileProcessorError.invalidFile
        }
        
        print("📁 FileProcessor ready for: \(filePath.lastPathComponent)")
    }
    
    func process() async throws -> ProcessingResult {
        print("📁 Processing \(filePath.lastPathComponent) with options: \(processingOptions)")
        
        let data = try await fileService.loadFile(at: filePath)
        let result = try await fileService.processData(data, options: processingOptions)
        
        return result
    }
}

// Generated factory method signature:
// func makeFileProcessor(filePath: URL, processingOptions: ProcessingOptions) async throws -> FileProcessor

// Usage:
let processor = try await fileProcessorFactory.makeFileProcessor(
    filePath: fileURL,
    processingOptions: ProcessingOptions(format: .pdf, quality: .high)
)

let result = try await processor.process()
```

**Key Learning:** Factories are perfect for:
- Services that need user input or request data
- Services with expensive or async initialization
- Services that need to be created multiple times with different parameters

## 4. Setting Up Tests

Testing with dependency injection becomes much easier with `@TestContainer`.

### Step 1: Basic Test Setup

```swift
import XCTest
@testable import MyApp

@TestContainer
class UserServiceTests: XCTestCase {
    var container: Container!
    
    // Properties that need mocking - automatically detected by the macro
    var userRepository: UserRepository!
    var notificationService: NotificationService!
    var logger: LoggerService!
    
    var userService: UserService! // Service under test
    
    override func setUp() {
        super.setUp()
        
        // This method is generated by @TestContainer
        container = setupTestContainer()
        
        // Resolve your mocked dependencies
        userRepository = container.resolve(UserRepository.self)!
        notificationService = container.resolve(NotificationService.self)!
        logger = container.resolve(LoggerService.self)!
        
        // Register and resolve your service under test
        UserService.register(in: container)
        userService = container.resolve(UserService.self)!
    }
    
    func testCreateUser() async throws {
        // Arrange: Set up mock behavior
        let mockUserRepo = userRepository as! MockUserRepository
        mockUserRepo.saveUserResult = .success(())
        
        let mockNotifications = notificationService as! MockNotificationService  
        mockNotifications.sendWelcomeNotificationResult = .success(())
        
        // Act: Call the method under test
        let user = try await userService.createUser(name: "Test User", email: "test@example.com")
        
        // Assert: Verify the behavior
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.email, "test@example.com")
        
        XCTAssertTrue(mockUserRepo.saveUserCalled)
        XCTAssertEqual(mockUserRepo.savedUser?.name, "Test User")
        
        XCTAssertTrue(mockNotifications.sendWelcomeNotificationCalled)
        XCTAssertEqual(mockNotifications.welcomeNotificationUser?.name, "Test User")
    }
}
```

### Step 2: Custom Mock Implementations

```swift
// You can provide your own sophisticated mocks
class MockUserRepository: UserRepository {
    var fetchUserResult: Result<User, Error> = .failure(MockError.notSet)
    var saveUserResult: Result<Void, Error> = .failure(MockError.notSet)
    
    var fetchUserCalled = false
    var saveUserCalled = false
    var savedUser: User?
    var fetchedUserId: String?
    
    func fetchUser(id: String) async throws -> User {
        fetchUserCalled = true
        fetchedUserId = id
        return try fetchUserResult.get()
    }
    
    func saveUser(_ user: User) async throws {
        saveUserCalled = true
        savedUser = user
        try saveUserResult.get()
    }
}

class MockNotificationService: NotificationService {
    var sendWelcomeNotificationResult: Result<Void, Error> = .failure(MockError.notSet)
    
    var sendWelcomeNotificationCalled = false
    var welcomeNotificationUser: User?
    
    func sendWelcomeNotification(to user: User) async throws {
        sendWelcomeNotificationCalled = true
        welcomeNotificationUser = user
        try sendWelcomeNotificationResult.get()
    }
}

class MockLoggerService: LoggerService {
    var loggedMessages: [String] = []
    
    override func log(_ message: String) {
        loggedMessages.append(message)
        super.log(message) // Still print if you want to see output
    }
}
```

### Step 3: Testing Error Scenarios

```swift
func testCreateUserWithRepositoryError() async {
    // Arrange: Make the repository fail
    let mockUserRepo = userRepository as! MockUserRepository
    mockUserRepo.saveUserResult = .failure(RepositoryError.connectionFailed)
    
    // Act & Assert: Verify the error propagates
    do {
        _ = try await userService.createUser(name: "Test User", email: "test@example.com")
        XCTFail("Expected error to be thrown")
    } catch {
        XCTAssertTrue(error is RepositoryError)
        
        // Verify that notification was NOT sent after repository failure
        let mockNotifications = notificationService as! MockNotificationService
        XCTAssertFalse(mockNotifications.sendWelcomeNotificationCalled)
    }
}

func testCreateUserWithNotificationError() async {
    // Arrange: Repository succeeds, but notification fails
    let mockUserRepo = userRepository as! MockUserRepository
    mockUserRepo.saveUserResult = .success(())
    
    let mockNotifications = notificationService as! MockNotificationService
    mockNotifications.sendWelcomeNotificationResult = .failure(NotificationError.serviceUnavailable)
    
    // Act & Assert
    do {
        _ = try await userService.createUser(name: "Test User", email: "test@example.com")
        XCTFail("Expected error to be thrown")
    } catch {
        XCTAssertTrue(error is NotificationError)
        
        // Verify that user was still saved even though notification failed
        XCTAssertTrue(mockUserRepo.saveUserCalled)
        XCTAssertEqual(mockUserRepo.savedUser?.name, "Test User")
    }
}
```

### Step 4: Testing Factories

```swift
@TestContainer
class SearchServiceTests: XCTestCase {
    var container: Container!
    var apiClient: APIClient!
    var userRepository: UserRepository!
    
    var searchFactory: SearchServiceFactory!
    
    override func setUp() {
        super.setUp()
        container = setupTestContainer()
        
        apiClient = container.resolve(APIClient.self)!
        userRepository = container.resolve(UserRepository.self)!
        
        // Register and resolve the factory
        container.registerFactory(SearchServiceFactory.self)
        searchFactory = container.resolve(SearchServiceFactory.self)!
    }
    
    func testSearchWithResults() async throws {
        // Arrange: Mock API to return results
        let mockAPI = apiClient as! MockAPIClient
        let expectedUsers = [
            User(id: "1", name: "Alice", email: "alice@example.com"),
            User(id: "2", name: "Bob", email: "bob@example.com")
        ]
        mockAPI.getResult = .success(expectedUsers)
        
        // Act: Create search service with runtime parameters
        let searchService = searchFactory.makeSearchService(
            query: "test query",
            filters: [.active, .verified]
        )
        
        let results = try await searchService.search()
        
        // Assert
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].name, "Alice")
        XCTAssertEqual(results[1].name, "Bob")
        
        // Verify API was called with correct parameters
        XCTAssertTrue(mockAPI.getCalled)
        XCTAssertTrue(mockAPI.lastPath?.contains("test query") == true)
    }
}
```

**Key Learning:** 
- `@TestContainer` eliminates test setup boilerplate
- You can still provide custom mocks when needed
- Testing both success and error scenarios is straightforward
- Factory testing works the same way as regular service testing

## 5. Adding Cross-Cutting Concerns with Interceptors

Now let's learn how to add cross-cutting concerns like logging, performance monitoring, and validation to our services without cluttering the business logic.

### Step 1: Understanding the Problem

Imagine you want to add logging, security validation, and performance monitoring to your user service:

```swift
// ❌ Traditional approach - business logic gets buried in boilerplate
@Injectable
class UserService {
    private let repository: UserRepository
    private let logger: LoggerService
    private let securityValidator: SecurityValidator
    private let performanceMonitor: PerformanceMonitor
    
    init(repository: UserRepository, logger: LoggerService, 
         securityValidator: SecurityValidator, performanceMonitor: PerformanceMonitor) {
        self.repository = repository
        self.logger = logger
        self.securityValidator = securityValidator
        self.performanceMonitor = performanceMonitor
    }
    
    func createUser(name: String, email: String) async throws -> User {
        // Logging
        logger.log("Creating user: \(name), \(email)")
        let startTime = Date()
        
        // Security validation
        try securityValidator.validateUserData(name: name, email: email)
        
        // Business logic (buried in boilerplate!)
        let user = User(name: name, email: email)
        let savedUser = try await repository.save(user)
        
        // More logging
        let duration = Date().timeIntervalSince(startTime)
        logger.log("User created in \(duration)ms: \(savedUser.id)")
        performanceMonitor.record("createUser", duration: duration)
        
        return savedUser
    }
}
```

### Step 2: Clean Solution with @Interceptor

```swift
// ✅ With @Interceptor - clean business logic with cross-cutting concerns handled automatically
@Injectable
class UserService {
    private let repository: UserRepository
    
    init(repository: UserRepository) {
        self.repository = repository
    }
    
    @Interceptor(
        before: ["SecurityInterceptor", "LoggingInterceptor"],
        after: ["PerformanceInterceptor", "AuditInterceptor"]
    )
    func createUser(name: String, email: String) async throws -> User {
        // Pure business logic - no clutter!
        let user = User(name: name, email: email)
        return try await repository.save(user)
    }
}
```

### Step 3: Creating Your First Interceptor

Let's create a simple logging interceptor:

```swift
import SwinJectMacros

class LoggingInterceptor: MethodInterceptor {
    func before(context: InterceptorContext) throws {
        print("🚀 Starting \(context.methodName)")
        print("   Parameters: \(context.parameters)")
    }
    
    func after(context: InterceptorContext, result: Any?) throws {
        print("✅ Completed \(context.methodName) in \(String(format: "%.2f", context.executionTime))ms")
        if let result = result {
            print("   Result: \(result)")
        }
    }
    
    func onError(context: InterceptorContext, error: Error) throws {
        print("❌ Failed \(context.methodName): \(error)")
        throw error // Re-throw the error
    }
}
```

### Step 4: Security Validation Interceptor

```swift
class SecurityInterceptor: MethodInterceptor {
    func before(context: InterceptorContext) throws {
        // Validate parameters before method execution
        for (paramName, value) in context.parameters {
            if let stringValue = value as? String {
                // Check for suspicious patterns
                if stringValue.contains("<script>") || stringValue.contains("DROP TABLE") {
                    throw SecurityError.suspiciousInput(paramName)
                }
                
                // Email validation for email parameters
                if paramName.lowercased().contains("email") {
                    guard stringValue.contains("@") && stringValue.contains(".") else {
                        throw ValidationError.invalidEmail(stringValue)
                    }
                }
            }
        }
        
        print("🔒 Security validation passed for \(context.methodName)")
    }
    
    func after(context: InterceptorContext, result: Any?) throws {
        // Could log successful operations for audit trail
        print("🔒 \(context.methodName) completed securely")
    }
    
    func onError(context: InterceptorContext, error: Error) throws {
        // Log security failures
        print("🚨 Security interceptor caught error in \(context.methodName): \(error)")
        throw error
    }
}
```

### Step 5: Performance Monitoring Interceptor

```swift
class PerformanceInterceptor: MethodInterceptor {
    private static var metrics: [String: [Double]] = [:]
    private static let queue = DispatchQueue(label: "performance.metrics")
    
    func before(context: InterceptorContext) throws {
        // Setup happens automatically - startTime is in context
    }
    
    func after(context: InterceptorContext, result: Any?) throws {
        let methodKey = "\(context.typeName).\(context.methodName)"
        let executionTime = context.executionTime
        
        Self.queue.async {
            Self.metrics[methodKey, default: []].append(executionTime)
            
            // Keep only last 100 measurements
            if Self.metrics[methodKey]!.count > 100 {
                Self.metrics[methodKey]!.removeFirst()
            }
        }
        
        // Alert on slow methods
        if executionTime > 1000 { // 1 second
            print("⚠️ SLOW METHOD: \(methodKey) took \(String(format: "%.2f", executionTime))ms")
        }
    }
    
    func onError(context: InterceptorContext, error: Error) throws {
        print("📊 \(context.methodName) failed after \(String(format: "%.2f", context.executionTime))ms")
        throw error
    }
    
    // Utility method to get performance stats
    static func getStats(for method: String) -> (avg: Double, min: Double, max: Double)? {
        return queue.sync {
            guard let times = metrics[method], !times.isEmpty else { return nil }
            return (
                avg: times.reduce(0, +) / Double(times.count),
                min: times.min() ?? 0,
                max: times.max() ?? 0
            )
        }
    }
}
```

### Step 6: Registering Your Interceptors

```swift
// In your app startup (AppDelegate, SceneDelegate, or App.swift)
import SwinJectMacros

func setupInterceptors() {
    // Register all your custom interceptors
    InterceptorRegistry.register(interceptor: LoggingInterceptor(), name: "LoggingInterceptor")
    InterceptorRegistry.register(interceptor: SecurityInterceptor(), name: "SecurityInterceptor")
    InterceptorRegistry.register(interceptor: PerformanceInterceptor(), name: "PerformanceInterceptor")
    
    // You can also register the built-in interceptors
    InterceptorRegistry.registerDefaults()
}
```

### Step 7: Using the Intercepted Methods

```swift
// The @Interceptor macro generates "Intercepted" versions of your methods
let userService = container.resolve(UserService.self)!

// This calls the intercepted version with all the interceptors
let user = try await userService.createUserIntercepted(name: "John Doe", email: "john@example.com")

// This calls the original method without interceptors
let user2 = try await userService.createUser(name: "Jane Doe", email: "jane@example.com")
```

### Step 8: Testing with Interceptors

```swift
@TestContainer
class UserServiceInterceptorTests: XCTestCase {
    var container: Container!
    var userService: UserService!
    var mockRepository: UserRepository!
    
    override func setUp() {
        super.setUp()
        container = setupTestContainer()
        
        // Register test-specific interceptors
        InterceptorRegistry.register(interceptor: TestLoggingInterceptor(), name: "LoggingInterceptor")
        InterceptorRegistry.register(interceptor: TestSecurityInterceptor(), name: "SecurityInterceptor")
        
        UserService.register(in: container)
        userService = container.resolve(UserService.self)!
        mockRepository = container.resolve(UserRepository.self)! as? MockUserRepository
    }
    
    func testCreateUserWithInterceptors() async throws {
        // Arrange
        let mockRepo = mockRepository as! MockUserRepository
        mockRepo.saveResult = .success(User(name: "Test", email: "test@example.com"))
        
        // Act - Use the intercepted version
        let user = try await userService.createUserIntercepted(name: "Test User", email: "test@example.com")
        
        // Assert
        XCTAssertEqual(user.name, "Test User")
        XCTAssertTrue(mockRepo.saveCalled)
        
        // Verify interceptors were called
        let testLogger = InterceptorRegistry.get(name: "LoggingInterceptor") as! TestLoggingInterceptor
        XCTAssertTrue(testLogger.beforeCalled)
        XCTAssertTrue(testLogger.afterCalled)
    }
    
    func testSecurityValidationFails() async {
        // Act & Assert - Should throw security error
        do {
            _ = try await userService.createUserIntercepted(name: "Test", email: "malicious<script>")
            XCTFail("Should have thrown security error")
        } catch SecurityError.suspiciousInput {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
```

### 📊 What You've Learned

1. **Separation of Concerns**: Business logic stays clean while cross-cutting concerns are handled separately
2. **Reusable Interceptors**: Create once, use across all your services
3. **Rich Context**: Interceptors have access to method names, parameters, execution time, and more
4. **Error Handling**: Interceptors can catch, transform, or log errors
5. **Performance Monitoring**: Built-in execution timing and custom metrics collection
6. **Testing**: Easy to test both business logic and interceptor behavior separately

### 🎯 Common Interceptor Patterns

```swift
// Caching Interceptor
class CacheInterceptor: MethodInterceptor {
    private var cache: [String: Any] = [:]
    
    func before(context: InterceptorContext) throws {
        let cacheKey = "\(context.methodName)_\(context.parameters.description)"
        if let cachedResult = cache[cacheKey] {
            // Could skip method execution entirely (advanced feature)
            context.metadata["cachedResult"] = cachedResult
        }
    }
}

// Rate Limiting Interceptor
class RateLimitInterceptor: MethodInterceptor {
    private var lastCall: [String: Date] = [:]
    private let minimumInterval: TimeInterval = 1.0 // 1 second
    
    func before(context: InterceptorContext) throws {
        let methodKey = "\(context.typeName).\(context.methodName)"
        if let lastTime = lastCall[methodKey] {
            let timeSinceLastCall = Date().timeIntervalSince(lastTime)
            if timeSinceLastCall < minimumInterval {
                throw RateLimitError.tooManyRequests(methodKey)
            }
        }
        lastCall[methodKey] = Date()
    }
}

// Retry Interceptor (error handling)
class RetryInterceptor: MethodInterceptor {
    func onError(context: InterceptorContext, error: Error) throws {
        if let networkError = error as? NetworkError, networkError.isRetryable {
            // Could implement retry logic here
            print("🔄 Could retry \(context.methodName) due to: \(error)")
        }
        throw error
    }
}
```

The `@Interceptor` macro gives you enterprise-level AOP capabilities with the simplicity and performance of compile-time code generation!

## 6. Real-World iOS Example

Let's build a complete iOS app example that demonstrates all the macros working together.

### Step 1: Define Your App's Architecture

```swift
// MARK: - Models
struct Article {
    let id: String
    let title: String
    let content: String
    let authorId: String
    let publishedAt: Date
}

struct Author {
    let id: String
    let name: String
    let email: String
    let bio: String
}

// MARK: - Core Services

@Injectable(scope: .container)
class NetworkService: APIClient {
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        print("🌐 NetworkService initialized")
    }
    
    func get<T: Codable>(path: String, type: T.Type) async throws -> T {
        guard let url = URL(string: "https://api.myblog.com/\(path)") else {
            throw NetworkError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
}

@Injectable(scope: .container)
class CacheService {
    private var cache: [String: Any] = [:]
    
    init() {
        print("💾 CacheService initialized")
    }
    
    func get<T>(_ key: String, type: T.Type) -> T? {
        return cache[key] as? T
    }
    
    func set<T>(_ key: String, value: T) {
        cache[key] = value
    }
}

@Injectable
class ArticleRepository {
    private let networkService: APIClient
    private let cacheService: CacheService
    
    init(networkService: APIClient, cacheService: CacheService) {
        self.networkService = networkService
        self.cacheService = cacheService
        print("📰 ArticleRepository initialized")
    }
    
    func getArticles() async throws -> [Article] {
        // Check cache first
        if let cached = cacheService.get("articles", type: [Article].self) {
            print("📰 Returning cached articles")
            return cached
        }
        
        // Fetch from network
        print("📰 Fetching articles from network")
        let articles = try await networkService.get(path: "articles", type: [Article].self)
        
        // Cache the results
        cacheService.set("articles", value: articles)
        
        return articles
    }
    
    func getArticle(id: String) async throws -> Article {
        let cacheKey = "article_\(id)"
        
        if let cached = cacheService.get(cacheKey, type: Article.self) {
            return cached
        }
        
        let article = try await networkService.get(path: "articles/\(id)", type: Article.self)
        cacheService.set(cacheKey, value: article)
        
        return article
    }
}

@Injectable
class AuthorRepository {
    private let networkService: APIClient
    private let cacheService: CacheService
    
    init(networkService: APIClient, cacheService: CacheService) {
        self.networkService = networkService
        self.cacheService = cacheService
    }
    
    func getAuthor(id: String) async throws -> Author {
        let cacheKey = "author_\(id)"
        
        if let cached = cacheService.get(cacheKey, type: Author.self) {
            return cached
        }
        
        let author = try await networkService.get(path: "authors/\(id)", type: Author.self)
        cacheService.set(cacheKey, value: author)
        
        return author
    }
}
```

### Step 2: Business Logic with Factories

```swift
// MARK: - Services that need runtime parameters

@AutoFactory
class ArticleDetailService {
    private let articleRepository: ArticleRepository // Injected
    private let authorRepository: AuthorRepository   // Injected
    private let articleId: String                   // Runtime parameter
    
    init(articleRepository: ArticleRepository, 
         authorRepository: AuthorRepository,
         articleId: String) {
        self.articleRepository = articleRepository
        self.authorRepository = authorRepository
        self.articleId = articleId
        print("📖 ArticleDetailService created for article: \(articleId)")
    }
    
    func loadArticleWithAuthor() async throws -> (Article, Author) {
        async let article = articleRepository.getArticle(id: articleId)
        async let author = try await authorRepository.getAuthor(id: article.authorId)
        
        return try await (article, author)
    }
}

@AutoFactory
class ArticleSearchService {
    private let articleRepository: ArticleRepository // Injected
    private let query: String                       // Runtime parameter
    private let filters: [SearchFilter]            // Runtime parameter
    
    init(articleRepository: ArticleRepository, query: String, filters: [SearchFilter]) {
        self.articleRepository = articleRepository
        self.query = query
        self.filters = filters
    }
    
    func search() async throws -> [Article] {
        let allArticles = try await articleRepository.getArticles()
        
        return allArticles.filter { article in
            let matchesQuery = query.isEmpty || 
                              article.title.localizedCaseInsensitiveContains(query) ||
                              article.content.localizedCaseInsensitiveContains(query)
            
            let matchesFilters = filters.allSatisfy { filter in
                switch filter {
                case .publishedToday:
                    return Calendar.current.isDateInToday(article.publishedAt)
                case .longForm:
                    return article.content.count > 1000
                }
            }
            
            return matchesQuery && matchesFilters
        }
    }
}
```

### Step 3: SwiftUI Views with Dependency Injection

```swift
import SwiftUI

// MARK: - SwiftUI App Setup

@main
struct BlogApp: App {
    let container = Container()
    
    init() {
        setupDependencies()
    }
    
    private func setupDependencies() {
        let assembler = Assembler([BlogAssembly()], container: container)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container.resolve(ArticleRepository.self)!)
                .environmentObject(container.resolve(ArticleDetailServiceFactory.self)!)
                .environmentObject(container.resolve(ArticleSearchServiceFactory.self)!)
        }
    }
}

class BlogAssembly: Assembly {
    func assemble(container: Container) {
        // Infrastructure
        NetworkService.register(in: container)
        CacheService.register(in: container)
        
        // Repositories
        ArticleRepository.register(in: container)
        AuthorRepository.register(in: container)
        
        // Protocol bindings
        container.register(APIClient.self) { resolver in
            resolver.resolve(NetworkService.self)!
        }
        
        // Factories
        container.registerFactory(ArticleDetailServiceFactory.self)
        container.registerFactory(ArticleSearchServiceFactory.self)
    }
}

// MARK: - SwiftUI Views

struct ContentView: View {
    @EnvironmentObject var articleRepository: ArticleRepository
    @State private var articles: [Article] = []
    @State private var isLoading = false
    @State private var showingSearch = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading articles...")
                } else {
                    List(articles, id: \.id) { article in
                        NavigationLink(destination: ArticleDetailView(articleId: article.id)) {
                            ArticleRowView(article: article)
                        }
                    }
                }
            }
            .navigationTitle("My Blog")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Search") {
                        showingSearch = true
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                ArticleSearchView()
            }
            .task {
                await loadArticles()
            }
        }
    }
    
    private func loadArticles() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            articles = try await articleRepository.getArticles()
        } catch {
            print("Failed to load articles: \(error)")
            // Handle error (show alert, etc.)
        }
    }
}

struct ArticleDetailView: View {
    let articleId: String
    
    @EnvironmentObject var detailServiceFactory: ArticleDetailServiceFactory
    @State private var article: Article?
    @State private var author: Author?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading article...")
            } else if let article = article, let author = author {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(article.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("By \(author.name)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(article.publishedAt, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        Text(article.content)
                            .font(.body)
                        
                        Spacer()
                    }
                    .padding()
                }
            } else {
                Text("Failed to load article")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArticleDetail()
        }
    }
    
    private func loadArticleDetail() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Create a service instance for this specific article
            let detailService = detailServiceFactory.makeArticleDetailService(articleId: articleId)
            let (loadedArticle, loadedAuthor) = try await detailService.loadArticleWithAuthor()
            
            article = loadedArticle
            author = loadedAuthor
        } catch {
            print("Failed to load article detail: \(error)")
        }
    }
}

struct ArticleSearchView: View {
    @EnvironmentObject var searchServiceFactory: ArticleSearchServiceFactory
    @State private var searchQuery = ""
    @State private var selectedFilters: [SearchFilter] = []
    @State private var searchResults: [Article] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchQuery, onSearchButtonClicked: performSearch)
                
                FilterPickerView(selectedFilters: $selectedFilters)
                
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults, id: \.id) { article in
                        ArticleRowView(article: article)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Search Articles")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            return
        }
        
        Task {
            isSearching = true
            defer { isSearching = false }
            
            do {
                // Create a search service with current parameters
                let searchService = searchServiceFactory.makeArticleSearchService(
                    query: searchQuery,
                    filters: selectedFilters
                )
                
                searchResults = try await searchService.search()
            } catch {
                print("Search failed: \(error)")
                searchResults = []
            }
        }
    }
}
```

### Step 4: Comprehensive Testing

```swift
import XCTest
@testable import BlogApp

// MARK: - Repository Tests

@TestContainer
class ArticleRepositoryTests: XCTestCase {
    var container: Container!
    var networkService: APIClient!
    var cacheService: CacheService!
    var articleRepository: ArticleRepository!
    
    override func setUp() {
        super.setUp()
        container = setupTestContainer()
        
        networkService = container.resolve(APIClient.self)!
        cacheService = container.resolve(CacheService.self)!
        
        ArticleRepository.register(in: container)
        articleRepository = container.resolve(ArticleRepository.self)!
    }
    
    func testGetArticlesCachesResults() async throws {
        // Arrange
        let mockNetwork = networkService as! MockAPIClient
        let expectedArticles = [
            Article(id: "1", title: "Test Article", content: "Content", authorId: "author1", publishedAt: Date())
        ]
        mockNetwork.getResult = .success(expectedArticles)
        
        // Act - First call should hit network
        let articles1 = try await articleRepository.getArticles()
        
        // Reset mock for second call
        mockNetwork.getResult = .success([]) // Different result
        
        // Act - Second call should use cache
        let articles2 = try await articleRepository.getArticles()
        
        // Assert
        XCTAssertEqual(articles1.count, 1)
        XCTAssertEqual(articles2.count, 1) // Should be same as first call (cached)
        XCTAssertEqual(articles1[0].title, "Test Article")
        XCTAssertEqual(articles2[0].title, "Test Article")
        
        // Network should only be called once
        XCTAssertEqual(mockNetwork.getCallCount, 1)
    }
}

// MARK: - Factory Service Tests

@TestContainer
class ArticleDetailServiceTests: XCTestCase {
    var container: Container!
    var articleRepository: ArticleRepository!
    var authorRepository: AuthorRepository!
    var detailServiceFactory: ArticleDetailServiceFactory!
    
    override func setUp() {
        super.setUp()
        container = setupTestContainer()
        
        articleRepository = container.resolve(ArticleRepository.self)!
        authorRepository = container.resolve(AuthorRepository.self)!
        
        container.registerFactory(ArticleDetailServiceFactory.self)
        detailServiceFactory = container.resolve(ArticleDetailServiceFactory.self)!
    }
    
    func testLoadArticleWithAuthor() async throws {
        // Arrange
        let mockArticleRepo = articleRepository as! MockArticleRepository
        let mockAuthorRepo = authorRepository as! MockAuthorRepository
        
        let expectedArticle = Article(id: "123", title: "Test", content: "Content", authorId: "author1", publishedAt: Date())
        let expectedAuthor = Author(id: "author1", name: "John Doe", email: "john@example.com", bio: "Writer")
        
        mockArticleRepo.getArticleResult = .success(expectedArticle)
        mockAuthorRepo.getAuthorResult = .success(expectedAuthor)
        
        // Act
        let detailService = detailServiceFactory.makeArticleDetailService(articleId: "123")
        let (article, author) = try await detailService.loadArticleWithAuthor()
        
        // Assert
        XCTAssertEqual(article.id, "123")
        XCTAssertEqual(article.title, "Test")
        XCTAssertEqual(author.id, "author1")
        XCTAssertEqual(author.name, "John Doe")
        
        XCTAssertEqual(mockArticleRepo.getArticleId, "123")
        XCTAssertEqual(mockAuthorRepo.getAuthorId, "author1")
    }
}

// MARK: - Integration Tests

class BlogAppIntegrationTests: XCTestCase {
    var container: Container!
    
    override func setUp() {
        super.setUp()
        container = Container()
        let assembler = Assembler([BlogAssembly()], container: container)
    }
    
    func testFullDependencyGraph() {
        // Test that all services can be resolved
        XCTAssertNotNil(container.resolve(NetworkService.self))
        XCTAssertNotNil(container.resolve(CacheService.self))
        XCTAssertNotNil(container.resolve(ArticleRepository.self))
        XCTAssertNotNil(container.resolve(AuthorRepository.self))
        XCTAssertNotNil(container.resolve(ArticleDetailServiceFactory.self))
        XCTAssertNotNil(container.resolve(ArticleSearchServiceFactory.self))
        
        // Test that protocol bindings work
        XCTAssertNotNil(container.resolve(APIClient.self))
    }
    
    func testSingletonScoping() {
        // Container-scoped services should be singletons
        let network1 = container.resolve(NetworkService.self)!
        let network2 = container.resolve(NetworkService.self)!
        XCTAssertTrue(network1 === network2)
        
        let cache1 = container.resolve(CacheService.self)!
        let cache2 = container.resolve(CacheService.self)!
        XCTAssertTrue(cache1 === cache2)
    }
    
    func testGraphScoping() {
        // Graph-scoped services should be new instances
        let repo1 = container.resolve(ArticleRepository.self)!
        let repo2 = container.resolve(ArticleRepository.self)!
        XCTAssertFalse(repo1 === repo2)
    }
}
```

**Key Learnings from this Complete Example:**

1. **Architecture**: Clean separation between infrastructure, business logic, and UI
2. **Scoping**: Use `.container` for expensive resources, `.graph` for business logic
3. **Factories**: Perfect for services that need runtime parameters (article ID, search query)
4. **SwiftUI Integration**: Environment objects work seamlessly with dependency injection
5. **Testing**: `@TestContainer` makes testing all layers straightforward
6. **Real-world Patterns**: Caching, networking, async operations all work naturally

This example shows how SwinJectMacros scales from simple services to complex, real-world applications while maintaining clean, testable code with minimal boilerplate.

---

## 🎯 Next Steps

1. **Try the Examples**: Copy and adapt these examples to your own projects
2. **Start Simple**: Begin with `@Injectable` for basic services
3. **Add Factories**: Use `@AutoFactory` when you need runtime parameters
4. **Test Everything**: Use `@TestContainer` to make testing easy
5. **Add Cross-Cutting Concerns**: Use `@Interceptor` for logging, security, and performance monitoring
6. **Scale Up**: Apply these patterns to larger, more complex applications

**Questions?** Check out the [main README](../README.md) for more details or open an issue on GitHub!