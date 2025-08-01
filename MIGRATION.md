# Migration Guide: From Traditional DI to SwinjectUtilityMacros

This guide helps you migrate from traditional dependency injection patterns to SwinjectUtilityMacros, showing you exactly what changes and how to adopt the new macros incrementally.

## 📋 Table of Contents

1. [Migration Strategy](#migration-strategy)
2. [Service Registration Migration](#service-registration-migration)
3. [Factory Pattern Migration](#factory-pattern-migration)
4. [Testing Migration](#testing-migration)
5. [Cross-Cutting Concerns Migration](#cross-cutting-concerns-migration)
6. [Common Migration Scenarios](#common-migration-scenarios)
7. [Troubleshooting](#troubleshooting)

## Migration Strategy

### ✅ **Recommended Incremental Approach**

**Don't migrate everything at once!** Follow this proven migration path:

1. **Phase 1**: Migrate simple services (no dependencies)
2. **Phase 2**: Migrate services with dependencies  
3. **Phase 3**: Migrate factory patterns
4. **Phase 4**: Migrate test setup
5. **Phase 5**: Clean up old registration code

### 🔄 **Backward Compatibility**

SwinjectUtilityMacros is fully compatible with existing Swinject code. You can:
- Keep existing registrations and add new macro-based ones
- Mix manual registration with macro registration
- Migrate gradually without breaking existing functionality

## Service Registration Migration

### Basic Service Migration

#### ❌ **Before: Manual Registration**

```swift
// Service definition
class UserService {
    private let apiClient: APIClient
    private let logger: LoggerService
    
    init(apiClient: APIClient, logger: LoggerService) {
        self.apiClient = apiClient
        self.logger = logger
    }
    
    func getUser(id: String) -> User? {
        // implementation
    }
}

// Manual assembly (lots of boilerplate)
class UserAssembly: Assembly {
    func assemble(container: Container) {
        container.register(APIClient.self) { _ in
            HTTPAPIClient()
        }.inObjectScope(.container)
        
        container.register(LoggerService.self) { _ in
            ConsoleLogger()
        }
        
        container.register(UserService.self) { resolver in
            UserService(
                apiClient: resolver.resolve(APIClient.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }
    }
}
```

#### ✅ **After: With SwinjectUtilityMacros**

```swift
// Service definition with macro
@Injectable
class UserService {
    private let apiClient: APIClient
    private let logger: LoggerService
    
    init(apiClient: APIClient, logger: LoggerService) {
        self.apiClient = apiClient
        self.logger = logger
    }
    
    func getUser(id: String) -> User? {
        // implementation
    }
}

@Injectable(scope: .container)
class HTTPAPIClient: APIClient {
    init() {
        // implementation
    }
}

@Injectable
class ConsoleLogger: LoggerService {
    init() {
        // implementation  
    }
}

// Simplified assembly
class UserAssembly: Assembly {
    func assemble(container: Container) {
        // Auto-registration with macros
        ConsoleLogger.register(in: container)
        HTTPAPIClient.register(in: container)
        UserService.register(in: container)
        
        // Protocol bindings (still manual, but much less code)
        container.register(APIClient.self) { resolver in
            resolver.resolve(HTTPAPIClient.self)!
        }
        container.register(LoggerService.self) { resolver in
            resolver.resolve(ConsoleLogger.self)!
        }
    }
}
```

**💡 Migration Tip**: Start by adding `@Injectable` to services, then gradually clean up the assembly code.

### Scoped Service Migration

#### ❌ **Before: Manual Scoping**

```swift
class DatabaseService {
    init() {
        // Expensive initialization
    }
}

// Assembly
container.register(DatabaseService.self) { _ in
    DatabaseService()
}.inObjectScope(.container) // Singleton
```

#### ✅ **After: Declarative Scoping**

```swift
@Injectable(scope: .container)
class DatabaseService {
    init() {
        // Expensive initialization
    }
}

// Assembly
DatabaseService.register(in: container) // Scope is automatically applied
```

### Named Service Migration

#### ❌ **Before: Manual Named Registration**

```swift
// Multiple implementations
class StripePaymentProcessor: PaymentProcessor { }
class PayPalPaymentProcessor: PaymentProcessor { }

// Assembly
container.register(PaymentProcessor.self, name: "stripe") { _ in
    StripePaymentProcessor()
}
container.register(PaymentProcessor.self, name: "paypal") { _ in
    PayPalPaymentProcessor()
}
```

#### ✅ **After: Declarative Naming**

```swift
@Injectable(name: "stripe")
class StripePaymentProcessor: PaymentProcessor {
    init() { }
}

@Injectable(name: "paypal")
class PayPalPaymentProcessor: PaymentProcessor {
    init() { }
}

// Assembly - names are automatically applied
StripePaymentProcessor.register(in: container)
PayPalPaymentProcessor.register(in: container)
```

## Factory Pattern Migration

### Simple Factory Migration

#### ❌ **Before: Manual Factory**

```swift
// Manual factory protocol
protocol ReportGeneratorFactory {
    func makeReportGenerator(type: ReportType, dateRange: DateRange) -> ReportGenerator
}

// Manual factory implementation
class ReportGeneratorFactoryImpl: ReportGeneratorFactory {
    private let resolver: Resolver
    
    init(resolver: Resolver) {
        self.resolver = resolver
    }
    
    func makeReportGenerator(type: ReportType, dateRange: DateRange) -> ReportGenerator {
        return ReportGenerator(
            database: resolver.resolve(DatabaseService.self)!,
            emailService: resolver.resolve(EmailService.self)!,
            type: type,
            dateRange: dateRange
        )
    }
}

// Service that needs runtime parameters
class ReportGenerator {
    private let database: DatabaseService
    private let emailService: EmailService
    private let type: ReportType
    private let dateRange: DateRange
    
    init(database: DatabaseService, emailService: EmailService, 
         type: ReportType, dateRange: DateRange) {
        // implementation
    }
}

// Manual factory registration
container.register(ReportGeneratorFactory.self) { resolver in
    ReportGeneratorFactoryImpl(resolver: resolver)
}
```

#### ✅ **After: @AutoFactory**

```swift
// Service with macro
@AutoFactory
class ReportGenerator {
    private let database: DatabaseService    // Injected automatically
    private let emailService: EmailService  // Injected automatically
    private let type: ReportType            // Runtime parameter
    private let dateRange: DateRange        // Runtime parameter
    
    init(database: DatabaseService, emailService: EmailService, 
         type: ReportType, dateRange: DateRange) {
        // implementation
    }
}

// Assembly - factory is generated automatically
container.registerFactory(ReportGeneratorFactory.self)
```

**🎯 Massive Code Reduction**: From ~30 lines of boilerplate to just the `@AutoFactory` annotation!

### Async Factory Migration

#### ❌ **Before: Manual Async Factory**

```swift
protocol AsyncDataProcessorFactory {
    func makeAsyncDataProcessor(inputData: Data) async throws -> AsyncDataProcessor
}

class AsyncDataProcessorFactoryImpl: AsyncDataProcessorFactory {
    private let resolver: Resolver
    
    init(resolver: Resolver) {
        self.resolver = resolver
    }
    
    func makeAsyncDataProcessor(inputData: Data) async throws -> AsyncDataProcessor {
        return try await AsyncDataProcessor(
            apiClient: resolver.resolve(APIClient.self)!,
            validator: resolver.resolve(DataValidator.self)!,
            inputData: inputData
        )
    }
}

class AsyncDataProcessor {
    init(apiClient: APIClient, validator: DataValidator, inputData: Data) async throws {
        // Async initialization
    }
}
```

#### ✅ **After: @AutoFactory with Async**

```swift
@AutoFactory(async: true, throws: true)
class AsyncDataProcessor {
    private let apiClient: APIClient      // Injected
    private let validator: DataValidator  // Injected  
    private let inputData: Data          // Runtime parameter
    
    init(apiClient: APIClient, validator: DataValidator, inputData: Data) async throws {
        // Async initialization - automatically handled
    }
}

// Generated factory method signature:
// func makeAsyncDataProcessor(inputData: Data) async throws -> AsyncDataProcessor
```

## Testing Migration

### Test Setup Migration

#### ❌ **Before: Manual Test Setup**

```swift
class UserServiceTests: XCTestCase {
    var container: Container!
    var mockAPIClient: MockAPIClient!
    var mockLogger: MockLoggerService!
    var userService: UserService!
    
    override func setUp() {
        super.setUp()
        container = Container()
        
        // Create mocks manually
        mockAPIClient = MockAPIClient()
        mockLogger = MockLoggerService()
        
        // Register mocks manually
        container.register(APIClient.self) { _ in self.mockAPIClient }
        container.register(LoggerService.self) { _ in self.mockLogger }
        
        // Register service under test
        container.register(UserService.self) { resolver in
            UserService(
                apiClient: resolver.resolve(APIClient.self)!,
                logger: resolver.resolve(LoggerService.self)!
            )
        }
        
        userService = container.resolve(UserService.self)!
    }
    
    // Test methods...
}
```

#### ✅ **After: @TestContainer**

```swift
@TestContainer
class UserServiceTests: XCTestCase {
    var container: Container!
    
    // Services automatically detected for mocking
    var apiClient: APIClient!
    var logger: LoggerService!
    
    var userService: UserService!
    
    override func setUp() {
        super.setUp()
        
        // Generated method creates container with mocks
        container = setupTestContainer()
        
        // Resolve mocked dependencies
        apiClient = container.resolve(APIClient.self)!
        logger = container.resolve(LoggerService.self)!
        
        // Register and resolve service under test
        UserService.register(in: container)
        userService = container.resolve(UserService.self)!
    }
    
    // Test methods - same as before but much less setup code!
}
```

**💡 Migration Tip**: `@TestContainer` works with existing mock classes, so you don't need to change your mock implementations.

## Cross-Cutting Concerns Migration

### Migrating from Scattered Cross-Cutting Code to @Interceptor

One of the most powerful features of SwinjectUtilityMacros is the ability to clean up cross-cutting concerns using the `@Interceptor` macro.

#### ❌ **Before: Scattered Cross-Cutting Code**

```swift
class OrderService {
    private let repository: OrderRepository
    private let logger: Logger
    private let securityValidator: SecurityValidator
    private let performanceMonitor: PerformanceMonitor
    private let auditLogger: AuditLogger
    
    init(repository: OrderRepository, logger: Logger, 
         securityValidator: SecurityValidator, performanceMonitor: PerformanceMonitor,
         auditLogger: AuditLogger) {
        self.repository = repository
        self.logger = logger
        self.securityValidator = securityValidator
        self.performanceMonitor = performanceMonitor
        self.auditLogger = auditLogger
    }
    
    func createOrder(customerId: String, items: [OrderItem]) throws -> Order {
        // Logging
        logger.log("Creating order for customer: \(customerId)")
        let startTime = Date()
        
        // Security validation
        try securityValidator.validateCustomer(customerId)
        try securityValidator.validateOrderItems(items)
        
        // Business logic (buried in boilerplate!)
        let order = Order(customerId: customerId, items: items)
        let savedOrder = try repository.save(order)
        
        // More logging and monitoring
        let duration = Date().timeIntervalSince(startTime)
        logger.log("Order \(savedOrder.id) created in \(duration)ms")
        performanceMonitor.record("createOrder", duration: duration)
        auditLogger.log("Order created", orderId: savedOrder.id, customerId: customerId)
        
        return savedOrder
    }
}
```

#### ✅ **After: Clean Business Logic with @Interceptor**

```swift
@Injectable
class OrderService {
    private let repository: OrderRepository
    
    init(repository: OrderRepository) {
        self.repository = repository
    }
    
    @Interceptor(
        before: ["SecurityInterceptor", "LoggingInterceptor"],
        after: ["PerformanceInterceptor", "AuditInterceptor"]
    )
    func createOrder(customerId: String, items: [OrderItem]) throws -> Order {
        // Pure business logic - no clutter!
        let order = Order(customerId: customerId, items: items)
        return try repository.save(order)
    }
}
```

### Migration Strategy for Cross-Cutting Concerns

#### Step 1: Identify Cross-Cutting Code Patterns

Look for these common patterns in your existing code:
- Logging at method entry/exit
- Performance timing measurements
- Security/validation checks
- Audit trail logging
- Error handling and reporting
- Caching logic
- Transaction management

#### Step 2: Extract Cross-Cutting Logic into Interceptors  

```swift
// Before: Logging scattered everywhere
class UserService {
    func createUser(name: String) -> User {
        logger.log("Creating user: \(name)")
        let user = // ... business logic
        logger.log("User created: \(user.id)")
        return user
    }
    
    func deleteUser(id: String) {
        logger.log("Deleting user: \(id)")
        // ... business logic
        logger.log("User deleted: \(id)")
    }
}

// After: Centralized logging interceptor
class LoggingInterceptor: MethodInterceptor {
    func before(context: InterceptorContext) throws {
        print("🚀 Starting \(context.methodName) with: \(context.parameters)")
    }
    
    func after(context: InterceptorContext, result: Any?) throws {
        print("✅ Completed \(context.methodName) in \(context.executionTime)ms")
    }
}

@Injectable
class UserService {
    @Interceptor(before: ["LoggingInterceptor"])
    func createUser(name: String) -> User {
        // Pure business logic
        return User(name: name)
    }
    
    @Interceptor(before: ["LoggingInterceptor"])
    func deleteUser(id: String) {
        // Pure business logic
        repository.delete(id)
    }
}
```

#### Step 3: Incremental Migration Process

1. **Identify Methods with Cross-Cutting Concerns**
   ```bash
   # Search for common patterns
   grep -r "logger\." your_project/
   grep -r "startTime\|endTime" your_project/
   grep -r "validate\|security" your_project/
   ```

2. **Create Interceptors for Each Concern**
   ```swift
   // Start with the most common patterns
   class LoggingInterceptor: MethodInterceptor { /* ... */ }
   class SecurityInterceptor: MethodInterceptor { /* ... */ }
   class PerformanceInterceptor: MethodInterceptor { /* ... */ }
   ```

3. **Register Interceptors in App Startup**
   ```swift
   func setupInterceptors() {
       InterceptorRegistry.register(interceptor: LoggingInterceptor(), name: "LoggingInterceptor")
       InterceptorRegistry.register(interceptor: SecurityInterceptor(), name: "SecurityInterceptor")
       InterceptorRegistry.register(interceptor: PerformanceInterceptor(), name: "PerformanceInterceptor")
   }
   ```

4. **Migrate Methods One by One**
   ```swift
   // Before
   func processPayment(amount: Double) -> Result {
       logger.log("Processing payment: \(amount)")
       // business logic with scattered cross-cutting code
   }
   
   // After
   @Interceptor(before: ["LoggingInterceptor", "SecurityInterceptor"])
   func processPayment(amount: Double) -> Result {
       // clean business logic only
   }
   ```

5. **Remove Old Cross-Cutting Dependencies**
   ```swift
   // Remove these from your service constructors
   - logger: Logger
   - securityValidator: SecurityValidator  
   - performanceMonitor: PerformanceMonitor
   - auditLogger: AuditLogger
   ```

### Complex Cross-Cutting Scenarios

#### Conditional Interceptors

```swift
// Before: Complex conditional logic mixed with business logic
func processOrder(order: Order) throws -> ProcessedOrder {
    if isProductionEnvironment {
        securityValidator.validate(order)
        auditLogger.log("Processing order", orderId: order.id)
    }
    
    if enablePerformanceMonitoring {
        let startTime = Date()
        let result = doProcessOrder(order)
        performanceMonitor.record("processOrder", Date().timeIntervalSince(startTime))
        return result
    } else {
        return doProcessOrder(order)
    }
}

// After: Clean business logic with environment-specific interceptor registration
@Interceptor(
    before: ["ConditionalSecurityInterceptor"],
    after: ["ConditionalPerformanceInterceptor", "ConditionalAuditInterceptor"]
)
func processOrder(order: Order) throws -> ProcessedOrder {
    return doProcessOrder(order)
}

// Conditional interceptors handle environment logic
class ConditionalSecurityInterceptor: MethodInterceptor {
    func before(context: InterceptorContext) throws {
        if Environment.isProduction {
            try SecurityValidator.validate(context.parameters)
        }
    }
}
```

#### Transaction Management Migration

```swift
// Before: Manual transaction management scattered everywhere
func updateUserProfile(userId: String, profile: UserProfile) throws -> UserProfile {
    let transaction = database.beginTransaction()
    defer {
        if transaction.isActive {
            transaction.rollback()
        }
    }
    
    try validateProfile(profile)
    let updatedProfile = try repository.updateProfile(userId: userId, profile: profile)
    try auditLogger.logProfileUpdate(userId: userId, profile: profile)
    
    transaction.commit()
    return updatedProfile
}

// After: Transaction interceptor handles all transaction logic
@Injectable
class UserProfileService {
    @Interceptor(
        before: ["TransactionInterceptor", "ValidationInterceptor"],
        after: ["AuditInterceptor"],
        onError: ["TransactionRollbackInterceptor"]
    )
    func updateUserProfile(userId: String, profile: UserProfile) throws -> UserProfile {
        // Pure business logic - no transaction boilerplate
        return try repository.updateProfile(userId: userId, profile: profile)
    }
}
```

### Migration Testing Strategy

When migrating cross-cutting concerns, ensure your tests cover both business logic and interceptor behavior:

```swift
@TestContainer
class OrderServiceInterceptorMigrationTests: XCTestCase {
    var orderService: OrderService!
    
    override func setUp() {
        super.setUp()
        container = setupTestContainer()
        
        // Register test interceptors
        InterceptorRegistry.register(interceptor: TestSecurityInterceptor(), name: "SecurityInterceptor")
        InterceptorRegistry.register(interceptor: TestLoggingInterceptor(), name: "LoggingInterceptor")
        
        OrderService.register(in: container)
        orderService = container.resolve(OrderService.self)!
    }
    
    func testCreateOrderBusinessLogic() throws {
        // Test pure business logic (original method)
        let order = try orderService.createOrder(customerId: "123", items: [])
        XCTAssertEqual(order.customerId, "123")
    }
    
    func testCreateOrderWithInterceptors() throws {
        // Test intercepted version with cross-cutting concerns
        let order = try orderService.createOrderIntercepted(customerId: "123", items: [])
        
        // Verify business logic still works
        XCTAssertEqual(order.customerId, "123")
        
        // Verify interceptors were called
        let securityInterceptor = InterceptorRegistry.get(name: "SecurityInterceptor") as! TestSecurityInterceptor
        XCTAssertTrue(securityInterceptor.beforeCalled)
        
        let loggingInterceptor = InterceptorRegistry.get(name: "LoggingInterceptor") as! TestLoggingInterceptor
        XCTAssertTrue(loggingInterceptor.beforeCalled)
        XCTAssertTrue(loggingInterceptor.afterCalled)
    }
}
```

### Benefits of Cross-Cutting Concerns Migration

1. **Cleaner Business Logic**: Methods focus solely on business rules
2. **Reusable Concerns**: Write once, apply to multiple methods/services
3. **Easier Testing**: Test business logic and cross-cutting concerns separately
4. **Better Maintainability**: Change logging/security logic in one place
5. **Consistent Application**: All methods get the same cross-cutting behavior
6. **Performance**: No more scattered performance monitoring code

**💡 Migration Tip**: Start with the most common cross-cutting concern (usually logging) and gradually migrate others. The interceptor approach scales much better than scattered cross-cutting code.

## Common Migration Scenarios

### Scenario 1: Large Service with Many Dependencies

#### ❌ **Before**

```swift
class ComplexService {
    // 10+ dependencies
    init(dep1: Dep1, dep2: Dep2, dep3: Dep3, dep4: Dep4, dep5: Dep5,
         dep6: Dep6, dep7: Dep7, dep8: Dep8, dep9: Dep9, dep10: Dep10) {
        // initialization
    }
}

// Assembly - very error-prone manual registration
container.register(ComplexService.self) { resolver in
    ComplexService(
        dep1: resolver.resolve(Dep1.self)!,
        dep2: resolver.resolve(Dep2.self)!,
        dep3: resolver.resolve(Dep3.self)!,
        dep4: resolver.resolve(Dep4.self)!,
        dep5: resolver.resolve(Dep5.self)!,
        dep6: resolver.resolve(Dep6.self)!,
        dep7: resolver.resolve(Dep7.self)!,
        dep8: resolver.resolve(Dep8.self)!,
        dep9: resolver.resolve(Dep9.self)!,
        dep10: resolver.resolve(Dep10.self)!
    )
}
```

#### ✅ **After**

```swift
@Injectable
class ComplexService {
    // Same 10+ dependencies
    init(dep1: Dep1, dep2: Dep2, dep3: Dep3, dep4: Dep4, dep5: Dep5,
         dep6: Dep6, dep7: Dep7, dep8: Dep8, dep9: Dep9, dep10: Dep10) {
        // initialization
    }
}

// Assembly - one line!
ComplexService.register(in: container)
```

**🎯 Benefit**: Eliminates 15+ lines of error-prone boilerplate code.

### Scenario 2: Protocol-Based Architecture

#### ❌ **Before**

```swift
// Service implementations
class UserRepositoryImpl: UserRepository { 
    init(database: DatabaseService) { }
}

class EmailServiceImpl: EmailService { 
    init(smtpClient: SMTPClient) { }
}

// Assembly - lots of protocol binding code
container.register(DatabaseService.self) { _ in DatabaseServiceImpl() }
container.register(SMTPClient.self) { _ in SMTPClientImpl() }

container.register(UserRepositoryImpl.self) { resolver in
    UserRepositoryImpl(database: resolver.resolve(DatabaseService.self)!)
}
container.register(UserRepository.self) { resolver in
    resolver.resolve(UserRepositoryImpl.self)!
}

container.register(EmailServiceImpl.self) { resolver in
    EmailServiceImpl(smtpClient: resolver.resolve(SMTPClient.self)!)
}
container.register(EmailService.self) { resolver in
    resolver.resolve(EmailServiceImpl.self)!
}
```

#### ✅ **After**

```swift
// Service implementations with macros
@Injectable
class UserRepositoryImpl: UserRepository { 
    init(database: DatabaseService) { }
}

@Injectable
class EmailServiceImpl: EmailService { 
    init(smtpClient: SMTPClient) { }
}

@Injectable
class DatabaseServiceImpl: DatabaseService {
    init() { }
}

@Injectable
class SMTPClientImpl: SMTPClient {
    init() { }
}

// Assembly - much cleaner
DatabaseServiceImpl.register(in: container)
SMTPClientImpl.register(in: container)
UserRepositoryImpl.register(in: container)
EmailServiceImpl.register(in: container)

// Protocol bindings - still manual but much less code
container.register(DatabaseService.self) { resolver in
    resolver.resolve(DatabaseServiceImpl.self)!
}
container.register(SMTPClient.self) { resolver in
    resolver.resolve(SMTPClientImpl.self)!
}
container.register(UserRepository.self) { resolver in
    resolver.resolve(UserRepositoryImpl.self)!
}
container.register(EmailService.self) { resolver in
    resolver.resolve(EmailServiceImpl.self)!
}
```

### Scenario 3: Conditional Registration

Sometimes you need different implementations based on configuration.

#### ❌ **Before**

```swift
// Assembly with conditional logic
func assemble(container: Container) {
    if isProduction {
        container.register(Logger.self) { _ in
            ProductionLogger()
        }
    } else {
        container.register(Logger.self) { _ in
            DebugLogger()
        }
    }
}
```

#### ✅ **After - Hybrid Approach**

```swift
// Mark both implementations as injectable
@Injectable
class ProductionLogger: Logger {
    init() { }
}

@Injectable  
class DebugLogger: Logger {
    init() { }
}

// Assembly - conditional logic for selection
func assemble(container: Container) {
    ProductionLogger.register(in: container)
    DebugLogger.register(in: container)
    
    // Conditional binding to protocol
    if isProduction {
        container.register(Logger.self) { resolver in
            resolver.resolve(ProductionLogger.self)!
        }
    } else {
        container.register(Logger.self) { resolver in
            resolver.resolve(DebugLogger.self)!
        }
    }
}
```

**💡 Migration Strategy**: Keep conditional logic in assembly, but use macros for the service registration.

## Step-by-Step Migration Process

### Phase 1: Preparation (No Code Changes)

1. **Add SwinjectUtilityMacros to your project**
2. **Import the library** in your service files
3. **Run your existing tests** to ensure nothing breaks

### Phase 2: Migrate Simple Services

1. **Identify services with no dependencies**
2. **Add `@Injectable` annotation**
3. **Update assembly to use generated `register` method**
4. **Test and verify behavior**

```swift
// Start with the simplest services
@Injectable  // <- Add this
class LoggerService {
    init() { }
}

// In assembly
LoggerService.register(in: container)  // <- Replace manual registration
```

### Phase 3: Migrate Services with Dependencies

1. **Migrate leaf services first** (services that others depend on)
2. **Work your way up the dependency tree**
3. **Update each service one by one**

### Phase 4: Migrate Factories

1. **Identify services that need runtime parameters**
2. **Replace manual factory code with `@AutoFactory`**
3. **Update factory registration in assembly**

### Phase 5: Migrate Tests

1. **Add `@TestContainer` to test classes**
2. **Remove manual mock setup code**
3. **Verify all tests still pass**

### Phase 6: Cleanup

1. **Remove old registration code from assemblies**
2. **Delete manual factory implementations**
3. **Clean up unused imports and files**

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Cannot find 'register' in scope"

**Problem**: You forgot to add `@Injectable` to a service.

```swift
// ❌ Missing @Injectable
class MyService {
    init() { }
}

// Assembly
MyService.register(in: container) // ❌ Error: register method doesn't exist
```

**Solution**: Add the `@Injectable` annotation.

```swift
// ✅ Fixed
@Injectable
class MyService {
    init() { }
}
```

#### Issue: Runtime parameters in @Injectable service

**Problem**: Service has runtime parameters that can't be pre-registered.

```swift
// ❌ Will cause compiler warning
@Injectable
class SearchService {
    init(apiClient: APIClient, query: String) { // ⚠️ query is runtime parameter
        // ...
    }
}
```

**Solution**: Use `@AutoFactory` instead.

```swift
// ✅ Fixed
@AutoFactory
class SearchService {
    init(apiClient: APIClient, query: String) {
        // ...
    }
}
```

#### Issue: Circular dependency errors

**Problem**: Two services depend on each other.

```swift
@Injectable
class ServiceA {
    init(serviceB: ServiceB) { } // Depends on B
}

@Injectable
class ServiceB {
    init(serviceA: ServiceA) { } // Depends on A - circular!
}
```

**Solution**: Break the cycle with protocols or refactor.

```swift
protocol ServiceAProtocol { }

@Injectable
class ServiceA: ServiceAProtocol {
    init(serviceB: ServiceB) { }
}

@Injectable
class ServiceB {
    init(serviceA: ServiceAProtocol) { } // Now uses protocol
}
```

#### Issue: Protocol registration still needed

**Problem**: Expecting protocols to be automatically registered.

```swift
@Injectable
class ConcreteService: MyProtocol {
    init() { }
}

// Later...
let service = container.resolve(MyProtocol.self) // ❌ Returns nil
```

**Explanation**: Macros only register concrete types, not protocols.

**Solution**: Manually register protocol bindings.

```swift
// Assembly
ConcreteService.register(in: container)
container.register(MyProtocol.self) { resolver in
    resolver.resolve(ConcreteService.self)!
}
```

### Performance Considerations

#### Memory Usage

**Before**: Runtime reflection and dynamic registration
**After**: Compile-time code generation - zero runtime overhead

#### Build Time

**Impact**: Swift macros run during compilation, adding minimal build time
**Benefit**: Catches dependency errors at compile-time instead of runtime

#### App Startup

**Before**: Container setup happens at runtime
**After**: Same runtime performance, but with less code to execute

## Migration Checklist

Use this checklist to track your migration progress:

### Pre-Migration
- [ ] Add SwinjectUtilityMacros dependency
- [ ] Run existing tests to establish baseline
- [ ] Document current assembly structure

### Service Migration
- [ ] Identify all services in dependency graph
- [ ] Migrate leaf services (no dependencies) first
- [ ] Add `@Injectable` annotations
- [ ] Update assembly registration calls
- [ ] Test each service as you migrate it

### Factory Migration  
- [ ] Identify factory patterns in codebase
- [ ] Replace manual factories with `@AutoFactory`
- [ ] Update factory registrations
- [ ] Test factory creation and usage

### Test Migration
- [ ] Add `@TestContainer` to test classes
- [ ] Remove manual mock setup code
- [ ] Verify all tests pass
- [ ] Clean up unused test helper code

### Cleanup
- [ ] Remove old manual registration code
- [ ] Delete unused factory implementations
- [ ] Update documentation
- [ ] Run full test suite
- [ ] Performance test if needed

### Validation
- [ ] All services resolve correctly
- [ ] Object scoping works as expected
- [ ] Named services resolve properly
- [ ] Factory parameters work correctly
- [ ] Tests pass consistently

## Next Steps

After completing your migration:

1. **Explore Advanced Features**: Look into upcoming macros like `@Interceptor` and `@PerformanceTracked`
2. **Optimize Your Architecture**: Consider refactoring to take advantage of cleaner dependency injection
3. **Share Your Experience**: Help others by documenting your migration experience
4. **Stay Updated**: Watch for new macro releases and features

---

**Need Help?** 
- Check the [main README](README.md) for detailed macro documentation
- Browse [Examples/GettingStarted.md](Examples/GettingStarted.md) for practical tutorials
- Open an issue on GitHub if you encounter migration challenges

**Migration taking too long?** Consider migrating incrementally - SwinjectUtilityMacros works alongside existing Swinject code, so you can take your time! 🚀