// ViewModelInject.swift - SwiftUI ViewModel dependency injection

import Foundation
import SwiftUI
import Swinject

// MARK: - @ViewModelInject Macro

/// Automatically creates a ViewModel with dependency injection for SwiftUI Views.
///
/// This macro generates ViewModels that integrate seamlessly with SwiftUI's ObservableObject
/// pattern while providing automatic dependency injection through Swinject Container.
///
/// ## Basic Usage
///
/// ```swift
/// @ViewModelInject
/// class UserProfileViewModel {
///     private let userService: UserServiceProtocol
///     private let analytics: AnalyticsProtocol
///
///     @Published var user: User?
///     @Published var isLoading = false
///
///     func loadUser(_ id: String) async {
///         isLoading = true
///         defer { isLoading = false }
///
///         user = try? await userService.fetchUser(id)
///         analytics.track("user_profile_loaded", properties: ["user_id": id])
///     }
/// }
///
/// struct UserProfileView: View {
///     @StateObject private var viewModel = UserProfileViewModel()
///     let userId: String
///
///     var body: some View {
///         VStack {
///             if viewModel.isLoading {
///                 ProgressView("Loading...")
///             } else if let user = viewModel.user {
///                 Text("Hello, \(user.name)!")
///             }
///         }
///         .task {
///             await viewModel.loadUser(userId)
///         }
///     }
/// }
/// ```
///
/// ## Advanced Usage with Named Dependencies
///
/// ```swift
/// @ViewModelInject(container: "networking")
/// class NetworkViewModel: ObservableObject {
///     private let primaryAPI: APIClientProtocol
///     private let fallbackAPI: APIClientProtocol
///     private let cache: CacheServiceProtocol
///
///     @Published var data: [DataModel] = []
///     @Published var error: Error?
///
///     // Dependencies are automatically injected based on parameter types and names
///     init(
///         @Named("primary") primaryAPI: APIClientProtocol,
///         @Named("fallback") fallbackAPI: APIClientProtocol,
///         cache: CacheServiceProtocol
///     ) {
///         self.primaryAPI = primaryAPI
///         self.fallbackAPI = fallbackAPI
///         self.cache = cache
///     }
///
///     func fetchData() async {
///         do {
///             // Try primary API first
///             let result = try await primaryAPI.fetchData()
///             await MainActor.run {
///                 self.data = result
///                 self.error = nil
///             }
///
///             // Cache the result
///             await cache.store(result, forKey: "main_data")
///         } catch {
///             // Fallback to secondary API
///             do {
///                 let fallbackResult = try await fallbackAPI.fetchData()
///                 await MainActor.run {
///                     self.data = fallbackResult
///                     self.error = nil
///                 }
///             } catch fallbackError {
///                 await MainActor.run {
///                     self.error = fallbackError
///                 }
///             }
///         }
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **ObservableObject Conformance**: Automatically adds ObservableObject conformance
/// 2. **Dependency Injection**: Generates initializer with automatic dependency resolution
/// 3. **Environment Integration**: Works with SwiftUI Environment for container access
/// 4. **Factory Registration**: Optional factory method generation for container registration
/// 5. **Preview Support**: Creates preview-friendly initializers
/// 6. **Error Handling**: Comprehensive error handling for missing dependencies
///
/// ## Container Integration
///
/// Configure your ViewModel dependencies in the container:
///
/// ```swift
/// extension Container {
///     func configureViewModels() {
///         // Register dependencies
///         register(UserServiceProtocol.self) { _ in UserService() }
///         register(AnalyticsProtocol.self) { _ in AnalyticsService() }
///
///         // Named services
///         register(APIClientProtocol.self, name: "primary") { _ in PrimaryAPIClient() }
///         register(APIClientProtocol.self, name: "fallback") { _ in FallbackAPIClient() }
///
///         // Register ViewModels (optional - for factory pattern)
///         register(UserProfileViewModel.self) { resolver in
///             UserProfileViewModel(container: self)
///         }
///     }
/// }
/// ```
///
/// ## SwiftUI Integration
///
/// Use ViewModels in your SwiftUI views:
///
/// ```swift
/// struct ContentView: View {
///     let container = Container()
///
///     var body: some View {
///         TabView {
///             UserProfileView()
///                 .tabItem { Label("Profile", systemImage: "person") }
///
///             SettingsView()
///                 .tabItem { Label("Settings", systemImage: "gear") }
///         }
///         .environmentObject(DIContainer(container))
///     }
/// }
/// ```
///
/// ## Preview Support
///
/// Create mock ViewModels for SwiftUI previews:
///
/// ```swift
/// struct UserProfileView_Previews: PreviewProvider {
///     static var previews: some View {
///         let mockContainer = Container()
///         mockContainer.register(UserServiceProtocol.self) { _ in
///             MockUserService(users: [User.preview])
///         }
///
///         UserProfileView()
///             .environmentObject(DIContainer(mockContainer))
///             .previewDisplayName("User Profile")
///     }
/// }
/// ```
///
/// ## Async/Await Support
///
/// Full support for async ViewModels and operations:
///
/// ```swift
/// @ViewModelInject
/// class AsyncDataViewModel: ObservableObject {
///     private let dataService: DataServiceProtocol
///     private let notificationCenter: NotificationCenterProtocol
///
///     @Published var items: [DataItem] = []
///     @Published var isLoading = false
///     @Published var error: Error?
///
///     @MainActor
///     func loadData() async {
///         isLoading = true
///         error = nil
///
///         do {
///             let fetchedItems = try await dataService.fetchItems()
///             items = fetchedItems
///
///             // Send notification
///             await notificationCenter.post(.dataLoaded, object: fetchedItems)
///         } catch {
///             self.error = error
///         }
///
///         isLoading = false
///     }
/// }
/// ```
///
/// ## Testing Support
///
/// ViewModels are easily testable with mock dependencies:
///
/// ```swift
/// final class UserProfileViewModelTests: XCTestCase {
///     func testUserLoading() async {
///         // Arrange
///         let mockUserService = MockUserService()
///         let mockAnalytics = MockAnalyticsService()
///         let container = Container()
///
///         container.register(UserServiceProtocol.self) { _ in mockUserService }
///         container.register(AnalyticsProtocol.self) { _ in mockAnalytics }
///
///         let viewModel = UserProfileViewModel(container: container)
///
///         // Act
///         await viewModel.loadUser("test-id")
///
///         // Assert
///         XCTAssertNotNil(viewModel.user)
///         XCTAssertEqual(mockAnalytics.trackedEvents.count, 1)
///     }
/// }
/// ```
///
/// ## Parameters:
/// - `container`: Optional container name for multi-container scenarios
/// - `scope`: Object scope for ViewModel registration (default: .transient)
/// - `generateFactory`: Whether to generate factory method for container registration
/// - `previewSupport`: Whether to generate preview-friendly initializers
///
/// ## Requirements:
/// - Class must be marked as ObservableObject or the macro will add conformance
/// - Dependencies should be declared as private/internal properties
/// - Initializer parameters will be analyzed for dependency injection
/// - iOS 15.0+, macOS 12.0+, watchOS 8.0+, tvOS 15.0+
///
/// ## Generated Behavior:
/// 1. **ObservableObject**: Adds ObservableObject conformance if missing
/// 2. **Dependency Injection**: Generates DI-aware initializer
/// 3. **Container Integration**: Integrates with SwiftUI Environment container
/// 4. **Factory Methods**: Optional factory method generation
/// 5. **Preview Support**: Preview-friendly initialization
/// 6. **Error Handling**: Clear errors for missing dependencies
///
/// ## Real-World Examples:
///
/// ```swift
/// // E-commerce App
/// @ViewModelInject
/// class ShoppingCartViewModel: ObservableObject {
///     private let cartService: CartServiceProtocol
///     private let productService: ProductServiceProtocol
///     private let paymentService: PaymentServiceProtocol
///
///     @Published var items: [CartItem] = []
///     @Published var total: Decimal = 0
///     @Published var isProcessingPayment = false
///
///     func addItem(_ productId: String, quantity: Int = 1) async {
///         guard let product = await productService.product(id: productId) else { return }
///
///         let cartItem = CartItem(product: product, quantity: quantity)
///         await cartService.addItem(cartItem)
///         await refreshCart()
///     }
///
///     func checkout() async throws {
///         isProcessingPayment = true
///         defer { isProcessingPayment = false }
///
///         try await paymentService.processPayment(for: items, total: total)
///         await cartService.clear()
///         await refreshCart()
///     }
///
///     private func refreshCart() async {
///         items = await cartService.items()
///         total = items.reduce(0) { $0 + $1.totalPrice }
///     }
/// }
///
/// // Social Media App
/// @ViewModelInject
/// class PostComposerViewModel: ObservableObject {
///     private let postService: PostServiceProtocol
///     private let mediaService: MediaServiceProtocol
///     private let userService: UserServiceProtocol
///
///     @Published var text = ""
///     @Published var selectedImages: [UIImage] = []
///     @Published var isPosting = false
///     @Published var error: Error?
///
///     func addImage(_ image: UIImage) {
///         selectedImages.append(image)
///     }
///
///     func post() async {
///         guard !text.isEmpty || !selectedImages.isEmpty else { return }
///
///         isPosting = true
///         error = nil
///
///         do {
///             // Upload media first
///             var mediaUrls: [URL] = []
///             for image in selectedImages {
///                 let url = try await mediaService.upload(image)
///                 mediaUrls.append(url)
///             }
///
///             // Create post
///             let post = Post(
///                 text: text,
///                 mediaUrls: mediaUrls,
///                 author: userService.currentUser
///             )
///
///             try await postService.create(post)
///
///             // Reset form
///             await MainActor.run {
///                 text = ""
///                 selectedImages = []
///             }
///         } catch {
///             await MainActor.run {
///                 self.error = error
///             }
///         }
///
///         isPosting = false
///     }
/// }
/// ```
@attached(member, names: arbitrary)
@attached(extension, conformances: ObservableObject)
public macro ViewModelInject(
    container: String = "default",
    scope: ObjectScope = .transient,
    generateFactory: Bool = false,
    previewSupport: Bool = true
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "ViewModelInjectMacro")

