# Injectable

Automatically generate dependency injection registration code for your services.

## Overview

The `@Injectable` macro is the cornerstone of SwinjectMacros, eliminating the need to write boilerplate dependency injection registration code. It analyzes your service's initializer and automatically generates the correct registration code with proper dependency resolution.

## Basic Usage

### Simple Service Registration

```swift
import SwinjectMacros
import Swinject

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

**Generated Code:**

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

### Registration and Usage

```swift
// In your assembly
class AppAssembly: Assembly {
    func assemble(container: Container) {
        // Register all injectable services
        UserService.register(in: container)
        APIClient.register(in: container)
        DatabaseService.register(in: container)
    }
}

// Usage
let container = Container()
let assembler = Assembler([AppAssembly()], container: container)
let userService = container.resolve(UserService.self)!
```

## Configuration Options

### Object Scopes

Control the lifecycle of your services with different scopes:

```swift
// Default scope (.graph) - new instance per object graph
@Injectable
class UserService {
    init(apiClient: APIClient) { }
}

// Container scope - singleton within container
@Injectable(scope: .container)
class DatabaseService {
    init() {
        // Expensive initialization - share across container
    }
}

// Singleton scope - global singleton
@Injectable(scope: .singleton)
class ConfigurationService {
    init() {
        // App-wide configuration
    }
}

// Transient scope - new instance every time
@Injectable(scope: .transient)
class RequestProcessor {
    init(logger: LoggerService) { }
}

// Weak scope - shared while strong references exist
@Injectable(scope: .weak)
class CacheService {
    init() { }
}
```

### Named Services

Register multiple implementations of the same protocol:

```swift
protocol PaymentProcessor {
    func process(payment: Payment) async throws
}

@Injectable(name: "stripe")
class StripePaymentProcessor: PaymentProcessor {
    init(apiKey: String) { }

    func process(payment: Payment) async throws {
        // Stripe implementation
    }
}

@Injectable(name: "paypal")
class PayPalPaymentProcessor: PaymentProcessor {
    init(clientId: String, secret: String) { }

    func process(payment: Payment) async throws {
        // PayPal implementation
    }
}

// Usage
let stripeProcessor = container.resolve(PaymentProcessor.self, name: "stripe")
let paypalProcessor = container.resolve(PaymentProcessor.self, name: "paypal")
```

### Combined Configuration

```swift
@Injectable(scope: .container, name: "primary")
class PrimaryDatabaseService: DatabaseService {
    init(connectionString: String) { }
}

@Injectable(scope: .container, name: "secondary")
class SecondaryDatabaseService: DatabaseService {
    init(connectionString: String) { }
}
```

## Smart Dependency Classification

The macro automatically analyzes your initializer parameters and classifies them:

### Service Dependencies

Types that follow service naming conventions are automatically resolved:

```swift
@Injectable
class OrderService {
    // These are automatically detected as service dependencies
    init(
        userService: UserService,           // Service suffix
        paymentClient: PaymentClient,       // Client suffix
        inventoryRepository: InventoryRepository, // Repository suffix
        auditLogger: AuditLogger,          // Logger suffix
        emailGateway: EmailGateway,        // Gateway suffix
        cacheManager: CacheManager         // Manager suffix
    ) { }
}
```

**Generated registration:**

```swift
container.register(OrderService.self) { resolver in
    OrderService(
        userService: resolver.resolve(UserService.self)!,
        paymentClient: resolver.resolve(PaymentClient.self)!,
        inventoryRepository: resolver.resolve(InventoryRepository.self)!,
        auditLogger: resolver.resolve(AuditLogger.self)!,
        emailGateway: resolver.resolve(EmailGateway.self)!,
        cacheManager: resolver.resolve(CacheManager.self)!
    )
}
```

### Protocol Dependencies

Protocol types are also automatically handled:

```swift
@Injectable
class NotificationService {
    init(
        emailSender: any EmailSending,     // Protocol dependency
        pushNotifier: any PushNotifying,   // Protocol dependency
        logger: LoggerService              // Concrete dependency
    ) { }
}
```

### Optional Dependencies

Optional dependencies are resolved without force unwrapping:

```swift
@Injectable
class AnalyticsService {
    private let logger: LoggerService?    // Optional dependency
    private let database: DatabaseService // Required dependency

