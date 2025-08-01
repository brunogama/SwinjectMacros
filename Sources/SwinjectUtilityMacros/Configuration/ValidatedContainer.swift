// ValidatedContainer.swift - Compile-time container validation

import Foundation
import Swinject

// MARK: - @ValidatedContainer Macro

/// Validates dependency injection container configuration at compile time.
///
/// This macro analyzes your container setup and ensures all dependencies are properly
/// registered, preventing runtime dependency resolution failures.
///
/// ## Basic Usage
///
/// ```swift
/// @ValidatedContainer
/// class AppContainer {
///     static func configure() -> Container {
///         let container = Container()
///         
///         // Register services
///         container.register(UserServiceProtocol.self) { _ in
///             UserService()
///         }
///         
///         container.register(APIClientProtocol.self) { _ in
///             APIClient()
///         }
///         
///         // Register dependent services
///         container.register(UserRepositoryProtocol.self) { resolver in
///             UserRepository(
///                 apiClient: resolver.resolve(APIClientProtocol.self)!,
///                 userService: resolver.resolve(UserServiceProtocol.self)!
///             )
///         }
///         
///         return container
///     }
/// }
/// 
/// // Compile-time validation ensures:
/// // ✅ All dependencies are registered
/// // ✅ No circular dependencies exist
/// // ✅ All required protocols are implemented
/// // ✅ Scope configurations are valid
/// ```
///
/// ## Advanced Validation Rules
///
/// ```swift
/// @ValidatedContainer(
///     strictMode: true,
///     validateScopes: true,
///     requireDocumentation: true,
///     checkCircularDependencies: true
/// )
/// class ProductionContainer {
///     
///     /// User management services
///     @DependencyGroup("UserServices")
///     static func configureUserServices(_ container: Container) {
///         container.register(UserServiceProtocol.self) { _ in
///             UserService()
///         }.inObjectScope(.container)
///         
///         container.register(UserRepositoryProtocol.self) { resolver in
///             UserRepository(userService: resolver.resolve(UserServiceProtocol.self)!)
///         }.inObjectScope(.transient)
///     }
///     
///     /// Network services
///     @DependencyGroup("NetworkServices")
///     static func configureNetworkServices(_ container: Container) {
///         container.register(APIClientProtocol.self) { _ in
///             APIClient(baseURL: Environment.apiBaseURL)
///         }.inObjectScope(.container)
///         
///         container.register(NetworkManagerProtocol.self) { resolver in
///             NetworkManager(apiClient: resolver.resolve(APIClientProtocol.self)!)
///         }
///     }
///     
///     static func configure() -> Container {
///         let container = Container()
///         configureUserServices(container)
///         configureNetworkServices(container)
///         return container
///     }
/// }
/// ```
///
/// ## Validation Features
///
/// ### Dependency Resolution Validation
/// ```swift
/// @ValidatedContainer
/// class ValidationDemoContainer {
///     static func configure() -> Container {
///         let container = Container()
///         
///         // ✅ This will pass validation
///         container.register(LoggerProtocol.self) { _ in
///             ConsoleLogger()
///         }
///         
///         container.register(UserService.self) { resolver in
///             UserService(logger: resolver.resolve(LoggerProtocol.self)!)
///         }
///         
///         // ❌ This will fail validation - DatabaseProtocol not registered
///         container.register(UserRepository.self) { resolver in
///             UserRepository(database: resolver.resolve(DatabaseProtocol.self)!)
///         }
///         
///         return container
///     }
/// }
/// 
/// // Compile-time error:
/// // "Dependency 'DatabaseProtocol' required by 'UserRepository' is not registered"
/// ```
///
/// ### Circular Dependency Detection
/// ```swift
/// @ValidatedContainer(checkCircularDependencies: true)
/// class CircularDependencyContainer {
///     static func configure() -> Container {
///         let container = Container()
///         
///         // ❌ This creates a circular dependency
///         container.register(ServiceA.self) { resolver in
///             ServiceA(serviceB: resolver.resolve(ServiceB.self)!)
///         }
///         
///         container.register(ServiceB.self) { resolver in
///             ServiceB(serviceA: resolver.resolve(ServiceA.self)!)
///         }
///         
///         return container
///     }
/// }
/// 
/// // Compile-time error:
/// // "Circular dependency detected: ServiceA -> ServiceB -> ServiceA"
/// ```
///
/// ### Scope Validation
/// ```swift
/// @ValidatedContainer(validateScopes: true)
/// class ScopeValidationContainer {
///     static func configure() -> Container {
///         let container = Container()
///         
///         // ✅ Singleton service
///         container.register(ConfigurationService.self) { _ in
///             ConfigurationService()
///         }.inObjectScope(.container)
///         
///         // ⚠️ Warning: Transient service depending on singleton
///         container.register(RequestHandler.self) { resolver in
///             RequestHandler(config: resolver.resolve(ConfigurationService.self)!)
///         }.inObjectScope(.transient) // This is fine - transient can depend on singleton
///         
///         // ❌ Error: Singleton depending on transient
///         container.register(GlobalState.self) { resolver in
///             GlobalState(handler: resolver.resolve(RequestHandler.self)!)
///         }.inObjectScope(.container) // This is problematic
///         
///         return container
///     }
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Dependency Graph Analysis**: Complete analysis of service dependencies
/// 2. **Validation Methods**: Runtime and compile-time validation utilities
/// 3. **Documentation**: Automatic dependency documentation generation
/// 4. **Testing Utilities**: Container validation for unit tests
/// 5. **Performance Metrics**: Analysis of container performance characteristics
///
/// ## Generated Validation Methods
///
/// ```swift
/// extension AppContainer {
///     /// Validate container configuration at runtime
///     static func validateContainer(_ container: Container) throws {
///         try validateUserServiceProtocol(container)
///         try validateAPIClientProtocol(container)
///         try validateUserRepositoryProtocol(container)
///         // ... other validations
///     }
///     
///     /// Get dependency graph visualization
///     static func getValidationDependencyGraph() -> ValidationDependencyGraph {
///         // Generated dependency graph representation
///     }
///     
///     /// Validate specific service registration
///     private static func validateUserServiceProtocol(_ container: Container) throws {
///         guard container.resolve(UserServiceProtocol.self) != nil else {
///             throw ContainerValidationError.serviceNotRegistered("UserServiceProtocol")
///         }
///     }
/// }
/// ```
///
/// ## Testing Integration
///
/// ```swift
/// class ContainerValidationTests: XCTestCase {
///     func testContainerConfiguration() {
///         let container = AppContainer.configure()
///         
///         // Generated validation method
///         XCTAssertNoThrow(try AppContainer.validateContainer(container))
///         
///         // Test specific service resolution
///         XCTAssertNotNil(container.resolve(UserServiceProtocol.self))
///         XCTAssertNotNil(container.resolve(APIClientProtocol.self))
///     }
///     
///     func testValidationDependencyGraph() {
///         let graph = AppContainer.getValidationDependencyGraph()
///         
///         XCTAssertTrue(graph.hasService("UserServiceProtocol"))
///         XCTAssertTrue(graph.hasService("APIClientProtocol"))
///         XCTAssertFalse(graph.hasCircularDependencies)
///     }
/// }
/// ```
///
/// ## Performance Analysis
///
/// ```swift
/// @ValidatedContainer(analyzePerformance: true)
/// class PerformanceAnalyzedContainer {
///     static func configure() -> Container {
///         let container = Container()
///         
///         // Heavy initialization - will be flagged for optimization
///         container.register(ExpensiveService.self) { _ in
///             ExpensiveService() // Takes 2 seconds to initialize
///         }.inObjectScope(.container)
///         
///         return container
///     }
/// }
/// 
/// // Generated performance report:
/// // "ExpensiveService initialization takes 2.1s - consider lazy loading"
/// ```
///
/// ## Documentation Generation
///
/// ```swift
/// @ValidatedContainer(generateDocumentation: true)
/// class DocumentedContainer {
///     /// Core application services
///     @ServiceGroup("Core")
///     static func configureCoreServices(_ container: Container) {
///         /// Manages user authentication and authorization
///         container.register(AuthServiceProtocol.self) { _ in
///             AuthService()
///         }
///         
///         /// Handles data persistence operations
///         container.register(DatabaseProtocol.self) { _ in
///             CoreDataDatabase()
///         }
///     }
/// }
/// 
/// // Generates:
/// // - Service dependency documentation
/// // - Architecture diagrams
/// // - Configuration guides
/// ```
///
/// ## Requirements:
/// - Container must be configured in a static method
/// - All service registrations should be analyzable at compile time
/// - Dependencies should use protocol types for best validation
/// - Method must return a configured Container instance
///
/// ## Parameters:
/// - `strictMode`: Enable strict validation rules (default: false)
/// - `validateScopes`: Validate object scope configurations (default: true)
/// - `checkCircularDependencies`: Detect circular dependencies (default: true)
/// - `requireDocumentation`: Require documentation for services (default: false)
/// - `analyzePerformance`: Analyze container performance (default: false)
/// - `generateDocumentation`: Generate service documentation (default: false)
///
/// ## Validation Errors:
/// The macro provides clear compile-time errors for common issues:
/// - Missing service registrations
/// - Circular dependencies
/// - Invalid scope configurations
/// - Missing documentation (if required)
/// - Performance bottlenecks (if analysis enabled)
@attached(peer, names: arbitrary)
public macro ValidatedContainer(
    strictMode: Bool = false,
    validateScopes: Bool = true,
    checkCircularDependencies: Bool = true,
    requireDocumentation: Bool = false,
    analyzePerformance: Bool = false,
    generateDocumentation: Bool = false
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "ValidatedContainerMacro")