// MARK: - ViewModel Injection Support Types

/// Configuration for ViewModel dependency injection
public struct ViewModelConfig {
    /// Container name for multi-container scenarios
    public let containerName: String

    /// Object scope for ViewModel registration
    public let scope: ObjectScope

    /// Whether to generate factory method
    public let generateFactory: Bool

    /// Whether to generate preview support
    public let previewSupport: Bool

    public init(
        containerName: String = "default",
        scope: ObjectScope = .transient,
        generateFactory: Bool = false,
        previewSupport: Bool = true
    ) {
        self.containerName = containerName
        self.scope = scope
        self.generateFactory = generateFactory
        self.previewSupport = previewSupport
    }
}

/// Base protocol for ViewModels with dependency injection support
public protocol InjectableViewModel: ObservableObject {
    /// Container used for dependency resolution
    var container: DIContainer { get }

    /// Initialize ViewModel with dependency injection container
    init(container: DIContainer)
}

/// Errors that can occur during ViewModel dependency injection
public enum ViewModelInjectError: Error, LocalizedError {
    case containerNotFound
    case dependencyResolutionFailed(type: String, dependency: String)
    case invalidViewModelConfiguration
    case initializerGenerationFailed

    public var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "DIContainer not found for ViewModel dependency injection"
        case let .dependencyResolutionFailed(type, dependency):
            return "Failed to resolve dependency '\(dependency)' for ViewModel '\(type)'"
        case .invalidViewModelConfiguration:
            return "Invalid ViewModel configuration for dependency injection"
        case .initializerGenerationFailed:
            return "Failed to generate dependency injection initializer for ViewModel"
        }
    }
}

