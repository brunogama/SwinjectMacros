# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
- **Build project**: `swift build`
- **Run all tests**: `swift test`
- **Run specific test**: `swift test --filter <TestName>`
- **Build in release mode**: `swift build -c release`

### Package Management
- **Update dependencies**: `swift package update`
- **Generate Xcode project**: `swift package generate-xcodeproj`
- **Resolve package dependencies**: `swift package resolve`

### Testing Commands
- **Run macro tests**: `swift test --filter SwinjectUtilityMacrosTests`
- **Run integration tests**: `swift test --filter IntegrationTests`
- **Run performance benchmarks**: `swift test --filter PerformanceBenchmarkTests`
- **Run stress tests**: `swift test --filter StressTests`

## Project Architecture

### High-Level Structure
This is a Swift Package Manager project that implements a comprehensive dependency injection macro library built on top of Swinject. The project uses Swift Macros (Swift 5.9+) to generate boilerplate code at compile time.

### Core Components

#### Target Structure
- **SwinjectUtilityMacros**: Public API target containing macro declarations and protocols
- **SwinjectUtilityMacrosImplementation**: Macro implementation target with SwiftSyntax-based code generation
- **ServiceDiscoveryTool**: Build tool for automatic service discovery
- **SwinJectBuildPlugin**: Build plugin for integrating service discovery into build process

#### Macro Categories
1. **Core DI Macros**: `@Injectable`, `@AutoFactory`, `@TestContainer`
2. **AOP Macros**: `@Interceptor`, `@PerformanceTracked`, `@Retry`, `@CircuitBreaker`, `@Cache`
3. **Lifecycle Macros**: `@LazyInject`, `@WeakInject`
4. **Future Macros**: SwiftUI integration, configuration, and validation macros (see Plugin.swift TODOs)

#### Implementation Architecture
- **Core/**: Contains individual macro implementations (InjectableMacro.swift, AutoFactoryMacro.swift, etc.)
- **Utilities/**: Shared utilities for code generation, syntax analysis, and type resolution
- **AOP/**: Aspect-oriented programming utilities and interceptor framework
- **Testing/**: Test-specific macro implementations and utilities

### Key Design Patterns

#### Macro Implementation Pattern
Each macro follows a consistent structure:
- Implements appropriate SwiftSyntax macro protocols (MemberMacro, ExtensionMacro, etc.)
- Uses TypeAnalyzer for dependency analysis
- Uses CodeGenerator for generating Swinject registration code
- Handles error cases with descriptive diagnostics

#### Code Generation Strategy
- Analyzes initializer parameters to distinguish between injected dependencies and runtime parameters
- Generates static `register(in:)` methods for @Injectable services
- Generates factory protocols and implementations for @AutoFactory services
- Creates test container setup methods for @TestContainer

#### Testing Strategy
- Unit tests for individual macros using SwiftSyntaxMacrosTestSupport
- Integration tests with actual Swinject containers
- Edge case tests for complex scenarios
- Performance benchmarks for macro expansion times
- Stress tests for large dependency graphs

### Platform Support
- Minimum Swift version: 5.9 (required for macro support)
- Platforms: iOS 15.0+, macOS 12.0+, watchOS 8.0+, tvOS 15.0+
- Dependencies: SwiftSyntax 509.0.0+, Swinject 2.9.1+

### Development Guidelines

#### When Adding New Macros
1. Create implementation file in appropriate subdirectory of Core/
2. Add macro type to Plugin.swift providingMacros array
3. Add corresponding test file following naming convention
4. Update documentation in main target if public API changes

#### Code Style Conventions
- Use descriptive variable and function names
- Follow Swift API design guidelines
- Prefer explicit types over type inference in macro implementations
- Use SwiftSyntax factory methods for creating syntax nodes
- Include comprehensive error handling with diagnostic messages

#### Testing Requirements
- All new macros must have comprehensive unit tests
- Test both successful expansion and error cases
- Include integration tests with actual Swinject usage
- Performance tests for macros that may be used frequently

### Build Plugin Integration

The project includes a build plugin (SwinJectBuildPlugin) that uses ServiceDiscoveryTool to automatically discover services marked with macros and generate registration code. This enables automatic service discovery without manual registration calls.

### Future Development Roadmap

The Plugin.swift file contains extensive TODOs for planned macros including:
- Advanced SwiftUI integration macros
- Configuration and feature toggle macros  
- Enhanced debugging and validation macros
- Performance optimization macros

See Plugin.swift lines 14-58 for complete planned macro list.