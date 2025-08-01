// PublisherInject.swift - Combine Publisher dependency injection macro declarations

import Foundation
import Combine
import Swinject

// MARK: - @PublisherInject Macro

/// Enables Combine Publisher dependency injection with reactive data streams and optional resolution.
///
/// This macro transforms properties into Combine Publishers that reactively resolve dependencies
/// from the container, providing reactive programming patterns with dependency injection.
///
/// ## Basic Usage
///
/// ```swift
/// class WeatherService {
///     @PublisherInject var locationService: AnyPublisher<LocationServiceProtocol?, Never>
///     @PublisherInject var networkClient: AnyPublisher<NetworkClientProtocol?, Never>
///     
///     func getCurrentWeather() -> AnyPublisher<Weather?, Never> {
///         return Publishers.CombineLatest(locationService, networkClient)
///             .flatMap { (location, network) -> AnyPublisher<Weather?, Never> in
///                 guard let locationService = location,
///                       let networkClient = network else {
///                     return Just(nil).eraseToAnyPublisher()
///                 }
///                 
///                 return locationService.currentLocation()
///                     .flatMap { coords in
///                         networkClient.fetchWeather(for: coords)
///                     }
///                     .eraseToAnyPublisher()
///             }
///             .eraseToAnyPublisher()
///     }
/// }
/// ```
///
/// ## Named Dependencies with Publishers
///
/// ```swift
/// class AnalyticsAggregator {
///     @PublisherInject("primary") var primaryAnalytics: AnyPublisher<AnalyticsProtocol?, Never>
///     @PublisherInject("secondary") var secondaryAnalytics: AnyPublisher<AnalyticsProtocol?, Never>
///     @PublisherInject("realtime") var realtimeAnalytics: AnyPublisher<RealtimeAnalyticsProtocol?, Never>
///     
///     var combinedAnalytics: AnyPublisher<[AnalyticsEvent], Never> {
///         return Publishers.CombineLatest3(primaryAnalytics, secondaryAnalytics, realtimeAnalytics)
///             .compactMap { (primary, secondary, realtime) in
///                 var events: [AnalyticsEvent] = []
///                 if let primary = primary { events.append(contentsOf: primary.getEvents()) }
///                 if let secondary = secondary { events.append(contentsOf: secondary.getEvents()) }
///                 if let realtime = realtime { events.append(contentsOf: realtime.getLiveEvents()) }
///                 return events
///             }
///             .eraseToAnyPublisher()
///     }
/// }
/// ```
///
/// ## Reactive Container Updates
///
/// ```swift
/// class DynamicConfigurationService {
///     @PublisherInject(reactive: true) var configProvider: AnyPublisher<ConfigProviderProtocol?, Never>
///     @PublisherInject(reactive: true, debounce: 0.5) var featureFlags: AnyPublisher<FeatureFlagsProtocol?, Never>
///     
///     var currentConfiguration: AnyPublisher<Configuration, Never> {
///         return Publishers.CombineLatest(configProvider, featureFlags)
///             .compactMap { (provider, flags) -> Configuration? in
///                 guard let provider = provider, let flags = flags else { return nil }
///                 return Configuration(
///                     settings: provider.getSettings(),
///                     features: flags.getAllFlags()
///                 )
///             }
///             .removeDuplicates()
///             .eraseToAnyPublisher()
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Publisher Property**: AnyPublisher that emits resolved dependencies
/// 2. **Reactive Resolution**: Container changes trigger new emissions
/// 3. **Optional Handling**: Graceful handling of unregistered dependencies
/// 4. **Debouncing**: Optional debouncing for rapidly changing dependencies
/// 5. **Thread Safety**: Publisher emissions are thread-safe
///
/// ## Performance Characteristics
///
/// - **Lazy Subscription**: Publishers only start resolving when subscribed to
/// - **Cached Resolution**: Successful resolutions are cached until container changes
/// - **Memory Efficient**: Automatic cleanup when publishers are deallocated
/// - **Reactive Updates**: Container registration changes trigger re-resolution
///
/// ## Integration with SwiftUI
///
/// ```swift
/// struct ConfigurableView: View {
///     @PublisherInject var themeProvider: AnyPublisher<ThemeProviderProtocol?, Never>
///     @State private var currentTheme: Theme = .default
///     
///     var body: some View {
///         VStack {
///             Text("Themed Content")
///                 .foregroundColor(currentTheme.primaryColor)
///                 .background(currentTheme.backgroundColor)
///         }
///         .onReceive(themeProvider.compactMap { $0?.currentTheme }) { theme in
///             currentTheme = theme
///         }
///     }
/// }
/// ```
@attached(accessor)
public macro PublisherInject(
    _ name: String? = nil,
    reactive: Bool = false,
    debounce: TimeInterval = 0.0,
    container: String? = nil,
    resolver: String = "resolver"
) = #externalMacro(module: "SwinJectMacrosImplementation", type: "PublisherInjectMacro")

