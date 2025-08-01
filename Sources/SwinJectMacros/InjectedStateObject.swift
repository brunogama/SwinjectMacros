// InjectedStateObject.swift - SwiftUI StateObject dependency injection macro declarations

import Foundation
import SwiftUI
import Swinject

// MARK: - @InjectedStateObject Macro

/// Automatically generates SwiftUI StateObject dependency injection with proper lifecycle management.
///
/// This macro transforms properties into SwiftUI StateObjects that are resolved from the dependency injection
/// container while maintaining proper SwiftUI lifecycle semantics and ObservableObject integration.
///
/// ## Basic Usage
///
/// ```swift
/// struct ContentView: View {
///     @InjectedStateObject var viewModel: UserViewModel
///     @InjectedStateObject var settings: AppSettings
///     
///     var body: some View {
///         VStack {
///             Text("Welcome \(viewModel.currentUser?.name ?? "Guest")")
///             Toggle("Dark Mode", isOn: $settings.isDarkMode)
///         }
///         .onAppear {
///             viewModel.loadCurrentUser()
///         }
///     }
/// }
/// ```
///
/// ## Named Dependencies
///
/// ```swift
/// struct DashboardView: View {
///     @InjectedStateObject("main") var viewModel: DashboardViewModel
///     @InjectedStateObject("analytics") var tracker: AnalyticsTracker
///     
///     var body: some View {
///         ScrollView {
///             ForEach(viewModel.dashboardItems) { item in
///                 DashboardItemView(item: item)
///                     .onTapGesture {
///                         tracker.trackInteraction(item.id)
///                     }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Custom Container Integration
///
/// ```swift
/// struct ProfileView: View {
///     @InjectedStateObject(container: "userSession") var profile: UserProfile
///     @InjectedStateObject(resolver: "customResolver") var preferences: UserPreferences
///     
///     var body: some View {
///         Form {
///             Section("Profile") {
///                 TextField("Name", text: $profile.displayName)
///                 TextField("Email", text: $profile.email)
///             }
///             Section("Preferences") {
///                 Toggle("Notifications", isOn: $preferences.notificationsEnabled)
///                 Picker("Theme", selection: $preferences.theme) {
///                     Text("Light").tag(Theme.light)
///                     Text("Dark").tag(Theme.dark)
///                     Text("Auto").tag(Theme.auto)
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **StateObject Property Wrapper**: Proper @StateObject wrapper with container resolution
/// 2. **Lifecycle Management**: Automatic ObservableObject lifecycle handling
/// 3. **Container Integration**: Seamless Swinject container resolution
/// 4. **Type Safety**: Compile-time validation of ObservableObject conformance
/// 5. **SwiftUI Integration**: Native SwiftUI preview and testing support
///
/// ## Requirements
///
/// - The injected type must conform to `ObservableObject`
/// - The dependency must be registered in the container before view creation
/// - Works with SwiftUI previews when preview container is configured
///
/// ## Performance Characteristics
///
/// - **Lazy Resolution**: Dependencies resolved only when StateObject is created
/// - **Single Instance**: StateObject lifecycle ensures single instance per view lifecycle
/// - **Memory Efficient**: Automatic cleanup when view is deallocated
/// - **SwiftUI Optimized**: Native SwiftUI observation and update patterns
///
/// ## SwiftUI Preview Support
///
/// ```swift
/// struct ContentView_Previews: PreviewProvider {
///     static var previews: some View {
///         ContentView()
///             .environmentObject(PreviewContainer.shared.resolve(UserViewModel.self)!)
///     }
/// }
/// ```
@attached(accessor)
public macro InjectedStateObject(
    _ name: String? = nil,
    container: String? = nil,
    resolver: String = "resolver"
) = #externalMacro(module: "SwinJectMacrosImplementation", type: "InjectedStateObjectMacro")

// MARK: - SwiftUI Integration Support Types

/// Configuration for SwiftUI StateObject injection
public struct InjectedStateObjectConfiguration {
    public let name: String?
    public let containerName: String?
    public let resolverName: String
    public let requiresObservableObject: Bool
    
