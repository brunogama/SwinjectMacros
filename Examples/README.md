# SwinjectMacros Examples

This directory contains comprehensive examples demonstrating the power and flexibility of SwinjectMacros.

## 📁 Example Projects

### 1. QuickStart Example
**Location:** `QuickStart/`

A simple command-line application that demonstrates the core features:
- Basic `@Injectable` usage with different scopes
- `@AutoFactory` for services with runtime parameters
- Dependency resolution and scoping verification
- Factory pattern implementation

**To run:**
```bash
cd QuickStart
swift build
# Note: Due to XCTest linkage issues, use Xcode to run this example
```

### 2. iOS SwiftUI Demo
**Location:** `iOS-SwiftUI-Demo/`

A complete iOS application demonstrating:
- Real-world SwiftUI integration
- Advanced macros like `@Retry`, `@PerformanceTracked`, `@CircuitBreaker`
- Service layer architecture
- Proper error handling and logging
- SwiftUI specific patterns with `@EnvironmentInject` and `@ViewModelInject`

**Features demonstrated:**
- User management service with retry logic
- Network service with performance tracking
- Database service with caching
- Authentication service with circuit breaker
- Theme management
- Navigation coordination

### 3. Module System Example
**Location:** `ModuleSystemExample.swift`

Demonstrates the advanced Module System (v1.0.1+ features):
- Module definition and registration
- Module lifecycle management (initialize, start, stop)
- Hot-swapping modules at runtime
- Module performance profiling and optimization
- Module debug tools and health monitoring
- Module-scoped services

**Key concepts:**
- Organizing services into logical modules
- Managing module dependencies
- Runtime module replacement
- Performance optimization
- Debug and monitoring capabilities

### 4. Playground Examples
**Location:** `SwinJectMacros-Playground.playground/`

Interactive playground with pages covering:
1. Introduction to SwinjectMacros
2. `@Injectable` macro deep dive
3. `@AutoFactory` patterns
4. `@TestContainer` for testing
5. AOP macros (`@Interceptor`, `@PerformanceTracked`, etc.)
6. Advanced patterns and best practices
7. Real-world application example

**To use:**
Open in Xcode and run each page interactively.

## 🚀 Getting Started

### Prerequisites
- Swift 5.9+
- Xcode 15.0+
- macOS 12.0+ / iOS 15.0+

### Running the Examples

1. **Clone the repository:**
   ```bash
   git clone https://github.com/brunogama/SwinjectMacros.git
   cd SwinjectMacros/Examples
   ```

2. **Choose an example to explore**

3. **Build and run:**
   - For Swift packages: `swift build` then `swift run`
   - For iOS apps: Open in Xcode and run
   - For playgrounds: Open in Xcode

## 📚 Key Concepts Demonstrated

### Dependency Injection Basics
- Service registration with `@Injectable`
- Automatic dependency resolution
- Object scoping (container, graph, transient, singleton)
- Protocol-based design

### Factory Pattern
- Using `@AutoFactory` for runtime parameters
- Separating injected dependencies from runtime data
- Factory protocol generation

### Testing Support
- `@TestContainer` for automatic mock setup
- Mock service generation
- Test isolation patterns

### Advanced Features
- Aspect-oriented programming with interceptors
- Performance monitoring and optimization
- Retry logic and circuit breakers
- Caching strategies
- Thread safety

### Module System
- Modular architecture design
- Module lifecycle management
- Runtime module replacement
- Performance profiling
- Debug and monitoring tools

## 💡 Best Practices

1. **Start with QuickStart** - Understand the basics
2. **Explore iOS Demo** - See real-world patterns
3. **Try the Playground** - Interactive learning
4. **Study Module System** - Advanced architecture

## 🤝 Contributing

Found an issue or want to add an example? Please:
1. Open an issue describing your example idea
2. Submit a PR with your example
3. Ensure examples are well-documented

## 📖 Additional Resources

- [Main README](../README.md)
- [API Documentation](../Documentation.docc/)
- [Migration Guide](../MIGRATION.md)
- [Getting Started Tutorial](GettingStarted.md)