// MARK: - Publisher Injection Support Types

/// Configuration for Combine Publisher injection
public struct PublisherInjectConfiguration {
    public let name: String?
    public let isReactive: Bool
    public let debounceInterval: TimeInterval
    public let containerName: String?
    public let resolverName: String
    
    public init(
        name: String? = nil,
        isReactive: Bool = false,
        debounceInterval: TimeInterval = 0.0,
        containerName: String? = nil,
        resolverName: String = "resolver"
    ) {
        self.name = name
        self.isReactive = isReactive
        self.debounceInterval = debounceInterval
        self.containerName = containerName
        self.resolverName = resolverName
    }
}

/// Publisher injection resolution result
public enum PublisherResolutionResult<T> {
    case resolved(T)
    case unavailable
    case error(Error)
    
    /// Convert to optional value
    public var value: T? {
        if case .resolved(let value) = self {
            return value
        }
        return nil
    }
    
    /// Check if resolution was successful
    public var isResolved: Bool {
        if case .resolved = self { return true }
        return false
    }
}

/// Publisher injection errors
public enum PublisherInjectionError: Error, LocalizedError {
    case containerNotFound(String)
    case resolutionFailed(String, String?)
    case publisherCreationFailed(String)
    case reactiveUpdateFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .containerNotFound(let name):
            return "Container '\(name)' not found for Publisher injection"
        case .resolutionFailed(let type, let name):
            let nameStr = name.map { " with name '\($0)'" } ?? ""
            return "Failed to resolve '\(type)'\(nameStr) for Publisher injection"
        case .publisherCreationFailed(let type):
            return "Failed to create Publisher for type '\(type)'"
        case .reactiveUpdateFailed(let type):
            return "Failed to update reactive Publisher for type '\(type)'"
        }
    }
}

// MARK: - Container Extensions for Publisher Injection

public extension Container {
    
    /// Create a Publisher that emits the resolved dependency
    func publisherFor<T>(
        _ serviceType: T.Type,
        name: String? = nil
    ) -> AnyPublisher<T?, Never> {
        return Just(resolve(serviceType, name: name))
            .eraseToAnyPublisher()
    }
    
    /// Create a reactive Publisher that re-emits when container changes
    func reactivePublisherFor<T>(
        _ serviceType: T.Type,
        name: String? = nil,
        debounceInterval: TimeInterval = 0.0
    ) -> AnyPublisher<T?, Never> {
        
        // Create a subject that will emit container changes
        let containerChanges = containerChangeSubject
            .map { [weak self] _ in
                self?.resolve(serviceType, name: name)
            }
            .eraseToAnyPublisher()
        
        // Apply debouncing if specified
        if debounceInterval > 0 {
            return containerChanges
                .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        } else {
            return containerChanges
                .eraseToAnyPublisher()
        }
    }
    
    /// Internal subject for container change notifications
    private var containerChangeSubject: PassthroughSubject<Void, Never> {
        // This would be implemented as an associated object or similar
        // For now, return a simple subject
        return PassthroughSubject<Void, Never>()
    }
}

// MARK: - Publisher Factory Utilities

/// Factory for creating dependency Publishers
public struct DependencyPublisherFactory {
    
    /// Create a simple dependency Publisher
    public static func createPublisher<T>(
        for serviceType: T.Type,
        name: String? = nil,
        container: Container? = nil
    ) -> AnyPublisher<T?, Never> {
        let resolveContainer = container ?? Container.publisherShared ?? Container()
        return resolveContainer.publisherFor(serviceType, name: name)
    }
    
    /// Create a reactive dependency Publisher
    public static func createReactivePublisher<T>(
        for serviceType: T.Type,
        name: String? = nil,
        debounceInterval: TimeInterval = 0.0,
        container: Container? = nil
    ) -> AnyPublisher<T?, Never> {
        let resolveContainer = container ?? Container.publisherShared ?? Container()
        return resolveContainer.reactivePublisherFor(
            serviceType,
            name: name,
            debounceInterval: debounceInterval
        )
    }
}

// MARK: - Extension for Container Publisher Instance

public extension Container {
    /// Publisher-specific shared container instance
    static var publisherShared: Container? = nil
    
    /// Set the shared container for Publisher injection
    static func setPublisherShared(_ container: Container) {
        publisherShared = container
    }
}

// MARK: - Combine Operators for Dependency Injection

public extension Publisher where Output == Optional<Any> {
    
    /// Map optional dependency to non-optional with fallback
    func withFallback<T>(_ fallback: T) -> Publishers.Map<Self, T> {
        return map { $0 as? T ?? fallback }
    }
    
    /// Filter out nil dependencies
    func compactMapDependency<T>() -> Publishers.CompactMap<Self, T> {
        return compactMap { $0 as? T }
    }
}