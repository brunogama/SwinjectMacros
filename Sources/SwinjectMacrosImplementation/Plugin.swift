// Plugin.swift - Compiler plugin registration for SwinjectMacros
// Copyright © 2025 SwinjectMacros. All rights reserved.

import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The main compiler plugin that provides all SwinjectMacros functionality
@main
struct SwinjectMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        // MARK: - Core Dependency Injection Macros
        InjectableMacro.self,
        AutoFactoryMacro.self,
        AutoFactory1Macro.self,
        AutoFactory2Macro.self,
        AutoFactoryMultiMacro.self,
        AutoRegisterMacro.self,

        // MARK: - AOP Macros
        InterceptorMacro.self,
        PerformanceTrackedMacro.self,
        RetryMacro.self,
        CircuitBreakerMacro.self,
        CacheMacro.self,
        DecoratorMacro.self,

        // MARK: - Lifecycle Management Macros
        LazyInjectMacro.self,
        WeakInjectMacro.self,
        AsyncInjectMacro.self,
        OptionalInjectMacro.self,
        ThreadSafeMacro.self,
        NamedMacro.self,
        ScopedServiceMacro.self,

        // MARK: - SwiftUI Integration Macros
        EnvironmentInjectMacro.self,
        ViewModelInjectMacro.self,
        InjectedStateObjectMacro.self,
        PublisherInjectMacro.self,

        // MARK: - Testing Macros
        TestContainerMacro.self,
        SpyMacro.self,
        MockResponseMacro.self,
        StubServiceMacro.self,

        // MARK: - Configuration Macros
        DebugContainerMacro.self,
        DependencyGraphMacro.self,
        ValidatedContainerMacro.self,
        DependencyGroupMacro.self,
        ServiceGroupMacro.self,

        // MARK: - Module System Macros
        ModuleMacro.self
    ]
}

// MARK: - Core Macro Implementations

/// All macro implementations are registered above.
/// Each macro implementation is located in its respective subdirectory:
/// - Core/: Core dependency injection and lifecycle macros
/// - AOP/: Aspect-oriented programming macros
/// - SwiftUI/: SwiftUI integration macros
/// - Testing/: Testing utility macros
/// - Configuration/: Configuration and debugging macros

// Import required modules
import SwiftSyntax
import SwiftSyntaxMacros
