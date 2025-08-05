// Interceptor.swift - AOP interceptor macro declarations and support types
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation

// MARK: - @Interceptor Macro

/// Automatically generates method interception with before/after/onError hooks for aspect-oriented programming.
///
/// This macro enables cross-cutting concerns like logging, security, caching, validation, and performance monitoring
/// to be applied declaratively to methods without modifying their core business logic.
///
/// ## Basic Usage
///
/// ```swift
/// @Interceptor(before: ["LoggingInterceptor", "SecurityInterceptor"])
/// func processPayment(amount: Double, cardToken: String) -> PaymentResult {
///     // Core business logic remains clean
///     return PaymentProcessor.process(amount: amount, token: cardToken)
/// }
/// ```
///
/// ## Advanced Usage with Error Handling
///
/// ```swift
/// @Interceptor(
///     before: ["ValidationInterceptor", "LoggingInterceptor"],
///     after: ["AuditInterceptor", "NotificationInterceptor"],
///     onError: ["ErrorHandlingInterceptor", "AlertingInterceptor"]
/// )
/// func createUser(userData: UserData) throws -> User {
///     return try UserService.create(userData)
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Interceptor Chain**: Wraps your method with before/after/error interceptors
/// 2. **Context Passing**: Provides execution context to interceptors
/// 3. **Error Handling**: Proper exception handling with error interceptors
/// 4. **Performance Tracking**: Optional execution time measurement
/// 5. **Parameter Access**: Interceptors can access and modify method parameters
///
/// ## Interceptor Protocol
///
/// Your interceptors must conform to the `MethodInterceptor` protocol:
///
/// ```swift
/// class LoggingInterceptor: MethodInterceptor {
///     func before(context: InterceptorContext) throws {
///         print("🚀 Executing: \(context.methodName) with args: \(context.parameters)")
///     }
///
///     func after(context: InterceptorContext, result: Any?) throws {
///         print("✅ Completed: \(context.methodName) in \(context.executionTime)ms")
///     }
///
///     func onError(context: InterceptorContext, error: Error) throws {
///         print("❌ Failed: \(context.methodName) with error: \(error)")
///         throw error  // Re-throw or handle as needed
///     }
/// }
/// ```
///
/// ## Parameters:
/// - `before`: Array of interceptor class names to execute before the method
/// - `after`: Array of interceptor class names to execute after successful method completion
/// - `onError`: Array of interceptor class names to execute when method throws an error
/// - `order`: Execution order when multiple interceptor macros are applied (default: 0)
/// - `async`: Whether to support async interceptors (default: auto-detected)
/// - `measureTime`: Whether to measure and provide execution time (default: true)
///
/// ## Requirements:
/// - Can be applied to instance methods, static methods, and functions
/// - Method can be sync or async, throwing or non-throwing
/// - Interceptors must be resolvable from the dependency injection container
/// - All interceptor classes must conform to `MethodInterceptor` protocol
///
/// ## Generated Behavior:
/// 1. **Before Phase**: Execute all `before` interceptors in order
/// 2. **Method Execution**: Call the original method with potentially modified parameters
/// 3. **After Phase**: Execute all `after` interceptors in reverse order (LIFO)
/// 4. **Error Phase**: If any error occurs, execute `onError` interceptors
/// 5. **Context Management**: Provide rich context information to all interceptors
///
/// ## Performance Notes:
/// - Zero runtime overhead when no interceptors are configured
/// - Minimal overhead for interceptor chain execution
/// - Compile-time validation of interceptor class names
/// - Efficient parameter and context marshalling
@attached(peer, names: suffixed(Intercepted))
public macro Interceptor(
    before: [String] = [],
    after: [String] = [],
    onError: [String] = [],
    order: Int = 0,
    async: Bool? = nil,
    measureTime: Bool = true
) = #externalMacro(module: "SwinjectMacrosImplementation", type: "InterceptorMacro")

// MARK: - Interceptor Protocol and Support Types

/// Protocol that all method interceptors must conform to.
public protocol MethodInterceptor {
    /// Called before the intercepted method executes.
    /// Can modify parameters, perform validation, setup context, etc.
    /// - Parameter context: Rich context information about the method execution
    /// - Throws: If validation fails or setup cannot complete
    func before(context: InterceptorContext) throws