// MARK: - Dependency Group Annotation

/// Groups related service registrations for better organization and validation.
@attached(peer, names: arbitrary)
public macro DependencyGroup(
    _ name: String,
    priority: Int = 0,
    dependencies: [String] = []
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "DependencyGroupMacro")

// MARK: - Service Group Annotation

/// Annotates service registration methods for documentation and validation.
@attached(peer, names: arbitrary)  
public macro ServiceGroup(
    _ name: String,
    description: String = ""
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "ServiceGroupMacro")

// MARK: - Container Validation Types

/// Represents the validation dependency graph of a container
public struct ValidationDependencyGraph {
    public let services: Set<String>
    public let dependencies: [String: Set<String>]
    public let hasCircularDependencies: Bool
    
    public init(services: Set<String>, dependencies: [String: Set<String>]) {
        self.services = services
        self.dependencies = dependencies
        self.hasCircularDependencies = Self.detectCircularDependencies(dependencies)
    }
    
    /// Check if a service is registered in the graph
    public func hasService(_ serviceName: String) -> Bool {
        return services.contains(serviceName)
    }
    
    /// Get dependencies for a specific service
    public func getDependencies(for service: String) -> Set<String> {
        return dependencies[service] ?? []
    }
    
    /// Detect circular dependencies in the graph
    private static func detectCircularDependencies(_ dependencies: [String: Set<String>]) -> Bool {
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        
        for service in dependencies.keys {
            if !visited.contains(service) {
                if hasCycle(service, dependencies, &visited, &recursionStack) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private static func hasCycle(
        _ service: String,
        _ dependencies: [String: Set<String>],
        _ visited: inout Set<String>,
        _ recursionStack: inout Set<String>
    ) -> Bool {
        visited.insert(service)
        recursionStack.insert(service)
        
        for dependency in dependencies[service] ?? [] {
            if !visited.contains(dependency) {
                if hasCycle(dependency, dependencies, &visited, &recursionStack) {
                    return true
                }
            } else if recursionStack.contains(dependency) {
                return true
            }
        }
        
        recursionStack.remove(service)
        return false
    }
}

/// Errors that can occur during container validation
public enum ContainerValidationError: Error, LocalizedError {
    case serviceNotRegistered(String)
    case circularDependencyDetected(String)
    case invalidScopeConfiguration(String)
    case missingDocumentation(String)
    case performanceIssue(String, suggestion: String)
    
    public var errorDescription: String? {
        switch self {
        case .serviceNotRegistered(let service):
            return "Service '\(service)' is not registered in the container"
        case .circularDependencyDetected(let cycle):
            return "Circular dependency detected: \(cycle)"
        case .invalidScopeConfiguration(let issue):
            return "Invalid scope configuration: \(issue)"
        case .missingDocumentation(let service):
            return "Missing documentation for service '\(service)'"
        case .performanceIssue(let issue, let suggestion):
            return "Performance issue: \(issue). Suggestion: \(suggestion)"
        }
    }
}

// MARK: - Container Analysis Utilities

/// Utilities for analyzing container configurations
public enum ContainerAnalyzer {
    
    /// Analyze a container and return validation results
    public static func analyze(_ container: Container) -> ContainerAnalysisResult {
        // Implementation would analyze the container
        // This is a placeholder for the actual analysis logic
        return ContainerAnalysisResult(
            registeredServices: [],
            missingDependencies: [],
            circularDependencies: [],
            performanceIssues: []
        )
    }
    
    /// Generate a dependency graph from container configuration
    public static func generateValidationDependencyGraph(_ container: Container) -> ValidationDependencyGraph {
        // Implementation would generate the graph
        // This is a placeholder for the actual graph generation logic
        return ValidationDependencyGraph(services: [], dependencies: [:])
    }
}

/// Result of container analysis
public struct ContainerAnalysisResult {
    public let registeredServices: [String]
    public let missingDependencies: [String]
    public let circularDependencies: [String]
    public let performanceIssues: [String]
    
    public var isValid: Bool {
        return missingDependencies.isEmpty && circularDependencies.isEmpty
    }
    
    public var hasPerformanceIssues: Bool {
        return !performanceIssues.isEmpty
    }
}