    init(logger: LoggerService?, database: DatabaseService) {
        self.logger = logger
        self.database = database
    }
}
```

**Generated registration:**

```swift
container.register(AnalyticsService.self) { resolver in
    AnalyticsService(
        logger: resolver.resolve(LoggerService.self),        // No force unwrap
        database: resolver.resolve(DatabaseService.self)!   // Force unwrap for required
    )
}
```

### Configuration Parameters

Parameters with default values are handled appropriately:

```swift
@Injectable
class EmailService {
    init(
        smtpClient: SMTPClient,
        timeout: TimeInterval = 30.0,    // Default value used
        retryCount: Int = 3              // Default value used
    ) { }
}
```

## Advanced Features

### Generic Services

The macro handles generic types with proper constraint preservation:

```swift
@Injectable
class Repository<T: Codable> {
    private let database: DatabaseService

    init(database: DatabaseService) {
        self.database = database
    }

    func save(_ entity: T) async throws {
        try await database.save(entity)
    }
}

// Register specific types
Repository<User>.register(in: container)
Repository<Order>.register(in: container)
```

### Protocol Registration

Register both concrete types and their protocols:

```swift
protocol UserServiceProtocol {
    func getUser(id: String) async throws -> User
}

@Injectable
class UserService: UserServiceProtocol {
    init(apiClient: APIClient) { }

    func getUser(id: String) async throws -> User {
        // Implementation
    }
}

// Manual protocol registration (if needed)
class AppAssembly: Assembly {
    func assemble(container: Container) {
        UserService.register(in: container)

        // Register protocol to concrete mapping
        container.register(UserServiceProtocol.self) { resolver in
            resolver.resolve(UserService.self)!
        }
    }
}
```

### Thread-Safe Resolution

All generated code uses thread-safe resolution:

```swift
// Generated code automatically includes synchronization
container.register(UserService.self) { resolver in
    UserService(
        apiClient: resolver.synchronizedResolve(APIClient.self)!,
        database: resolver.synchronizedResolve(DatabaseService.self)!
    )
}.inObjectScope(.graph)
```

## Error Handling and Warnings

### Runtime Parameter Warning

If you accidentally include runtime parameters in an `@Injectable` service, you'll get a helpful warning:

```swift
@Injectable  // ⚠️ Warning: Runtime parameter detected
class ReportService {
    init(
        database: DatabaseService,  // Service dependency ✅
        reportType: String         // Runtime parameter ⚠️
    ) { }
}
```

**Warning message:**
```
warning: Runtime parameter 'reportType' detected in @Injectable service.
Consider using @AutoFactory for services that need runtime parameters.
```

**Solution:** Use `@AutoFactory` instead:

```swift
@AutoFactory
class ReportService {
    init(database: DatabaseService, reportType: String) { }
}
```

### Missing Dependencies

If a dependency isn't registered, you'll get a clear runtime error:

```swift
// If APIClient isn't registered
let userService = container.resolve(UserService.self)
// Runtime error: "Failed to resolve dependency: APIClient"
```

## Performance Characteristics

### Compile-Time Generation

- All registration code is generated at compile time
- Zero runtime overhead for dependency analysis
- No reflection or dynamic proxy creation

### Memory Efficiency

- Generated code uses direct method calls
- Minimal memory footprint
- No additional wrapper objects

### Thread Safety

- All generated resolution calls are thread-safe
- Uses `synchronizedResolve` for concurrent access
- No locks needed in generated code

## Best Practices

### 1. Service Naming Conventions

Use clear naming conventions for automatic detection:

```swift
// ✅ Good - automatically detected as services
class UserService { }
class PaymentClient { }
class OrderRepository { }
class EmailGateway { }

// ❌ Avoid - may not be detected as services
class UserThing { }
class PaymentHelper { }
class OrderUtils { }
```

### 2. Dependency Management

Keep dependencies focused and minimal:

```swift
// ✅ Good - focused dependencies
@Injectable
class UserService {
    init(apiClient: APIClient, repository: UserRepository) { }
}

