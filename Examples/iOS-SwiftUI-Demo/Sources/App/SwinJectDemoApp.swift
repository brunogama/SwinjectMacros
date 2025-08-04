// SwinJectDemoApp.swift - Main application demonstrating SwinJectMacros capabilities
// Copyright © 2025 SwinJectMacros Demo. All rights reserved.

import SwiftUI
import Swinject
import SwinjectUtilityMacros

@main
struct SwinJectDemoApp: App {

    // MARK: - Container Setup

    /// Main dependency injection container with debugging enabled
    @DebugContainer(
        logLevel: .verbose,
        trackResolutions: true,
        detectCircularDeps: true,
        performanceTracking: true,
        realTimeMonitoring: true
    )
    static let container = Container()

    // MARK: - App Lifecycle

    var body: some Scene {
        WindowGroup {
            ContentView()
                .stateObjectContainer(Self.container)
                .onAppear {
                    setupDependencyInjection()
                    logContainerSetup()
                }
        }
    }

    // MARK: - Dependency Setup

    private func setupDependencyInjection() {
        // Register all services using macro-generated methods
        ServiceConfiguration.registerAllServices(in: Self.container)

        // Enable debug mode
        Self.container.enableDebugMode()

        // Configure performance tracking
        if let debugContainer = Self.container as? DebuggableContainer {
            _ = debugContainer.performHealthCheck()
        }
    }

    private func logContainerSetup() {
        print("🚀 SwinJectMacros Demo App Starting")
        print("📊 Container registrations: \(Self.container.getRegistrationStats().count)")

        #if DEBUG
            // Export dependency graph for visualization
            do {
                try Self.container.exportDependencyGraph(to: "DemoApp_Dependencies.dot")
                print("📈 Dependency graph exported to DemoApp_Dependencies.dot")
            } catch {
                print("⚠️ Failed to export dependency graph: \(error)")
            }
        #endif
    }
}

// MARK: - Service Configuration

/// Central service registration using @Injectable and other macros
@DependencyGraph(
    format: .graphviz,
    includeOptional: true,
    detectCycles: true,
    exportPath: "dependency_graph.dot"
)
class ServiceConfiguration {

    /// Register all application services
    static func registerAllServices(in container: Container) {

        // MARK: - Core Services

        // Network service with performance tracking
        NetworkService.register(in: container)

        // Database service with scoped lifecycle
        DatabaseService.register(in: container)

        // Authentication service with caching
        AuthenticationService.register(in: container)

        // User service with retry logic
        UserService.register(in: container)

        // Analytics service with circuit breaker
        AnalyticsService.register(in: container)

        // MARK: - UI Services

        // Theme service for UI configuration
        ThemeService.register(in: container)

        // Navigation coordinator
        NavigationCoordinator.register(in: container)

        // MARK: - ViewModels

        // Main content view model
        ContentViewModel.register(in: container)

        // User profile view model
        UserProfileViewModel.register(in: container)

        // Settings view model
        SettingsViewModel.register(in: container)

        print("✅ All services registered successfully")
    }
}

// MARK: - Container Extensions

extension Container {

    /// Shared container for the demo app
    static var demoApp: Container {
        SwinJectDemoApp.container
    }
}
