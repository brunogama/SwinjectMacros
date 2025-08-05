# Module Lifecycle Management

Comprehensive lifecycle management for modules with 12 states, hooks, and monitoring.

## Overview

The Module Lifecycle Management system provides fine-grained control over module states, from initialization through destruction. It includes a sophisticated state machine, lifecycle hooks for monitoring and intervention, and comprehensive metrics tracking.

## Lifecycle States

Modules progress through a comprehensive 12-state lifecycle:

```
uninitialized → initializing → initialized → starting → active
                                              ↓
                                           pausing
                                              ↓
                                           paused
                                              ↓
                                          resuming
                                              ↓
                                           active → stopping → stopped → destroyed
                                              ↓
                                           failed
```

### State Descriptions

| State           | Description                       | Valid Transitions               |
| --------------- | --------------------------------- | ------------------------------- |
| `uninitialized` | Module not yet initialized        | `initializing`                  |
| `initializing`  | Module initialization in progress | `initialized`, `failed`         |
| `initialized`   | Module ready but not started      | `starting`, `destroyed`         |
| `starting`      | Module startup in progress        | `active`, `failed`              |
| `active`        | Module running normally           | `pausing`, `stopping`, `failed` |
| `pausing`       | Module being paused               | `paused`, `failed`              |
| `paused`        | Module temporarily suspended      | `resuming`, `stopping`          |
| `resuming`      | Module resuming from pause        | `active`, `failed`              |
| `stopping`      | Module shutdown in progress       | `stopped`, `failed`             |
| `stopped`       | Module cleanly stopped            | `destroyed`, `starting`         |
| `failed`        | Module encountered error          | `starting`, `destroyed`         |
| `destroyed`     | Module resources cleaned up       | (terminal state)                |

## Basic Usage

### ModuleLifecycleManager

The central coordinator for all lifecycle operations:

```swift
import SwinjectMacros

let lifecycleManager = ModuleLifecycleManager.shared

// Initialize a module
let result = await lifecycleManager.initializeModule("UserModule")
switch result {
case .success:
    print("Module initialized successfully")
case .failure(let error):
    print("Initialization failed: \(error)")
case .blocked(let reason):
    print("Initialization blocked: \(reason)")
case .timeout:
    print("Initialization timed out")
}

// Start the module
await lifecycleManager.startModule("UserModule")

// Pause and resume
await lifecycleManager.pauseModule("UserModule")
await lifecycleManager.resumeModule("UserModule")

// Stop and destroy
await lifecycleManager.stopModule("UserModule")
await lifecycleManager.destroyModule("UserModule")
```

### Lifecycle Information

Get detailed information about module lifecycle:

```swift
// Get current lifecycle info
if let info = await lifecycleManager.getLifecycleInfo(for: "UserModule") {
    print("Current state: \(info.currentState)")
    print("Total uptime: \(info.totalUptime) seconds")
    print("Failure count: \(info.failureCount)")
    print("Last transition: \(info.lastTransitionTime)")
}

// Query modules by state
let activeModules = await lifecycleManager.getModules(in: .active)
let failedModules = await lifecycleManager.getModules(in: .failed)

// Check if transition is valid
let canStart = await lifecycleManager.canTransition(
    moduleId: "UserModule",
    to: .starting
)
```

## Lifecycle Hooks

Lifecycle hooks allow you to monitor and respond to state transitions:

### Built-in Hooks

#### LoggingLifecycleHook

Provides structured logging of lifecycle events:

```swift
let loggingHook = LoggingLifecycleHook()
await lifecycleManager.registerHook(loggingHook)

// Logs output like:
// 🚀 [UserModule] Transitioning: uninitialized → initializing
// ✅ [UserModule] Transition completed: initialized (0.045s)
```

#### PerformanceLifecycleHook

Tracks performance metrics for lifecycle transitions:

```swift
let performanceHook = PerformanceLifecycleHook()
await lifecycleManager.registerHook(performanceHook)

// Automatically tracks:
// - Transition times
// - Success rates
// - Performance trends
```

### Custom Lifecycle Hooks

Create custom hooks by implementing `ModuleLifecycleHook`:

