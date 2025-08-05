# Module System

Advanced module system with lifecycle management, hot-swapping, performance optimization, and debugging tools.

## Overview

The SwinjectMacros Module System (introduced in v1.0.1) provides comprehensive module management capabilities that go beyond simple dependency injection. It includes lifecycle management, runtime module replacement, performance optimization, and advanced debugging tools.

## Core Components

### ModuleSystem

The central orchestrator for all module operations.

```swift
import SwinjectMacros

let moduleSystem = ModuleSystem.shared

// Register a module
try await moduleSystem.registerModule(
    id: "UserModule",
    dependencies: ["NetworkModule", "DatabaseModule"]
)

// Initialize and start module
try await moduleSystem.initializeModule("UserModule")
try await moduleSystem.startModule("UserModule")
```

### Module Declaration

Use the `@Module` macro to define modules:

```swift
@Module(
    id: "UserModule",
    dependencies: ["NetworkModule", "DatabaseModule"],
    priority: .high
)
public struct UserModule {
    @Injectable public var userService: UserService
    @Injectable public var userRepository: UserRepository

    public init() {}
}
```

### Module Scoping

The module system provides scoped dependency injection:

```swift
@ModuleScoped
class UserService {
    init(apiClient: APIClient) {
        // This instance is scoped to the module
    }
}

// Access module-scoped services
let userService = ModuleScope.current.resolve(UserService.self)
```

## Key Features

### 1. Lifecycle Management

Modules progress through a comprehensive 12-state lifecycle:

- `uninitialized` → `initializing` → `initialized`
- `starting` → `active` → `pausing`
- `paused` → `resuming` → `stopping`
- `stopped` → `failed` → `destroyed`

```swift
// Monitor lifecycle events
ModuleLifecycleManager.shared.registerHook(MyLifecycleHook())

class MyLifecycleHook: ModuleLifecycleHook {
    func onLifecycleEvent(_ event: ModuleLifecycleEvent, module: String) async throws {
        print("Module \(module) transitioned to \(event)")
    }
}
```

### 2. Hot-Swap Capabilities

Replace modules at runtime without stopping your application:

```swift
// Make a module hot-swappable
@HotSwappable
class NetworkModule: HotSwappableModule {
    let version = ModuleVersion(
        identifier: "NetworkModule",
        version: "2.0.0",
        compatibilityVersion: "2.0"
    )

    func prepareForSwap(context: HotSwapContext) async throws {
        // Prepare for module replacement
    }

    func validateCompatibility(with version: ModuleVersion) async -> HotSwapValidationResult {
        // Validate version compatibility
        return .valid
    }
}

// Perform hot-swap
let result = await ModuleHotSwapManager.shared.performHotSwap(
    moduleId: "NetworkModule",
    targetVersion: newVersion,
    initiatedBy: "admin"
)
```

### 3. Performance Optimization

Multiple optimization strategies for different scenarios:

```swift
// Configure performance optimization
let config = ModulePerformanceConfig(
    moduleId: "UserModule",
    strategy: .lazyLoading,
    priority: .high,
    maxMemoryUsage: 50 * 1024 * 1024, // 50MB limit
    enableCaching: true,
    cacheSize: 100
)

await ModulePerformanceOptimizer.shared.configureModule(config)
```

**Available Strategies:**
- `.lazyLoading` - Load modules on-demand
- `.preloading` - Pre-load critical dependencies
- `.memoryOptimized` - Minimize memory footprint
- `.startupOptimized` - Optimize for fast startup
- `.balanced` - Balance performance and memory

### 4. Debug and Visualization Tools

Comprehensive debugging capabilities with multiple visualization formats:

```swift
// Generate dependency graph
let mermaidGraph = await ModuleDebugTools.shared.generateDependencyGraph(
    for: "UserModule",
    format: .mermaid
)

// Execute debug commands
let result = await ModuleDebugTools.shared.executeCommand(
    DebugCommand(name: "inspect", parameters: ["UserModule"])
)

// Real-time monitoring
await ModuleDebugTools.shared.startRealTimeMonitoring()
```

**Visualization Formats:**
- `.mermaid` - Mermaid diagram format
- `.dot` - Graphviz DOT format
- `.html` - Interactive HTML visualization
- `.json` - Structured JSON data
- `.text` - Plain text representation

## Module Dependencies

### Dependency Declaration

```swift
@Module(
    id: "OrderModule",
    dependencies: ["UserModule", "PaymentModule", "InventoryModule"]
)
public struct OrderModule {
    // Module implementation
}
```

### Dependency Graph Analysis

```swift
// Analyze module dependencies
let graph = ModuleDependencyGraph()
await graph.analyzeDependencies(for: "OrderModule")

// Detect circular dependencies
let cycles = await graph.detectCycles()
if !cycles.isEmpty {
    print("Circular dependencies detected: \(cycles)")
}

// Get topological order
let loadOrder = await graph.getTopologicalOrder()
print("Module load order: \(loadOrder)")
```

## Real-World Example

Here's a complete example of a module system setup:

```swift
import SwinjectMacros

// Define modules
@Module(id: "CoreModule", priority: .critical)
public struct CoreModule {
    @Injectable public var logger: LoggerService
    @Injectable public var config: ConfigurationService
}

@Module(
    id: "NetworkModule",
    dependencies: ["CoreModule"],
    priority: .high
)
public struct NetworkModule {
    @Injectable public var apiClient: APIClient
    @Injectable public var networkReachability: NetworkReachability
}

@Module(
    id: "UserModule",
    dependencies: ["NetworkModule", "CoreModule"],
    priority: .normal
)
public struct UserModule {
    @Injectable public var userService: UserService
    @Injectable public var authService: AuthenticationService
}

// Application setup
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Task {
            // Initialize module system
            let moduleSystem = ModuleSystem.shared

            // Register modules
            try await moduleSystem.registerModule(CoreModule())
            try await moduleSystem.registerModule(NetworkModule())
            try await moduleSystem.registerModule(UserModule())

            // Configure performance optimization
            await ModulePerformanceOptimizer.shared.configureModule(
                ModulePerformanceConfig(
                    moduleId: "CoreModule",
                    strategy: .preloading,
                    priority: .critical
                )
            )

            // Enable debug monitoring in development
            #if DEBUG
            await ModuleDebugTools.shared.setDebugLevel(.verbose)
            await ModuleDebugTools.shared.startRealTimeMonitoring()
            #endif

            // Start all modules
            try await moduleSystem.startAllModules()
        }

        return true
    }
}
```

## Performance Considerations

### Memory Management

- Use `.memoryOptimized` strategy for memory-constrained environments
- Configure appropriate cache sizes based on available memory
- Monitor memory usage with debug tools

### Startup Performance

- Use `.startupOptimized` for critical modules
- Preload essential dependencies
- Defer loading of non-critical modules

### Runtime Performance

- Enable service resolution caching for frequently accessed services
- Use lazy loading for large, infrequently used modules
- Monitor performance with built-in metrics

## Best Practices

1. **Module Granularity**: Keep modules focused on specific business domains
2. **Dependency Management**: Minimize inter-module dependencies
3. **Lifecycle Hooks**: Use lifecycle hooks for cleanup and resource management
4. **Performance Monitoring**: Regularly analyze performance metrics
5. **Hot-Swap Planning**: Design modules with hot-swapping in mind from the start
6. **Debug Integration**: Integrate debug tools into development workflows

## See Also

- <doc:Module-Lifecycle>
- <doc:Module-Hot-Swap>
- <doc:Module-Performance>
- <doc:Module-Debug-Tools>
- <doc:Injectable>
