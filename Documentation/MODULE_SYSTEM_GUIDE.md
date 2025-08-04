# Module System Documentation & Migration Guide

## Table of Contents

1. [Introduction](#introduction)
1. [Core Concepts](#core-concepts)
1. [Getting Started](#getting-started)
1. [Module Definition](#module-definition)
1. [Module Composition](#module-composition)
1. [Module Scopes](#module-scopes)
1. [Dependency Graph Analysis](#dependency-graph-analysis)
1. [Migration Guide](#migration-guide)
1. [Best Practices](#best-practices)
1. [Troubleshooting](#troubleshooting)

## Introduction

The SwinjectMacros Module System provides a powerful, compile-time safe approach to organizing dependency injection in large-scale Swift applications. It enables true modular architecture with clear boundaries, explicit dependencies, and isolated testing.

### Key Benefits

- **Compile-time Safety**: Catch dependency issues at build time
- **Module Isolation**: Clear boundaries between feature modules
- **Scalable Development**: Teams can work independently
- **Progressive Complexity**: Start simple, add features as needed
- **Enterprise Ready**: Production-grade with comprehensive testing

## Core Concepts

### Modules

A module is a self-contained unit of functionality with:

- **Services**: Components the module provides
- **Dependencies**: Other modules it requires
- **Exports**: Services available to other modules
- **Priority**: Initialization order control

### Module Hierarchy

```
Application
    ├── Core Modules (Priority: 100+)
    │   ├── Network
    │   ├── Database
    │   └── Security
    ├── Feature Modules (Priority: 50-99)
    │   ├── User
    │   ├── Payment
    │   └── Analytics
    └── UI Modules (Priority: 0-49)
        ├── Onboarding
        ├── Settings
        └── Profile
```

### Module Lifecycle

1. **Registration**: Module is registered with the system
1. **Dependency Resolution**: Dependencies are validated
1. **Initialization**: Module's services are configured
1. **Runtime**: Services are available for injection
1. **Shutdown**: Module cleanup and resource release

## Getting Started

### Installation

Add the module system to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/SwinjectMacros.git", from: "2.0.0")
]
```

### Basic Module Definition

```swift
import SwinjectMacros
import Swinject

@Module(name: "Network")
struct NetworkModule {
    static func configure(_ container: Container) {
        container.register(HTTPClient.self) { _ in
            URLSessionHTTPClient()
        }
    }
}
```

### Module Registration and Initialization

```swift
// In your app startup
let moduleSystem = ModuleSystem.shared

// Register modules
NetworkModule.register(in: moduleSystem)
DatabaseModule.register(in: moduleSystem)

// Initialize the system
try moduleSystem.initialize()

// Resolve services
let httpClient = moduleSystem.resolve(HTTPClient.self)
```

## Module Definition

### Using @Module Macro

The `@Module` macro provides a declarative way to define modules:

```swift
@Module(
    name: "User",                              // Module name
    priority: 50,                              // Initialization priority
    dependencies: [NetworkModule.self],        // Required modules
    exports: [UserServiceInterface.self]       // Exported services
)
struct UserModule {
    static func configure(_ container: Container) {
        // Service registrations
    }
}
```

### Using @Provides Macro

Register services declaratively within modules:

```swift
@Module(name: "Database")
struct DatabaseModule {

    @Provides(scope: .singleton)
    static func database() -> DatabaseInterface {
        return SQLiteDatabase()
    }

    @Provides
    static func cache() -> CacheInterface {
        return InMemoryCache()
    }

    @Provides(name: "user_cache")
    static func userCache() -> CacheInterface {
        return DiskCache(directory: "users")
    }
}
```

### Module Interfaces

Define protocols that can be shared across module boundaries:

```swift
@ModuleInterface
protocol UserServiceInterface {
    func getUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

@ModuleInterface
protocol PaymentServiceInterface {
    func processPayment(_ amount: Decimal) async throws -> PaymentResult
}
```

## Module Composition

### Including Other Modules

Use `@Include` to compose modules:

```swift
@Module(name: "App")
struct AppModule {
    @Include(NetworkModule.self)
    @Include(DatabaseModule.self)
    @Include(UserModule.self)
    @Include(AnalyticsModule.self)
}
```

### Conditional Inclusion

Include modules based on conditions:

```swift
@Module(name: "App")
struct AppModule {
    // Always included
    @Include(CoreModule.self)

    // Debug-only modules
    @Include(DebugModule.self, condition: .debug)

    // Feature flag controlled
    @Include(PaymentModule.self, condition: .featureFlag("payments_enabled"))

    // Custom condition
    @Include(BetaModule.self, condition: .custom {
        UserDefaults.standard.bool(forKey: "beta_features")
    })
}
```

### Feature Flags

Control module loading with feature flags:

```swift
// Enable feature flags
FeatureFlags.enable("payments_enabled")
FeatureFlags.enable("analytics_enabled")

// Check if enabled
if FeatureFlags.isEnabled("payments_enabled") {
    // Payment features available
}

// Disable features
FeatureFlags.disable("beta_features")
```

## Module Scopes

### Module-Level Singletons

The module scope ensures services are singletons within their module:

```swift
@Module(name: "Database")
struct DatabaseModule {
    static func configure(_ container: Container) {
        // Singleton within this module only
        container.register(Connection.self) { _ in
            DatabaseConnection()
        }.inObjectScope(.module)

        // Or use the convenience method
        container.registerModuleScoped(Cache.self) { _ in
            InMemoryCache()
        }
    }
}
```

### Using @ModuleScoped Property Wrapper

Inject module-scoped dependencies:

```swift
class UserViewModel {
    @ModuleScoped(UserService.self, module: "User")
    var userService: UserService

    @ModuleScoped(Analytics.self)
    var analytics: Analytics

    func loadUser() async {
        let user = await userService.getCurrentUser()
        analytics.track("user_loaded")
    }
}
```

### Module Context

Execute code within a specific module context:

```swift
let context = ModuleContext(identifier: "Payment")
context.execute {
    // All resolutions here happen within Payment module context
    let paymentService = container.resolve(PaymentService.self)
    let paymentValidator = container.resolve(PaymentValidator.self)
}

// Async version
await context.execute {
    await processPayment()
}
```

## Dependency Graph Analysis

### Analyzing Module Dependencies

```swift
let analyzer = ModuleDependencyGraphAnalyzer()
let result = analyzer.analyze()

// Check for issues
if result.hasIssues {
    print("Found issues:")
    print("Circular dependencies: \(result.circularDependencies)")
    print("Missing dependencies: \(result.missingDependencies)")
}

// Get initialization order
print("Initialization order: \(result.initializationOrder)")
```

### Generating Visualizations

Generate GraphViz DOT format:

```swift
let dot = analyzer.generateDOT()
// Save to file and render with GraphViz
```

Generate Mermaid diagram:

```swift
let mermaid = analyzer.generateMermaid()
// Use in documentation or GitHub README
```

Generate text report:

```swift
let report = analyzer.generateReport()
print(report)
```

Example output:

```
Module Dependency Analysis Report
==================================================

Summary:
  Total Modules: 6
  Total Dependencies: 8
  Circular Dependencies: None ✅
  Missing Dependencies: None ✅

Initialization Order:
  1. Network ✅ (Priority: 100)
  2. Database ✅ (Priority: 90)
  3. User ✅ (Priority: 50)
  4. Payment ⏳ (Priority: 30)
  5. Analytics ✅ (Priority: 20)
  6. App ✅ (Priority: 0)
```

## Migration Guide

### From Existing Swinject Setup

#### Step 1: Identify Module Boundaries

Analyze your current code to identify natural module boundaries:

```swift
// Before: Monolithic registration
class AppAssembly: Assembly {
    func assemble(container: Container) {
        // Network
        container.register(HTTPClient.self) { _ in URLSessionHTTPClient() }
        container.register(APIClient.self) { r in
            APIClient(httpClient: r.resolve(HTTPClient.self)!)
        }

        // Database
        container.register(Database.self) { _ in SQLiteDatabase() }
        container.register(UserRepository.self) { r in
            UserRepository(database: r.resolve(Database.self)!)
        }

        // Services
        container.register(UserService.self) { r in
            UserService(
                api: r.resolve(APIClient.self)!,
                repository: r.resolve(UserRepository.self)!
            )
        }
    }
}
```

#### Step 2: Create Module Structure

Convert to modular structure:

```swift
// After: Modular structure

@Module(name: "Network", priority: 100)
struct NetworkModule {
    static func configure(_ container: Container) {
        container.register(HTTPClient.self) { _ in
            URLSessionHTTPClient()
        }
        container.register(APIClient.self) { r in
            APIClient(httpClient: r.resolve(HTTPClient.self)!)
        }
    }
}

@Module(name: "Database", priority: 90)
struct DatabaseModule {
    static func configure(_ container: Container) {
        container.register(Database.self) { _ in
            SQLiteDatabase()
        }
        container.register(UserRepository.self) { r in
            UserRepository(database: r.resolve(Database.self)!)
        }
    }
}

@Module(
    name: "User",
    dependencies: [NetworkModule.self, DatabaseModule.self]
)
struct UserModule {
    static func configure(_ container: Container) {
        container.register(UserService.self) { r in
            UserService(
                api: r.resolve(APIClient.self)!,
                repository: r.resolve(UserRepository.self)!
            )
        }
    }
}
```

#### Step 3: Update App Initialization

```swift
// Before
let container = Container()
let assembler = Assembler([
    AppAssembly(),
    NetworkAssembly(),
    DatabaseAssembly()
], container: container)

// After
let moduleSystem = ModuleSystem.shared
AppModule.register(in: moduleSystem) // AppModule includes all others
try moduleSystem.initialize()

// Services are now resolved from module system
let userService = moduleSystem.resolve(UserService.self)
```

### From Factory or Resolver

#### Step 1: Convert Factory Definitions

```swift
// Before: Factory
extension Container {
    var userService: Factory<UserService> {
        Factory(self) {
            UserService(
                api: self.apiClient(),
                database: self.database()
            )
        }.singleton
    }
}

// After: Module with @Provides
@Module(name: "User")
struct UserModule {
    @Provides(scope: .singleton)
    static func userService(
        api: APIClient,
        database: Database
    ) -> UserService {
        UserService(api: api, database: database)
    }
}
```

#### Step 2: Update Resolution

```swift
// Before: Factory
let userService = Container.shared.userService()

// After: Module System
let userService = ModuleSystem.shared.resolve(UserService.self)
```

### Gradual Migration Strategy

1. **Phase 1: Coexistence**

   - Keep existing DI setup
   - Add module system alongside
   - Migrate one feature at a time

1. **Phase 2: Module Extraction**

   - Extract core services (Network, Database)
   - Create feature modules
   - Update tests to use modules

1. **Phase 3: Full Migration**

   - Remove old DI code
   - Complete module system adoption
   - Add dependency analysis tools

## Best Practices

### Module Design

1. **Single Responsibility**: Each module should have a clear, single purpose
1. **Minimal Dependencies**: Reduce coupling between modules
1. **Interface Segregation**: Export only necessary interfaces
1. **Dependency Inversion**: Depend on abstractions, not concretions

### Naming Conventions

```swift
// Module names: PascalCase, descriptive
@Module(name: "UserAuthentication")
@Module(name: "PaymentProcessing")

// Interface suffix for protocols
@ModuleInterface
protocol UserServiceInterface { }

// Implementation suffix for concrete types
class UserServiceImplementation: UserServiceInterface { }
```

### Testing Modules

```swift
class UserModuleTests: XCTestCase {
    var moduleSystem: ModuleSystem!

    override func setUp() {
        super.setUp()
        moduleSystem = ModuleSystem()

        // Register test doubles
        TestNetworkModule.register(in: moduleSystem)
        TestDatabaseModule.register(in: moduleSystem)
        UserModule.register(in: moduleSystem)

        try! moduleSystem.initialize()
    }

    func testUserServiceResolution() {
        let userService = moduleSystem.resolve(UserService.self)
        XCTAssertNotNil(userService)
    }
}
```

### Performance Optimization

1. **Lazy Loading**: Use `.inObjectScope(.weak)` for rarely used services
1. **Module Priorities**: Higher priority for core services
1. **Conditional Loading**: Use feature flags to skip unused modules
1. **Scope Management**: Use appropriate scopes (transient, graph, container, module)

## Troubleshooting

### Common Issues and Solutions

#### Circular Dependencies

**Problem**: Module A depends on Module B, which depends on Module A

**Solution**:

1. Identify the cycle using dependency analyzer
1. Extract shared interfaces to a separate module
1. Use dependency inversion principle

```swift
// Before: Circular dependency
@Module(dependencies: [ModuleB.self])
struct ModuleA { }

@Module(dependencies: [ModuleA.self])
struct ModuleB { }

// After: Shared interface module
@Module
struct SharedInterfaces { }

@Module(dependencies: [SharedInterfaces.self])
struct ModuleA { }

@Module(dependencies: [SharedInterfaces.self])
struct ModuleB { }
```

#### Missing Dependencies

**Problem**: Module initialization fails with missing dependency

**Solution**:

1. Check module registration order
1. Verify all dependencies are registered
1. Use dependency analyzer to identify missing modules

```swift
// Debug missing dependencies
let analyzer = ModuleDependencyGraphAnalyzer()
let result = analyzer.analyze()
print(result.missingDependencies)
```

#### Service Resolution Failures

**Problem**: Service returns nil when resolved

**Solution**:

1. Verify module is initialized
1. Check service registration in module
1. Ensure correct scope is used

```swift
// Debug service resolution
if let info = moduleSystem.info(for: "UserModule") {
    print("Module initialized: \(info.isInitialized)")
    print("Module exports: \(info.exports)")
}
```

### Debug Mode

Enable debug logging for module system:

```swift
// In AppDelegate or main.swift
#if DEBUG
setenv("SWINJECT_DEBUG", "1", 1)
DebugLogger.setMinimumLevel(.verbose)
#endif
```

### Performance Profiling

```swift
let startTime = CFAbsoluteTimeGetCurrent()
try moduleSystem.initialize()
let initTime = CFAbsoluteTimeGetCurrent() - startTime
print("Module initialization took: \(initTime * 1000)ms")

// Profile individual modules
for moduleName in moduleSystem.moduleNames {
    let moduleStart = CFAbsoluteTimeGetCurrent()
    _ = moduleSystem.container(for: moduleName)
    let moduleTime = CFAbsoluteTimeGetCurrent() - moduleStart
    print("\(moduleName): \(moduleTime * 1000)ms")
}
```

## Advanced Topics

### Hot Module Swapping (Development)

```swift
#if DEBUG
class HotSwappableModuleSystem: ModuleSystem {
    func swapModule(_ old: ModuleProtocol.Type, with new: ModuleProtocol.Type) {
        // Implementation for development hot-swapping
    }
}
#endif
```

### Module Versioning

```swift
protocol VersionedModule: ModuleProtocol {
    static var version: String { get }
    static var minimumDependencyVersions: [String: String] { get }
}
```

### Cross-Platform Modules

```swift
@Module(name: "Network")
struct NetworkModule {
    static func configure(_ container: Container) {
        #if os(iOS)
        container.register(NetworkService.self) { _ in
            IOSNetworkService()
        }
        #elseif os(macOS)
        container.register(NetworkService.self) { _ in
            MacOSNetworkService()
        }
        #endif
    }
}
```

## Conclusion

The SwinjectMacros Module System provides a robust foundation for building scalable, maintainable Swift applications. By following this guide and best practices, you can successfully migrate existing projects and build new ones with proper modular architecture.

For more examples and updates, visit the [GitHub repository](https://github.com/brunogama/SwinjectMacros).