    public init(
        name: String? = nil,
        containerName: String? = nil,
        resolverName: String = "resolver",
        requiresObservableObject: Bool = true
    ) {
        self.name = name
        self.containerName = containerName
        self.resolverName = resolverName
        self.requiresObservableObject = requiresObservableObject
    }
}

/// SwiftUI integration errors
public enum SwiftUIInjectionError: Error, LocalizedError {
    case notObservableObject(String)
    case containerNotFound(String)
    case dependencyNotRegistered(String, String?)
    case previewConfigurationMissing(String)
    
    public var errorDescription: String? {
        switch self {
        case .notObservableObject(let type):
            return "Type '\(type)' must conform to ObservableObject for @InjectedStateObject"
        case .containerNotFound(let name):
            return "Container '\(name)' not found for SwiftUI injection"
        case .dependencyNotRegistered(let type, let name):
            let nameStr = name.map { " with name '\($0)'" } ?? ""
            return "Dependency '\(type)'\(nameStr) not registered in container"
        case .previewConfigurationMissing(let type):
            return "SwiftUI preview configuration missing for '\(type)' - configure preview container"
        }
    }
}

/// Protocol for SwiftUI preview container configuration
public protocol SwiftUIPreviewContainer {
    /// Configure preview container with test dependencies
    static func configurePreviewDependencies()
    
    /// Get preview-specific container instance
    static var previewContainer: Container { get }
}

/// Default preview container implementation
public class DefaultPreviewContainer: SwiftUIPreviewContainer {
    public static let shared = DefaultPreviewContainer()
    private let container = Container()
    
    private init() {
        Self.configurePreviewDependencies()
    }
    
    public static func configurePreviewDependencies() {
        // Override in subclasses to register preview-specific dependencies
    }
    
    public static var previewContainer: Container {
        return shared.container
    }
}

// MARK: - Container Extensions for SwiftUI

public extension Container {
    
    /// Register an ObservableObject for SwiftUI StateObject injection
    func registerStateObject<T: ObservableObject>(
        _ serviceType: T.Type,
        name: String? = nil,
        factory: @escaping (Resolver) -> T
    ) {
        let registration = register(serviceType, name: name, factory: factory)
        registration.inObjectScope(.container) // Ensure singleton for StateObject
    }
    
    /// Resolve a StateObject dependency for SwiftUI views
    func resolveStateObject<T: ObservableObject>(
        _ serviceType: T.Type,
        name: String? = nil
    ) -> T? {
        return resolve(serviceType, name: name)
    }
    
    /// Check if a StateObject dependency is available
    func hasStateObjectDependency<T: ObservableObject>(
        _ serviceType: T.Type,
        name: String? = nil
    ) -> Bool {
        return resolve(serviceType, name: name) != nil
    }
}

// MARK: - SwiftUI Environment Integration

/// Environment key for dependency injection container (StateObject specific)
private struct StateObjectContainerKey: EnvironmentKey {
    static let defaultValue: Container? = nil
}

public extension EnvironmentValues {
    /// Access the dependency injection container for StateObject injection
    var stateObjectContainer: Container? {
        get { self[StateObjectContainerKey.self] }
        set { self[StateObjectContainerKey.self] = newValue }
    }
}

public extension View {
    /// Provide a dependency injection container for StateObject injection
    func stateObjectContainer(_ container: Container) -> some View {
        environment(\.stateObjectContainer, container)
    }
}

// MARK: - SwiftUI Preview Helpers

/// Helper for configuring SwiftUI previews with dependency injection
public struct PreviewDependencyConfiguration {
    
    /// Configure a preview container with common dependencies
    public static func configurePreview<T: ObservableObject>(
        _ container: Container,
        with dependencies: [String: T]
    ) {
        for (name, dependency) in dependencies {
            container.registerStateObject(T.self, name: name) { _ in dependency }
        }
    }
    
    /// Create a preview-configured view with dependencies
    public static func previewView<Content: View>(
        @ViewBuilder content: @escaping () -> Content,
        dependencies: (Container) -> Void
    ) -> some View {
        let container = Container()
        dependencies(container)
        return content()
            .stateObjectContainer(container)
    }
}