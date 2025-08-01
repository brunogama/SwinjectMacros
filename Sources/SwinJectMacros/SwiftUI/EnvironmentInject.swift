// EnvironmentInject.swift - SwiftUI Environment-based dependency injection

import Foundation
import SwiftUI
import Swinject

// MARK: - @EnvironmentInject Macro

/// Automatically injects dependencies from the SwiftUI Environment using Swinject Container.
///
/// This macro integrates Swinject dependency injection with SwiftUI's Environment system,
/// allowing seamless dependency access in SwiftUI Views without manual container lookups.
///
/// ## Basic Usage
///
/// ```swift
/// struct UserProfileView: View {
///     @EnvironmentInject var userService: UserServiceProtocol
///     @EnvironmentInject var analytics: AnalyticsProtocol
///     
///     var body: some View {
///         VStack {
///             Text("User: \(userService.currentUser.name)")
///             Button("Track Event") {
///                 analytics.track("profile_viewed")
///             }
///         }
///     }
/// }
/// ```
///
/// ## Environment Setup
///
/// Configure your app's root view with the DI container:
///
/// ```swift
/// @main
/// struct MyApp: App {
///     let container = Container()
///     
///     init() {
///         // Configure your services
///         container.register(UserServiceProtocol.self) { _ in UserService() }
///         container.register(AnalyticsProtocol.self) { _ in AnalyticsService() }
///     }
///     
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .environmentObject(DIContainer(container))
///         }
///     }
/// }
/// ```
///
/// ## Advanced Usage with Named Services
///
/// ```swift
/// struct NetworkingView: View {
///     @EnvironmentInject("primary") var primaryAPI: APIClientProtocol
///     @EnvironmentInject("fallback") var fallbackAPI: APIClientProtocol
///     @EnvironmentInject(required: false) var optionalService: OptionalServiceProtocol?
///     
///     var body: some View {
///         VStack {
///             AsyncButton("Fetch Data") {
///                 do {
///                     let data = try await primaryAPI.fetchData()
///                     // Handle data
///                 } catch {
///                     let fallbackData = try await fallbackAPI.fetchData()
///                     // Handle fallback data
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## Preview Support
///
/// Use mock containers in SwiftUI previews:
///
/// ```swift
/// struct UserProfileView_Previews: PreviewProvider {
///     static var previews: some View {
///         let mockContainer = Container()
///         mockContainer.register(UserServiceProtocol.self) { _ in 
///             MockUserService(user: User.preview)
///         }
///         
///         UserProfileView()
///             .environmentObject(DIContainer(mockContainer))
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Environment Property Wrapper**: Custom property wrapper that integrates with SwiftUI's Environment
/// 2. **Container Access**: Automatic container resolution from SwiftUI Environment
/// 3. **Type Safety**: Compile-time type checking with clear error messages
/// 4. **Optional Support**: Handles optional dependencies gracefully
/// 5. **Named Services**: Support for named service registration
/// 6. **Preview Support**: Works seamlessly with SwiftUI previews
///
/// ## SwiftUI Integration Benefits
///
/// The macro provides several advantages for SwiftUI applications:
///
/// ```swift
/// // Without macro - manual container access
/// struct ContentView: View {
///     @EnvironmentObject var diContainer: DIContainer
///     
///     var body: some View {
///         let userService = diContainer.resolve(UserServiceProtocol.self)!
///         let analytics = diContainer.resolve(AnalyticsProtocol.self)!
///         
///         VStack {
///             Text("User: \(userService.currentUser.name)")
///             Button("Track") { analytics.track("button_tapped") }
///         }
///     }
/// }
///
/// // With macro - clean and declarative
/// struct ContentView: View {
///     @EnvironmentInject var userService: UserServiceProtocol
///     @EnvironmentInject var analytics: AnalyticsProtocol
///     
///     var body: some View {
///         VStack {
///             Text("User: \(userService.currentUser.name)")
///             Button("Track") { analytics.track("button_tapped") }
///         }
///     }
/// }
/// ```
///
/// **Performance Benefits:**
/// - **Lazy Resolution**: Dependencies resolved only when accessed in view body
/// - **Environment Caching**: SwiftUI Environment caches resolved instances
/// - **View Composition**: Clean separation of concerns in view hierarchies
/// - **Memory Efficient**: No strong references held by property wrappers
///
/// ## Error Handling
///
/// The macro provides clear error messages for common issues:
///
/// ```swift
/// struct ProblematicView: View {
///     @EnvironmentInject var service: UnregisteredService  // Compilation warning
///     @EnvironmentInject var value: Int                    // Error: not a service type
///     
///     var body: some View {
///         Text("Content")
///     }
/// }
/// ```
///
/// ## Integration with Navigation
///
/// Works seamlessly with SwiftUI navigation patterns:
///
/// ```swift
/// struct NavigationRootView: View {
///     @EnvironmentInject var coordinator: NavigationCoordinator
///     
///     var body: some View {
///         NavigationStack(path: $coordinator.path) {
///             HomeView()
///                 .navigationDestination(for: Route.self) { route in
///                     coordinator.view(for: route)
///                 }
///         }
///     }
/// }
/// ```
///
/// ## Parameters:
/// - `name`: Optional service name for named registration lookup
/// - `required`: Whether the dependency is required (default: true)
/// - `container`: Environment key for custom container access
///
/// ## Requirements:
/// - Property must have an explicit type annotation
/// - Type should be registered in the Swinject container
/// - SwiftUI Environment must contain DIContainer instance (now optional and must be set by the app)
/// - iOS 15.0+, macOS 12.0+, watchOS 8.0+, tvOS 15.0+
///
/// ## Generated Behavior:
/// 1. **Property Wrapper**: Creates @EnvironmentInject property wrapper
/// 2. **Environment Access**: Accesses DIContainer from SwiftUI Environment
/// 3. **Service Resolution**: Resolves service from container on access
/// 4. **Error Handling**: Provides clear errors for missing services
/// 5. **Preview Support**: Works with mock containers in previews
///
/// ## Real-World Examples:
///
/// ```swift
/// // E-commerce App
/// struct ProductListView: View {
///     @EnvironmentInject var productService: ProductServiceProtocol
///     @EnvironmentInject var cartManager: CartManagerProtocol
///     @EnvironmentInject("wishlist") var wishlistService: WishlistServiceProtocol
///     
///     var body: some View {
///         List(productService.products) { product in
///             ProductRow(product: product) {
///                 cartManager.add(product)
///             }
///         }
///     }
/// }
/// 
/// // Social Media App
/// struct TimelineView: View {
///     @EnvironmentInject var postService: PostServiceProtocol
///     @EnvironmentInject var userManager: UserManagerProtocol
///     @EnvironmentInject var imageCache: ImageCacheProtocol
///     
///     var body: some View {
///         LazyVStack {
///             ForEach(postService.timeline) { post in
///                 PostView(post: post, user: userManager.user(for: post.userId))
///                     .environment(\.imageCache, imageCache)
///             }
///         }
///     }
/// }
/// 
/// // Settings App
/// struct SettingsView: View {
///     @EnvironmentInject var settings: SettingsManagerProtocol
///     @EnvironmentInject var sync: SyncServiceProtocol
///     @EnvironmentInject(required: false) var analytics: AnalyticsProtocol?
///     
///     var body: some View {
///         Form {
///             Toggle("Dark Mode", isOn: $settings.isDarkMode)
///             Toggle("Sync Enabled", isOn: $settings.syncEnabled)
///             
///             if settings.syncEnabled {
///                 Button("Sync Now") {
///                     Task { await sync.performSync() }
///                     analytics?.track("manual_sync")
///                 }
///             }
///         }
///     }
/// }
/// ```
@attached(accessor)
public macro EnvironmentInject(
    _ name: String? = nil,
    required: Bool = true,
    container: PartialKeyPath<EnvironmentValues> = \.diContainer
) = #externalMacro(module: "SwinJectMacrosImplementation", type: "EnvironmentInjectMacro")

