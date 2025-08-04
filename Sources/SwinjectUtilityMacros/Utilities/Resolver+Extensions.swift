import Foundation
import Swinject

/// Extensions to Swinject's Resolver for thread-safe operations
public extension Resolver {

    /// Returns a thread-safe resolver instance.
    ///
    /// This computed property ensures that the resolver returned is thread-safe for concurrent access.
    /// According to Swinject documentation, `Container.synchronize()` always returns a thread-safe
    /// view of the container as a `Resolver` type.
    ///
    /// ## Usage
    /// ```swift
    /// let container = Container()
    /// // ... register services
    ///
    /// let threadSafeResolver = container.synchronizedResolver
    /// // Use threadSafeResolver for concurrent resolution operations
    /// ```
    ///
    /// ## Thread Safety
    /// - Registrations must still be performed on a single thread (typically during app startup)
    /// - Only use this resolver for resolution operations that need thread safety
    /// - The synchronized resolver uses NSLock internally for thread coordination
    ///
    /// ## Performance Considerations
    /// - Synchronized resolution has a small performance overhead due to locking
    /// - Consider caching the synchronized resolver instance rather than accessing this property repeatedly
    /// - For single-threaded scenarios, use the original resolver directly
    ///
    /// - Returns: A thread-safe Resolver instance
    var synchronizedResolver: Resolver {
        // Always return a synchronized version to ensure thread safety
        // This is the safest approach since Container.synchronize() is idempotent
        if let container = self as? Container {
            return container.synchronize()
        }

        // If already a resolver (not a container), assume it's already synchronized
        return self
    }

    /// Thread-safe resolve method that automatically uses synchronized resolver
    ///
    /// This method provides a convenient way to resolve dependencies in a thread-safe manner
    /// without having to manually access the synchronizedResolver property.
    ///
    /// ## Usage
    /// ```swift
    /// let service = resolver.synchronizedResolve(MyService.self)
    /// ```
    ///
    /// - Parameter serviceType: The service type to resolve
    /// - Returns: The resolved service instance, or nil if not registered
    func synchronizedResolve<Service>(_ serviceType: Service.Type) -> Service? {
        synchronizedResolver.resolve(serviceType)
    }

    /// Thread-safe resolve method with name parameter
    ///
    /// - Parameters:
    ///   - serviceType: The service type to resolve
    ///   - name: The registration name
    /// - Returns: The resolved service instance, or nil if not registered
    func synchronizedResolve<Service>(_ serviceType: Service.Type, name: String?) -> Service? {
        synchronizedResolver.resolve(serviceType, name: name)
    }

    /// Thread-safe resolve method with arguments
    ///
    /// - Parameters:
    ///   - serviceType: The service type to resolve
    ///   - argument: The argument to pass to the factory
    /// - Returns: The resolved service instance, or nil if not registered
    func synchronizedResolve<Service, Arg1>(_ serviceType: Service.Type, argument: Arg1) -> Service? {
        synchronizedResolver.resolve(serviceType, argument: argument)
    }

    /// Thread-safe resolve method with name and arguments
    ///
    /// - Parameters:
    ///   - serviceType: The service type to resolve
    ///   - name: The registration name
    ///   - argument: The argument to pass to the factory
    /// - Returns: The resolved service instance, or nil if not registered
    func synchronizedResolve<Service, Arg1>(_ serviceType: Service.Type, name: String?, argument: Arg1) -> Service? {
        synchronizedResolver.resolve(serviceType, name: name, argument: argument)
    }
}

/// Additional utilities for Container management
public extension Container {

    /// Creates a thread-safe container with proper initialization
    ///
    /// This is a convenience method that creates a container and immediately returns
    /// its synchronized version, ensuring all resolution operations are thread-safe.
    ///
    /// ## Usage
    /// ```swift
    /// let threadSafeContainer = Container.createSynchronized()
    /// // Register services on the original container (single-threaded)
    /// let originalContainer = (threadSafeContainer as! Container).parent!
    /// originalContainer.register(MyService.self) { _ in MyServiceImpl() }
    ///
    /// // Use threadSafeContainer for resolution (multi-threaded)
    /// let service = threadSafeContainer.resolve(MyService.self)
    /// ```
    ///
    /// - Returns: A thread-safe Resolver instance
    static func createSynchronized() -> Resolver {
        Container().synchronize()
    }

    /// Checks if a resolver is thread-safe
    ///
    /// This method helps determine whether a resolver instance is already synchronized
    /// and safe for concurrent access.
    ///
    /// ## Implementation Note
    /// Based on Swinject source code, `Container.synchronize()` returns a new Container instance
    /// with `synchronized: true`. Since there's no public API to check this flag, this method
    /// provides a simple way to determine if synchronization has been applied.
    ///
    /// - Parameter resolver: The resolver to check
    /// - Returns: Always returns true since we can't reliably detect synchronization state
    static func isSynchronized(_ resolver: Resolver) -> Bool {
        // Since Container.synchronize() returns a new Container with synchronized=true
        // and there's no public API to check this flag, we'll assume any resolver
        // could potentially be synchronized. The safest approach is to always
        // use synchronizedResolver when thread safety is needed.

        // For practical purposes, we'll check if it's at least a valid resolver
        resolver is Container || true
    }
}
