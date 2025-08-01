// Plugin.swift - Compiler plugin registration for SwinjectUtilityMacros
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The main compiler plugin that provides all SwinjectUtilityMacros functionality
@main
struct SwinjectUtilityMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        // MARK: - Core Dependency Injection Macros
        InjectableMacro.self,
        AutoFactoryMacro.self,
        
        // MARK: - AOP Macros
        InterceptorMacro.self,
        PerformanceTrackedMacro.self,
        RetryMacro.self,
        CircuitBreakerMacro.self,
        CacheMacro.self,
        
        // MARK: - Lifecycle Management Macros
        LazyInjectMacro.self,
        WeakInjectMacro.self,
        
        // MARK: - Testing Macros
        TestContainerMacro.self
    ]
}

// MARK: - Core Macro Implementations

/// Core dependency injection macros that will be implemented first
/// These are the foundation macros that other macros may depend on

// Import required modules
import SwiftSyntax
import SwiftSyntaxMacros

// The actual InjectableMacro implementation is in Core/InjectableMacro.swift
// and is automatically included in this module

// AutoFactoryMacro implementation is in Core/AutoFactoryMacro.swift

// Empty macro implementations removed to prevent silent failures
// TODO: Implement AutoFactory1Macro when needed
// TODO: Implement AutoFactory2Macro when needed
// TODO: Implement AutoFactoryMultiMacro when needed
// TODO: Implement AutoRegisterMacro when needed

// AOP macros - InterceptorMacro implementation is in Core/InterceptorMacro.swift

// TODO: Implement DecoratorMacro when needed

// AOP macros - PerformanceTrackedMacro implementation is in Core/PerformanceTrackedMacro.swift

// AOP macros - RetryMacro implementation is in Core/RetryMacro.swift

// AOP macros - CircuitBreakerMacro implementation is in Core/CircuitBreakerMacro.swift

// AOP macros - CacheMacro implementation is in Core/CacheMacro.swift

// TODO: Implement ScopedServiceMacro when needed

// LazyInjectMacro implementation is in Core/LazyInjectMacro.swift

// WeakInjectMacro implementation is in Core/WeakInjectMacro.swift

// TODO: Implement OptionalInjectMacro when needed
// TODO: Implement AsyncInjectMacro when needed  
// TODO: Implement ThreadSafeMacro when needed
// TODO: Implement NamedMacro when needed

// TODO: Implement SwiftUI macros when needed
// TODO: Implement EnvironmentInjectMacro when needed
// TODO: Implement ViewModelInjectMacro when needed
// TODO: Implement InjectedStateObjectMacro when needed
// TODO: Implement PublisherInjectMacro when needed

// TestContainerMacro implementation is in Core/TestContainerMacro.swift

// TODO: Implement testing macros when needed
// TODO: Implement SpyMacro when needed
// TODO: Implement MockResponseMacro when needed
// TODO: Implement StubServiceMacro when needed

// TODO: Implement configuration macros when needed
// TODO: Implement FeatureToggleMacro when needed
// TODO: Implement ConfigurableServiceMacro when needed
// TODO: Implement ConditionalRegistrationMacro when needed

// TODO: Implement debugging macros when needed
// TODO: Implement DebugContainerMacro when needed
// TODO: Implement DependencyGraphMacro when needed
// TODO: Implement ValidatedContainerMacro when needed
// TODO: Implement RequiredDependenciesMacro when needed
// TODO: Implement CircularDependencyMacro when needed