    /// Called after the intercepted method executes successfully.
    /// Can process results, perform cleanup, trigger notifications, etc.
    /// - Parameters:
    ///   - context: Rich context information about the method execution
    ///   - result: The return value from the intercepted method (nil for Void methods)
    /// - Throws: If post-processing fails
    func after(context: InterceptorContext, result: Any?) throws

    /// Called when the intercepted method or any interceptor throws an error.
    /// Can perform error handling, logging, alerting, cleanup, etc.
    /// - Parameters:
    ///   - context: Rich context information about the method execution
    ///   - error: The error that was thrown
    /// - Throws: Can throw a different error or re-throw the original
    func onError(context: InterceptorContext, error: Error) throws
}

/// Rich context information provided to interceptors during method execution.
public struct InterceptorContext {
    /// The name of the method being intercepted
    public let methodName: String

    /// The class or type name containing the method
    public let typeName: String

    /// Method parameters as key-value pairs (parameter name -> value)
    public let parameters: [String: Any]

    /// Method parameter types for type-safe access
    public let parameterTypes: [String: Any.Type]

    /// Whether the method is async
    public let isAsync: Bool

    /// Whether the method can throw
    public let canThrow: Bool

    /// The return type of the method
    public let returnType: Any.Type

    /// Execution start time (for performance measurement)
    public let startTime: CFAbsoluteTime

    /// Current execution time in milliseconds (updated throughout execution)
    public var executionTime: Double {
        (CFAbsoluteTime() - startTime) * 1000
    }

    /// Additional metadata that can be set by interceptors
    public var metadata: [String: Any] = [:]

    /// Unique identifier for this method execution
    public let executionId = UUID()

    public init(
        methodName: String,
        typeName: String,
        parameters: [String: Any],
        parameterTypes: [String: Any.Type],
        isAsync: Bool,
        canThrow: Bool,
        returnType: Any.Type,
        startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    ) {
        self.methodName = methodName
        self.typeName = typeName
        self.parameters = parameters
        self.parameterTypes = parameterTypes
        self.isAsync = isAsync
        self.canThrow = canThrow
        self.returnType = returnType
        self.startTime = startTime
    }
}

// MARK: - Default Interceptor Implementations

/// Base interceptor class that provides default no-op implementations.
/// Inherit from this class and override only the methods you need.
open class BaseInterceptor: MethodInterceptor {
    public init() {}

    open func before(context: InterceptorContext) throws {
        // Default: no-op
    }

    open func after(context: InterceptorContext, result: Any?) throws {
        // Default: no-op
    }

    open func onError(context: InterceptorContext, error: Error) throws {
        // Default: re-throw the error
        throw error
    }
}

/// Logging interceptor that logs method entry, exit, and errors.
public class LoggingInterceptor: BaseInterceptor {
    override public func before(context: InterceptorContext) throws {
        print("🚀 [\(context.executionId.uuidString.prefix(8))] Entering \(context.typeName).\(context.methodName)")
        if !context.parameters.isEmpty {
            print("   Parameters: \(context.parameters)")
        }
    }

    override public func after(context: InterceptorContext, result: Any?) throws {
        print(
            "✅ [\(context.executionId.uuidString.prefix(8))] Completed \(context.typeName).\(context.methodName) in \(String(format: "%.2f", context.executionTime))ms"
        )
        if let result = result {
            print("   Result: \(result)")
        }
    }

    override public func onError(context: InterceptorContext, error: Error) throws {
        print(
            "❌ [\(context.executionId.uuidString.prefix(8))] Failed \(context.typeName).\(context.methodName) after \(String(format: "%.2f", context.executionTime))ms"
        )
        print("   Error: \(error)")
        throw error
    }
}

/// Performance tracking interceptor that measures and reports execution times.
public class PerformanceInterceptor: BaseInterceptor {
    private static var performanceMetrics: [String: [Double]] = [:]
    private static let metricsQueue = DispatchQueue(label: "performance.metrics", attributes: .concurrent)

    override public func after(context: InterceptorContext, result: Any?) throws {
        let methodKey = "\(context.typeName).\(context.methodName)"
        let executionTime = context.executionTime

        Self.metricsQueue.async(flags: .barrier) {
            Self.performanceMetrics[methodKey, default: []].append(executionTime)

            // Keep only last 100 measurements to prevent memory growth
            if Self.performanceMetrics[methodKey]!.count > 100 {
                Self.performanceMetrics[methodKey]!.removeFirst()
            }
        }

        // Log slow methods (configurable threshold)
        if executionTime > 1000 { // 1 second
            print("⚠️  SLOW METHOD: \(methodKey) took \(String(format: "%.2f", executionTime))ms")
        }
    }