// MARK: - SwiftUI Environment Integration

/// Environment key for accessing the DI container in SwiftUI views
public struct DIContainerKey: EnvironmentKey {
    public static let defaultValue: DIContainer? = nil
}

extension EnvironmentValues {
    /// The dependency injection container for SwiftUI views (optional)
    public var diContainer: DIContainer? {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }

    /// Runtime-failing accessor for DIContainer
    public var requireDIContainer: DIContainer {
        guard let container = diContainer else {
            fatalError("DIContainer not found in SwiftUI Environment. Make sure to add .environmentObject(DIContainer(container)) or .diContainer(...) to your view hierarchy.")
        }
        return container
    }
}

/// Wrapper for Swinject Container to work with SwiftUI Environment
@MainActor
public class DIContainer: ObservableObject {
    private let container: Container
    
    public init(_ container: Container) {
        self.container = container
    }
    
    /// Resolve a service from the container
    public func resolve<Service>(_ serviceType: Service.Type, name: String? = nil) -> Service? {
        if let name = name {
            return container.synchronize().resolve(serviceType, name: name)
        } else {
            return container.synchronize().resolve(serviceType)
        }
    }
    
    /// Register a service in the container
    public func register<Service>(_ serviceType: Service.Type, name: String? = nil, factory: @escaping (Resolver) -> Service) {
        if let name = name {
            container.register(serviceType, name: name, factory: factory)
        } else {
            container.register(serviceType, factory: factory)
        }
    }
}

// MARK: - Environment Injection Errors

/// Errors that can occur during environment-based dependency injection
public enum EnvironmentInjectError: Error, LocalizedError {
    case containerNotFound
    case serviceNotRegistered(serviceName: String?, type: String)
    case requiredServiceMissing(type: String)
    case environmentNotConfigured
    
    public var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "DIContainer not found in SwiftUI Environment. Make sure to add .environmentObject(DIContainer(container)) to your view hierarchy."
        case .serviceNotRegistered(let serviceName, let type):
            let service = serviceName.map { " named '\($0)'" } ?? ""
            return "Service\(service) of type '\(type)' is not registered in the DI container."
        case .requiredServiceMissing(let type):
            return "Required service of type '\(type)' could not be resolved from the environment."
        case .environmentNotConfigured:
            return "SwiftUI Environment is not properly configured for dependency injection. Check your app setup."
        }
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Configure the DI container for the view hierarchy
    public func diContainer(_ container: Container) -> some View {
        self.environmentObject(DIContainer(container))
    }
    
    /// Configure the DI container with a DIContainer instance
    public func diContainer(_ diContainer: DIContainer) -> some View {
        self.environmentObject(diContainer)
    }
}

// MARK: - Preview Utilities

/// Utilities for creating mock containers in SwiftUI previews
public struct PreviewContainer {
    /// Create a container with mock services for previews
    public static func mock() -> Container {
        let container = Container()
        
        // Register common mock services
        // Users can extend this or create their own mock containers
        
        return container
    }
    
    /// Create a container with specific mock registrations
    public static func mock(configure: (Container) -> Void) -> Container {
        let container = Container()
        configure(container)
        return container
    }
}

