# `SwinjectMacros`

Advanced Dependency Injection Utilities for Swift using Compile-Time Macros

## Overview

SwinjectMacros brings the power of Swift Macros to dependency injection, dramatically reducing boilerplate code while maintaining type safety and performance. Built on top of the proven [Swinject](https://github.com/Swinject/Swinject) framework, it provides 25+ compile-time macros for modern Swift applications.

### Key Benefits

- **🔥 Zero Runtime Overhead**: All code generation happens at compile-time
- **🎯 Type Safety**: Full Swift type system integration with compile-time validation
- **📝 Dramatically Less Code**: Reduce dependency injection boilerplate by 80%+
- **🔍 Better Error Messages**: Clear, actionable compile-time diagnostics
- **⚡ Performance**: No reflection, no runtime lookups - pure Swift performance
- **🧪 Testing Made Easy**: Automatic mock generation and test container setup
- **🏗️ Factory Patterns**: Automatic factory generation for services with runtime parameters

### Requirements

- **Swift 5.9+** (Required for macro support)
- **iOS 15.0+** / **macOS 12.0+** / **watchOS 8.0+** / **tvOS 15.0+**
- **Xcode 15.0+**

## Topics

### Getting Started

- <doc:Quick-Start>

### Core Dependency Injection Macros

- `Injectable` - Automatic service registration
- `AutoFactory` - Factory protocol generation for runtime parameters
- `Named` - Named service registration with compile-time validation

### Testing Macros

- `TestContainer` - Automatic test container generation
- `Spy` - Test spy generation for behavior verification
- `MockResponse` - Mock response configuration
- `StubService` - Stub service generation

### Lifecycle Management Macros

- `LazyInject` - Lazy dependency resolution
- `WeakInject` - Weak reference injection
- `AsyncInject` - Asynchronous dependency resolution
- `OptionalInject` - Optional dependency with fallback support

### Aspect-Oriented Programming (AOP) Macros

- `Interceptor` - Method interception with hooks
- `PerformanceTracked` - Automatic performance monitoring
- `Retry` - Configurable retry logic
- `CircuitBreaker` - Circuit breaker pattern implementation
- `Cache` - Method result caching

### SwiftUI Integration Macros

- `EnvironmentInject` - SwiftUI environment-based injection
- `ViewModelInject` - ViewModel dependency injection
- `InjectedStateObject` - Injected state object wrapper
- `PublisherInject` - Combine publisher injection

### Advanced Feature Macros

- `ThreadSafe` - Thread-safe service wrapper
- `Decorator` - Service decorator pattern
- `ScopedService` - Custom scope service registration

### Configuration & Debug Macros

- `DebugContainer` - Debug container with diagnostics
- `DependencyGraph` - Dependency graph visualization
- `ValidatedContainer` - Container validation

### Module System

- <doc:Module-System>
- <doc:Module-Lifecycle>

### Core Protocols

- `Injectable` - Protocol for injectable services
- `ServiceFactory` - Base protocol for factory types
- `Interceptor` - Protocol for method interceptors
- `PerformanceTracker` - Protocol for performance tracking

### Core Types

- `SwinjectUtilityMacros` - Library configuration and constants
- `SwinJectError` - Error types for dependency injection
- `ObjectScope` - Service lifecycle scopes
- `DependencyInfo` - Runtime dependency metadata

### Container Extensions

- `Container/registerGeneratedServices()` - Register all generated services
- `Container/testContainer()` - Create test container

## See Also

- <doc:API-Reference>