// ❌ Avoid - too many dependencies (code smell)
@Injectable
class GodService {
    init(dep1: Dep1, dep2: Dep2, /* ... */, dep15: Dep15) { }
}
```

### 3. Scope Selection

Choose appropriate scopes for your services:

```swift
// Use .container for expensive resources
@Injectable(scope: .container)
class DatabaseConnection { }

// Use .graph (default) for business logic
@Injectable
class UserService { }

// Use .singleton sparingly for app-wide state
@Injectable(scope: .singleton)
class AppConfiguration { }
```

### 4. Protocol-Based Design

Design with protocols for better testability:

```swift
protocol UserServiceProtocol {
    func getUser(id: String) async throws -> User
}

@Injectable
class UserService: UserServiceProtocol {
    init(apiClient: any APIClientProtocol) { }

    func getUser(id: String) async throws -> User {
        // Implementation
    }
}
```

## Common Patterns

### Service Layer Pattern

```swift
// Data Layer
@Injectable(scope: .container)
class DatabaseService {
    init() { }
}

@Injectable
class UserRepository {
    init(database: DatabaseService) { }
}

// Service Layer
@Injectable
class UserService {
    init(repository: UserRepository, validator: UserValidator) { }
}

// Presentation Layer
@Injectable
class UserViewController {
    init(userService: UserService) { }
}
```

### Configuration Service Pattern

```swift
@Injectable(scope: .singleton)
class ConfigurationService {
    let apiBaseURL: String
    let timeout: TimeInterval

    init() {
        // Load from environment, plist, etc.
        self.apiBaseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "https://api.example.com"
        self.timeout = 30.0
    }
}

@Injectable
class APIClient {
    init(config: ConfigurationService) {
        // Use configuration
    }
}
```

### Factory Service Pattern

When you need runtime parameters, combine with `@AutoFactory`:

```swift
// Core service without runtime parameters
@Injectable
class EmailService {
    init(smtpClient: SMTPClient, logger: LoggerService) { }

    func send(email: Email) async throws {
        // Implementation
    }
}

// Factory for services with runtime parameters
@AutoFactory
class EmailComposer {
    init(emailService: EmailService, recipient: String, template: EmailTemplate) {
        // emailService is injected, recipient and template are runtime parameters
    }
}
```

## Migration Guide

### From Manual Swinject Registration

**Before:**

```swift
class AppAssembly: Assembly {
    func assemble(container: Container) {
        container.register(APIClient.self) { _ in
            APIClientImpl()
        }.inObjectScope(.container)

        container.register(UserService.self) { resolver in
            UserService(
                apiClient: resolver.resolve(APIClient.self)!
            )
        }.inObjectScope(.graph)
    }
}
```

**After:**

```swift
@Injectable(scope: .container)
class APIClientImpl: APIClient {
    init() { }
}

@Injectable
class UserService {
    init(apiClient: APIClient) { }
}

class AppAssembly: Assembly {
    func assemble(container: Container) {
        APIClientImpl.register(in: container)
        UserService.register(in: container)

        // Register protocol mappings if needed
        container.register(APIClient.self) { resolver in
            resolver.resolve(APIClientImpl.self)!
        }
    }
}
```

## Troubleshooting

### Common Issues

**Issue:** Circular dependencies
```
error: Circular dependency detected: UserService -> OrderService -> UserService
```

**Solution:** Break the cycle with protocols or redesign:

```swift
protocol UserServiceProtocol {
    func getUser(id: String) async -> User?
}

@Injectable
class UserService: UserServiceProtocol {
    init(orderService: OrderService) { }
}

@Injectable
class OrderService {
    init(userService: any UserServiceProtocol) { }
}
```

**Issue:** Missing protocol registration
```
fatal error: Unable to resolve dependency: APIClient
```

**Solution:** Register the protocol mapping:

```swift
container.register(APIClient.self) { resolver in
    resolver.resolve(APIClientImpl.self)!
}
```

## See Also

- <doc:AutoFactory>
- <doc:TestContainer>
- <doc:Container-Management>
- <doc:API-Reference>