```swift
class CustomLifecycleHook: ModuleLifecycleHook {
    func onLifecycleEvent(_ event: ModuleLifecycleEvent, module: String) async throws {
        switch event {
        case .willInitialize:
            print("🔄 Preparing to initialize \(module)")
            // Perform pre-initialization setup

        case .didInitialize:
            print("✅ \(module) initialized successfully")
            // Post-initialization tasks

        case .willStart:
            print("🚀 Starting \(module)")
            // Pre-startup validation

        case .didStart:
            print("🟢 \(module) is now active")
            // Post-startup notifications

        case .willStop:
            print("⏸️ Stopping \(module)")
            // Pre-shutdown cleanup

        case .didStop:
            print("🔴 \(module) stopped")
            // Post-shutdown tasks

        case .didFail(let error):
            print("❌ \(module) failed: \(error)")
            // Error handling and recovery
        }
    }
}

// Register the hook
await lifecycleManager.registerHook(CustomLifecycleHook())
```

### Lifecycle Events

Available lifecycle events:

```swift
public enum ModuleLifecycleEvent {
    case willInitialize
    case didInitialize
    case willStart
    case didStart
    case willPause
    case didPause
    case willResume
    case didResume
    case willStop
    case didStop
    case willDestroy
    case didDestroy
    case didFail(Error)
}
```

## Advanced Features

### Failure Handling

Handle module failures gracefully:

```swift
// Mark a module as failed
await lifecycleManager.markModuleFailed("UserModule", error: MyError.networkTimeout)

// Get failure information
if let info = await lifecycleManager.getLifecycleInfo(for: "UserModule"),
   info.currentState == .failed {
    print("Module failed \(info.failureCount) times")
    print("Last failure: \(info.lastFailureReason)")
}

// Attempt recovery
let recoveryResult = await lifecycleManager.startModule("UserModule")
```

### Metrics and Monitoring

Track detailed lifecycle metrics:

```swift
// Uptime tracking
if let info = await lifecycleManager.getLifecycleInfo(for: "UserModule") {
    print("Module uptime: \(info.totalUptime) seconds")
    print("Active sessions: \(info.activeSessionCount)")
    print("Average session duration: \(info.averageSessionDuration)")
}

// Performance metrics
let transitionTimes = await lifecycleManager.getTransitionMetrics(for: "UserModule")
print("Average initialization time: \(transitionTimes.averageInitTime)")
print("Average startup time: \(transitionTimes.averageStartTime)")
```

### Lifecycle Validation

Ensure modules meet requirements before transitions:

```swift
class ValidationLifecycleHook: ModuleLifecycleHook {
    func onLifecycleEvent(_ event: ModuleLifecycleEvent, module: String) async throws {
        switch event {
        case .willStart:
            // Validate prerequisites
            guard await validatePrerequisites(for: module) else {
                throw LifecycleError.prerequisitesNotMet(module)
            }

        case .willInitialize:
            // Check resource availability
            guard await checkResourceAvailability(for: module) else {
                throw LifecycleError.insufficientResources(module)
            }

        default:
            break
        }
    }

    private func validatePrerequisites(for module: String) async -> Bool {
        // Custom validation logic
        return true
    }

    private func checkResourceAvailability(for module: String) async -> Bool {
        // Resource checking logic
        return true
    }
}
```

## Real-World Example

Here's a comprehensive example showing lifecycle management in action:

```swift
import SwinjectMacros

class AppModuleManager {
    private let lifecycleManager = ModuleLifecycleManager.shared

    func setupApplication() async throws {
        // Register comprehensive lifecycle hooks
        await lifecycleManager.registerHook(LoggingLifecycleHook())
        await lifecycleManager.registerHook(PerformanceLifecycleHook())
        await lifecycleManager.registerHook(ValidationLifecycleHook())
        await lifecycleManager.registerHook(NotificationLifecycleHook())

        // Initialize modules in dependency order
        let moduleOrder = ["CoreModule", "NetworkModule", "DatabaseModule", "UserModule"]

        for moduleId in moduleOrder {
            do {
                let result = await lifecycleManager.initializeModule(moduleId)

                switch result {
                case .success:
                    print("✅ \(moduleId) initialized")

                case .failure(let error):
                    print("❌ Failed to initialize \(moduleId): \(error)")
                    throw AppError.moduleInitializationFailed(moduleId, error)

                case .blocked(let reason):
                    print("⚠️ \(moduleId) initialization blocked: \(reason)")
                    // Attempt to resolve blocking condition
                    try await resolveBlockingCondition(moduleId, reason)

                case .timeout:
                    print("⏱️ \(moduleId) initialization timed out")
                    throw AppError.moduleTimeout(moduleId)
                }
            } catch {
                // Cleanup any partially initialized modules
                await cleanupModules(moduleOrder)
                throw error
            }
        }

        // Start all modules
        try await startAllModules(moduleOrder)
    }

    private func startAllModules(_ moduleIds: [String]) async throws {
        for moduleId in moduleIds {
            let result = await lifecycleManager.startModule(moduleId)

            switch result {
            case .success:
                print("🚀 \(moduleId) started successfully")

            case .failure(let error):
                print("❌ Failed to start \(moduleId): \(error)")
                throw AppError.moduleStartupFailed(moduleId, error)

            default:
                throw AppError.unexpectedModuleState(moduleId)
            }
        }
    }

    private func cleanupModules(_ moduleIds: [String]) async {
        // Stop and destroy modules in reverse order
        for moduleId in moduleIds.reversed() {
            await lifecycleManager.stopModule(moduleId)
            await lifecycleManager.destroyModule(moduleId)
        }
    }
}

// Custom notification hook
class NotificationLifecycleHook: ModuleLifecycleHook {
    func onLifecycleEvent(_ event: ModuleLifecycleEvent, module: String) async throws {
        switch event {
        case .didStart:
            NotificationCenter.default.post(
                name: .moduleDidStart,
                object: module
            )

        case .didFail(let error):
            NotificationCenter.default.post(
                name: .moduleDidFail,
                object: module,
                userInfo: ["error": error]
            )

        default:
            break
        }
    }
}

extension Notification.Name {
    static let moduleDidStart = Notification.Name("moduleDidStart")
    static let moduleDidFail = Notification.Name("moduleDidFail")
}
```

## Error Handling

The lifecycle system provides comprehensive error handling:

```swift
enum LifecycleError: Error, LocalizedError {
    case invalidStateTransition(from: ModuleLifecycleState, to: ModuleLifecycleState)
    case moduleNotFound(String)
    case prerequisitesNotMet(String)
    case insufficientResources(String)
    case operationTimeout(String, TimeInterval)

    var errorDescription: String? {
        switch self {
        case .invalidStateTransition(let from, let to):
            return "Invalid state transition from \(from) to \(to)"
        case .moduleNotFound(let id):
            return "Module '\(id)' not found"
        case .prerequisitesNotMet(let id):
            return "Prerequisites not met for module '\(id)'"
        case .insufficientResources(let id):
            return "Insufficient resources to start module '\(id)'"
        case .operationTimeout(let id, let timeout):
            return "Operation timed out for module '\(id)' after \(timeout) seconds"
        }
    }
}
```

## Best Practices

1. **Always Register Hooks Early**: Register lifecycle hooks before any module operations
1. **Handle All Result Cases**: Always handle all cases of `LifecycleTransitionResult`
1. **Use Dependency Order**: Initialize modules in dependency order
1. **Implement Cleanup**: Always cleanup resources in failure scenarios
1. **Monitor Performance**: Use performance hooks to identify slow transitions
1. **Validate Prerequisites**: Check dependencies before state transitions
1. **Log Comprehensively**: Use logging hooks for debugging and monitoring

## Thread Safety

All lifecycle operations are thread-safe and use Swift's actor model:

```swift
// All operations are async and thread-safe
Task {
    await lifecycleManager.initializeModule("Module1")
}

Task {
    await lifecycleManager.startModule("Module2")
}

// No race conditions or synchronization needed
```

## See Also

- <doc:Module-System>
- <doc:Module-Hot-Swap>
- <doc:Module-Performance>
- <doc:Module-Debug-Tools>