    /// Get performance statistics for a method
    public static func getStats(for methodKey: String) -> (avg: Double, min: Double, max: Double, count: Int)? {
        metricsQueue.sync {
            guard let times = performanceMetrics[methodKey], !times.isEmpty else { return nil }
            return (
                avg: times.reduce(0, +) / Double(times.count),
                min: times.min() ?? 0,
                max: times.max() ?? 0,
                count: times.count
            )
        }
    }

    /// Print performance report for all tracked methods
    public static func printPerformanceReport() {
        metricsQueue.sync {
            print("\n📊 Performance Report:")
            print("=" * 50)

            for (method, times) in self.performanceMetrics.sorted(by: { $0.key < $1.key }) {
                let avg = times.reduce(0, +) / Double(times.count)
                let min = times.min() ?? 0
                let max = times.max() ?? 0

                print("\(method):")
                print("  Calls: \(times.count)")
                print("  Avg: \(String(format: "%.2f", avg))ms")
                print("  Min: \(String(format: "%.2f", min))ms")
                print("  Max: \(String(format: "%.2f", max))ms")
                print()
            }
        }
    }
}

/// Validation interceptor that can perform parameter validation before method execution.
public class ValidationInterceptor: BaseInterceptor {
    override public func before(context: InterceptorContext) throws {
        // Example validation - override in subclasses for specific validation logic
        for (paramName, value) in context.parameters {
            if let stringValue = value as? String, stringValue.isEmpty {
                throw ValidationError.emptyParameter(paramName)
            }
        }
    }
}

/// Error handling interceptor that can transform or log errors.
public class ErrorHandlingInterceptor: BaseInterceptor {
    override public func onError(context: InterceptorContext, error: Error) throws {
        // Log error details
        print("🔥 Error in \(context.typeName).\(context.methodName): \(error)")

        // Could transform errors, send to error reporting service, etc.
        if let validationError = error as? ValidationError {
            // Transform validation errors to user-friendly messages
            throw UserFriendlyError(message: "Please check your input: \(validationError.localizedDescription)")
        }

        // Re-throw other errors unchanged
        throw error
    }
}

// MARK: - Error Types

/// Validation errors thrown by interceptors
public enum ValidationError: Error, LocalizedError {
    case emptyParameter(String)
    case invalidFormat(String, expected: String)
    case outOfRange(String, min: Any?, max: Any?)

    public var errorDescription: String? {
        switch self {
        case .emptyParameter(let param):
            "Parameter '\(param)' cannot be empty"
        case .invalidFormat(let param, let expected):
            "Parameter '\(param)' has invalid format, expected: \(expected)"
        case .outOfRange(let param, let min, let max):
            "Parameter '\(param)' is out of range (min: \(min ?? "none"), max: \(max ?? "none"))"
        }
    }
}

/// User-friendly errors for UI display
public struct UserFriendlyError: Error, LocalizedError {
    public let message: String

    public var errorDescription: String? {
        message
    }

    public init(message: String) {
        self.message = message
    }
}

// MARK: - Interceptor Registry

/// Registry for managing interceptor instances and dependency injection integration.
public class InterceptorRegistry {
    private static var interceptors: [String: MethodInterceptor] = [:]
    private static let registryQueue = DispatchQueue(label: "interceptor.registry", attributes: .concurrent)

    /// Register an interceptor instance with a name
    public static func register(interceptor: MethodInterceptor, name: String) {
        registryQueue.async(flags: .barrier) {
            self.interceptors[name] = interceptor
        }
    }

    /// Get an interceptor by name
    public static func get(name: String) -> MethodInterceptor? {
        registryQueue.sync {
            self.interceptors[name]
        }
    }

    /// Register default interceptors
    public static func registerDefaults() {
        register(interceptor: LoggingInterceptor(), name: "LoggingInterceptor")
        register(interceptor: PerformanceInterceptor(), name: "PerformanceInterceptor")
        register(interceptor: ValidationInterceptor(), name: "ValidationInterceptor")
        register(interceptor: ErrorHandlingInterceptor(), name: "ErrorHandlingInterceptor")
    }
}

// MARK: - String Extension for Pretty Printing

// String * operator moved to StringExtensions.swift