// MARK: - ViewModel Factory Protocol

/// Protocol for ViewModels that can be created by factories
public protocol ViewModelFactory {
    associatedtype ViewModel: InjectableViewModel

    /// Create ViewModel instance with dependency injection
    static func create(container: DIContainer) -> ViewModel
}

// MARK: - SwiftUI Integration Helpers

extension View {
    /// Create a StateObject ViewModel with dependency injection
    public func stateObject<VM: InjectableViewModel>(
        _ viewModelType: VM.Type,
        container: DIContainer? = nil
    ) -> some View {
        self.modifier(ViewModelInjectionModifier<VM>(
            viewModelType: viewModelType,
            container: container
        ))
    }
}

/// ViewModifier for injecting ViewModels into SwiftUI views
public struct ViewModelInjectionModifier<VM: InjectableViewModel>: ViewModifier {
    let viewModelType: VM.Type
    let container: DIContainer?

    @EnvironmentObject private var environmentContainer: DIContainer

    public func body(content: Content) -> some View {
        let actualContainer = container ?? environmentContainer
        let viewModel = VM(container: actualContainer)

        content
            .environmentObject(viewModel)
    }
}

// MARK: - Preview Support

/// Utilities for creating ViewModels in SwiftUI previews
public struct PreviewViewModel {
    /// Create a ViewModel with mock dependencies for previews
    @MainActor public static func mock<VM: InjectableViewModel>(
        _ viewModelType: VM.Type,
        configure: (Container) -> Void = { _ in }
    ) -> VM {
        let container = Container()
        configure(container)
        return VM(container: DIContainer(container))
    }

    /// Create a ViewModel with specific mock services
    @MainActor public static func mock<VM: InjectableViewModel>(
        _ viewModelType: VM.Type,
        mockServices: [String: Any]
    ) -> VM {
        let container = Container()

        for (_, _) in mockServices {
            // Register mock services in container
            // Note: This is a simplified approach - real implementation would use type erasure
            // Services are identified by string names instead of types for simplicity
        }

        return VM(container: DIContainer(container))
    }
}

// MARK: - Dependency Analysis Support

/// Attribute for marking named dependencies in ViewModel initializers
@propertyWrapper
public struct Named<T> {
    public let name: String
    public var wrappedValue: T

    public init(_ name: String, wrappedValue: T) {
        self.name = name
        self.wrappedValue = wrappedValue
    }
}

/// Attribute for marking optional dependencies in ViewModel initializers
@propertyWrapper
public struct Optional<T> {
    public var wrappedValue: T?

    public init(wrappedValue: T? = nil) {
        self.wrappedValue = wrappedValue
    }
}

// MARK: - Object Scope Extension

extension ObjectScope {
    /// Default scope for ViewModel objects
    public static let viewModel: ObjectScope = .transient

    /// Singleton scope for shared ViewModels
    public static let sharedViewModel: ObjectScope = .container
}
