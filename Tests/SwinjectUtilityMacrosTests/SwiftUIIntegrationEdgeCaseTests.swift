// SwiftUIIntegrationEdgeCaseTests.swift - Comprehensive edge case tests for SwiftUI integration macros

import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

@testable import SwinjectUtilityMacrosImplementation

final class SwiftUIIntegrationEdgeCaseTests: XCTestCase {
    
    // MARK: - @EnvironmentInject Edge Cases
    
    func testEnvironmentInjectOnFunction() {
        assertMacroExpansion("""
        @EnvironmentInject
        func getUserService() -> UserService {
            return UserService()
        }
        """, expandedSource: """
        func getUserService() -> UserService {
            return UserService()
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @EnvironmentInject can only be applied to variable properties.
            
            ✅ Correct usage:
            struct ContentView: View {
                @EnvironmentInject var userService: UserServiceProtocol
                @EnvironmentInject var analytics: AnalyticsProtocol
            }
            
            ❌ Invalid usage:
            @EnvironmentInject
            func getUserService() -> UserService { ... } // Functions not supported
            
            @EnvironmentInject
            let service = UserService() // Constants not supported
            
            💡 Solution: Use 'var' for properties that should be injected from the environment.
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }
    
    func testEnvironmentInjectOnComputedProperty() {
        assertMacroExpansion("""
        struct ContentView: View {
            @EnvironmentInject var userService: UserService {
                get { UserService() }
                set { }
            }
        }
        """, expandedSource: """
        struct ContentView: View {
            @EnvironmentInject var userService: UserService {
                get { UserService() }
                set { }
            }
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @EnvironmentInject can only be applied to stored properties, not computed properties.
            
            ✅ Correct usage (stored property):
            @EnvironmentInject var userService: UserServiceProtocol
            
            ❌ Invalid usage (computed property):
            @EnvironmentInject var userService: UserServiceProtocol {
                get { ... }
                set { ... }
            }
            
            💡 Solution: Remove the getter/setter and let @EnvironmentInject handle property access.
            """, line: 2, column: 5, severity: .error)
        ], macros: testMacros)
    }
    
    func testEnvironmentInjectWithoutTypeAnnotation() {
        assertMacroExpansion("""
        struct ContentView: View {
            @EnvironmentInject var userService
        }
        """, expandedSource: """
        struct ContentView: View {
            @EnvironmentInject var userService
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @EnvironmentInject requires an explicit type annotation.
            
            ✅ Correct usage:
            @EnvironmentInject var userService: UserServiceProtocol
            @EnvironmentInject var analytics: AnalyticsService
            @EnvironmentInject var optionalService: OptionalService?
            
            ❌ Invalid usage:
            @EnvironmentInject var userService // Missing type annotation
            @EnvironmentInject var service = SomeService() // Type inferred from assignment
            
            💡 Tips:
            - Always provide explicit type annotations for injected properties
            - Use protocols for better testability and flexibility
            - Mark as optional (T?) if the service might not be available
            """, line: 2, column: 5, severity: .error)
        ], macros: testMacros)
    }
    
    func testEnvironmentInjectBasicExpansion() {
        assertMacroExpansion("""
        struct ContentView: View {
            @EnvironmentInject var userService: UserServiceProtocol
        }
        """, expandedSource: """
        struct ContentView: View {
            var userService: UserServiceProtocol {
                get {
                    // Environment-based dependency injection
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    // Access DI container from SwiftUI Environment
                    guard let resolved = Environment(\\EnvironmentValues\\.diContainer).wrappedValue.resolve(UserServiceProtocol.self) else {
                        let error = EnvironmentInjectError.requiredServiceMissing(type: "UserServiceProtocol")
                        fatalError("Environment injection failed: \\(error.localizedDescription)")
                    }
                    return resolved
                }
            }
        }
        """, macros: testMacros)
    }
    
    func testEnvironmentInjectWithOptionalType() {
        assertMacroExpansion("""
        struct ContentView: View {
            @EnvironmentInject var optionalService: OptionalService?
        }
        """, expandedSource: """
        struct ContentView: View {
            var optionalService: OptionalService? {
                get {
                    // Environment-based dependency injection
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    // Access DI container from SwiftUI Environment
                    return Environment(\\EnvironmentValues\\.diContainer).wrappedValue.resolve(OptionalService.self)
                }
            }
        }
        """, macros: testMacros)
    }
    
    func testEnvironmentInjectWithServiceName() {
        assertMacroExpansion("""
        struct ContentView: View {
            @EnvironmentInject("database") var userService: UserServiceProtocol
        }
        """, expandedSource: """
        struct ContentView: View {
            var userService: UserServiceProtocol {
                get {
                    // Environment-based dependency injection
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    // Access DI container from SwiftUI Environment
                    guard let resolved = Environment(\\EnvironmentValues\\.diContainer).wrappedValue.resolve(UserServiceProtocol.self, name: "database") else {
                        let error = EnvironmentInjectError.requiredServiceMissing(type: "UserServiceProtocol")
                        fatalError("Environment injection failed: \\(error.localizedDescription)")
                    }
                    return resolved
                }
            }
        }
        """, macros: testMacros)
    }
    
    func testEnvironmentInjectWithCustomContainer() {
        assertMacroExpansion("""
        struct ContentView: View {
            @EnvironmentInject(container: \\.customContainer) var userService: UserServiceProtocol
        }
        """, expandedSource: """
        struct ContentView: View {
            var userService: UserServiceProtocol {
                get {
                    // Environment-based dependency injection
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    // Access DI container from SwiftUI Environment
                    guard let resolved = Environment(\\EnvironmentValues\\.customContainer).wrappedValue.resolve(UserServiceProtocol.self) else {
                        let error = EnvironmentInjectError.requiredServiceMissing(type: "UserServiceProtocol")
                        fatalError("Environment injection failed: \\(error.localizedDescription)")
                    }
                    return resolved
                }
            }
        }
        """, macros: testMacros)
    }
    
    // MARK: - @ViewModelInject Edge Cases
    
    func testViewModelInjectOnStruct() {
        assertMacroExpansion("""
        @ViewModelInject
        struct UserProfileViewModel {
            @Published var user: User?
        }
        """, expandedSource: """
        struct UserProfileViewModel {
            @Published var user: User?
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @ViewModelInject can only be applied to classes.
            
            ✅ Correct usage:
            @ViewModelInject
            class UserProfileViewModel {
                private let userService: UserServiceProtocol
                private let analytics: AnalyticsProtocol
                
                @Published var user: User?
                @Published var isLoading = false
            }
            
            ❌ Invalid usage:
            @ViewModelInject
            struct UserProfileViewModel { ... } // Structs not supported
            
            @ViewModelInject
            protocol ViewModelProtocol { ... } // Protocols not supported
            
            💡 Tip: ViewModels should be classes to work with SwiftUI's ObservableObject.
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }
    
    func testViewModelInjectOnProtocol() {
        assertMacroExpansion("""
        @ViewModelInject
        protocol ViewModelProtocol {
            var user: User? { get }
        }
        """, expandedSource: """
        protocol ViewModelProtocol {
            var user: User? { get }
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @ViewModelInject can only be applied to classes.
            
            ✅ Correct usage:
            @ViewModelInject
            class UserProfileViewModel {
                private let userService: UserServiceProtocol
                private let analytics: AnalyticsProtocol
                
                @Published var user: User?
                @Published var isLoading = false
            }
            
            ❌ Invalid usage:
            @ViewModelInject
            struct UserProfileViewModel { ... } // Structs not supported
            
            @ViewModelInject
            protocol ViewModelProtocol { ... } // Protocols not supported
            
            💡 Tip: ViewModels should be classes to work with SwiftUI's ObservableObject.
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }
    
    func testViewModelInjectBasicExpansion() {
        assertMacroExpansion("""
        @ViewModelInject
        class UserProfileViewModel {
            private let userService: UserServiceProtocol
            private let analytics: AnalyticsProtocol
            
            @Published var user: User?
            @Published var isLoading = false
        }
        """, expandedSource: """
        class UserProfileViewModel {
            private let userService: UserServiceProtocol
            private let analytics: AnalyticsProtocol
            
            @Published var user: User?
            @Published var isLoading = false
            
            /// Dependency injection initializer
            public convenience init(container: DIContainer) {
                // Resolve dependencies from container
                guard let userService = container.resolve(UserServiceProtocol.self) else {
                    fatalError("Failed to resolve required dependency 'userService' of type 'UserServiceProtocol'")
                }
                guard let analytics = container.resolve(AnalyticsProtocol.self) else {
                    fatalError("Failed to resolve required dependency 'analytics' of type 'AnalyticsProtocol'")
                }
                
                // Call designated initializer with resolved dependencies
                self.init(userService: userService, analytics: analytics)
            }
            
            /// Designated initializer with explicit dependencies
            public init(userService: UserServiceProtocol, analytics: AnalyticsProtocol) {
                self.userService = userService
                self.analytics = analytics
            }
        }

        extension UserProfileViewModel: ObservableObject {
        }
        """, macros: testMacros)
    }
    
    func testViewModelInjectWithOptionalDependencies() {
        assertMacroExpansion("""
        @ViewModelInject
        class UserProfileViewModel {
            private let userService: UserServiceProtocol
            private let analytics: AnalyticsProtocol?
            
            @Published var user: User?
        }
        """, expandedSource: """
        class UserProfileViewModel {
            private let userService: UserServiceProtocol
            private let analytics: AnalyticsProtocol?
            
            @Published var user: User?
            
            /// Dependency injection initializer
            public convenience init(container: DIContainer) {
                // Resolve dependencies from container
                guard let userService = container.resolve(UserServiceProtocol.self) else {
                    fatalError("Failed to resolve required dependency 'userService' of type 'UserServiceProtocol'")
                }
                let analytics = container.resolve(AnalyticsProtocol.self)
                
                // Call designated initializer with resolved dependencies
                self.init(userService: userService, analytics: analytics)
            }
            
            /// Designated initializer with explicit dependencies
            public init(userService: UserServiceProtocol, analytics: AnalyticsProtocol?) {
                self.userService = userService
                self.analytics = analytics
            }
        }

        extension UserProfileViewModel: ObservableObject {
        }
        """, macros: testMacros)
    }
    
    func testViewModelInjectWithNamedServices() {
        assertMacroExpansion("""
        @ViewModelInject
        class UserProfileViewModel {
            @Named("database") private let userService: UserServiceProtocol
            @Service("premium") private let analytics: AnalyticsProtocol
            
            @Published var user: User?
        }
        """, expandedSource: """
        class UserProfileViewModel {
            @Named("database") private let userService: UserServiceProtocol
            @Service("premium") private let analytics: AnalyticsProtocol
            
            @Published var user: User?
            
            /// Dependency injection initializer
            public convenience init(container: DIContainer) {
                // Resolve dependencies from container
                guard let userService = container.resolve(UserServiceProtocol.self, name: "database") else {
                    fatalError("Failed to resolve required dependency 'userService' of type 'UserServiceProtocol'")
                }
                guard let analytics = container.resolve(AnalyticsProtocol.self, name: "premium") else {
                    fatalError("Failed to resolve required dependency 'analytics' of type 'AnalyticsProtocol'")
                }
                
                // Call designated initializer with resolved dependencies
                self.init(userService: userService, analytics: analytics)
            }
            
            /// Designated initializer with explicit dependencies
            public init(userService: UserServiceProtocol, analytics: AnalyticsProtocol) {
                self.userService = userService
                self.analytics = analytics
            }
        }

        extension UserProfileViewModel: ObservableObject {
        }
        """, macros: testMacros)
    }
    
    func testViewModelInjectWithFactoryGeneration() {
        assertMacroExpansion("""
        @ViewModelInject(generateFactory: true)
        class UserProfileViewModel {
            private let userService: UserServiceProtocol
            
            @Published var user: User?
        }
        """, expandedSource: """
        class UserProfileViewModel {
            private let userService: UserServiceProtocol
            
            @Published var user: User?
            
            /// Dependency injection initializer
            public convenience init(container: DIContainer) {
                // Resolve dependencies from container
                guard let userService = container.resolve(UserServiceProtocol.self) else {
                    fatalError("Failed to resolve required dependency 'userService' of type 'UserServiceProtocol'")
                }
                
                // Call designated initializer with resolved dependencies
                self.init(userService: userService)
            }
            
            /// Designated initializer with explicit dependencies
            public init(userService: UserServiceProtocol) {
                self.userService = userService
            }
            
            /// Factory method for container registration
            public static func register(in container: Container) {
                container.register(UserProfileViewModel.self) { resolver in
                    UserProfileViewModel(container: DIContainer(resolver as! Container))
                }.inObjectScope(.transient)
            }
        }

        extension UserProfileViewModel: ObservableObject {
        }
        """, macros: testMacros)
    }
    
    func testViewModelInjectWithPreviewSupport() {
        assertMacroExpansion("""
        @ViewModelInject(previewSupport: true)
        class UserProfileViewModel {
            private let userService: UserServiceProtocol
            private let analytics: AnalyticsProtocol?
            
            @Published var user: User?
        }
        """, expandedSource: """
        class UserProfileViewModel {
            private let userService: UserServiceProtocol
            private let analytics: AnalyticsProtocol?
            
            @Published var user: User?
            
            /// Dependency injection initializer
            public convenience init(container: DIContainer) {
                // Resolve dependencies from container
                guard let userService = container.resolve(UserServiceProtocol.self) else {
                    fatalError("Failed to resolve required dependency 'userService' of type 'UserServiceProtocol'")
                }
                let analytics = container.resolve(AnalyticsProtocol.self)
                
                // Call designated initializer with resolved dependencies
                self.init(userService: userService, analytics: analytics)
            }
            
            /// Designated initializer with explicit dependencies
            public init(userService: UserServiceProtocol, analytics: AnalyticsProtocol?) {
                self.userService = userService
                self.analytics = analytics
            }
            
            /// Preview-friendly initializer with mock dependencies
            public static func preview(userService: UserServiceProtocol = MockUserService(), analytics: AnalyticsProtocol? = nil) -> UserProfileViewModel {
                UserProfileViewModel(userService: userService, analytics: analytics)
            }
        }

        extension UserProfileViewModel: ObservableObject {
        }
        """, macros: testMacros)
    }
    
    func testViewModelInjectAlreadyConformsToObservableObject() {
        assertMacroExpansion("""
        @ViewModelInject
        class UserProfileViewModel: ObservableObject {
            private let userService: UserServiceProtocol
            
            @Published var user: User?
        }
        """, expandedSource: """
        class UserProfileViewModel: ObservableObject {
            private let userService: UserServiceProtocol
            
            @Published var user: User?
            
            /// Dependency injection initializer
            public convenience init(container: DIContainer) {
                // Resolve dependencies from container
                guard let userService = container.resolve(UserServiceProtocol.self) else {
                    fatalError("Failed to resolve required dependency 'userService' of type 'UserServiceProtocol'")
                }
                
                // Call designated initializer with resolved dependencies
                self.init(userService: userService)
            }
            
            /// Designated initializer with explicit dependencies
            public init(userService: UserServiceProtocol) {
                self.userService = userService
            }
        }
        """, macros: testMacros)
    }
    
    func testViewModelInjectWithNoDependencies() {
        assertMacroExpansion("""
        @ViewModelInject
        class SimpleViewModel {
            @Published var count = 0
            
            func increment() {
                count += 1
            }
        }
        """, expandedSource: """
        class SimpleViewModel {
            @Published var count = 0
            
            func increment() {
                count += 1
            }
            
            /// Dependency injection initializer
            public init(container: DIContainer) {
                // No dependencies to inject
            }
        }

        extension SimpleViewModel: ObservableObject {
        }
        """, macros: testMacros)
    }
    
    // MARK: - Complex Edge Cases
    
    func testEnvironmentInjectWithComplexGenerics() {
        assertMacroExpansion("""
        struct GenericView<T: Codable>: View {
            @EnvironmentInject var service: GenericService<T>
            
            var body: some View {
                Text("Generic View")
            }
        }
        """, expandedSource: """
        struct GenericView<T: Codable>: View {
            var service: GenericService<T> {
                get {
                    // Environment-based dependency injection
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    // Access DI container from SwiftUI Environment
                    guard let resolved = Environment(\\EnvironmentValues\\.diContainer).wrappedValue.resolve(GenericService<T>.self) else {
                        let error = EnvironmentInjectError.requiredServiceMissing(type: "GenericService<T>")
                        fatalError("Environment injection failed: \\(error.localizedDescription)")
                    }
                    return resolved
                }
            }
            
            var body: some View {
                Text("Generic View")
            }
        }
        """, macros: testMacros)
    }
    
    func testViewModelInjectWithGenericDependencies() {
        assertMacroExpansion("""
        @ViewModelInject
        class GenericViewModel<T: Codable> {
            private let repository: Repository<T>
            private let processor: DataProcessor<T, String>
            
            @Published var items: [T] = []
        }
        """, expandedSource: """
        class GenericViewModel<T: Codable> {
            private let repository: Repository<T>
            private let processor: DataProcessor<T, String>
            
            @Published var items: [T] = []
            
            /// Dependency injection initializer
            public convenience init(container: DIContainer) {
                // Resolve dependencies from container
                guard let repository = container.resolve(Repository<T>.self) else {
                    fatalError("Failed to resolve required dependency 'repository' of type 'Repository<T>'")
                }
                guard let processor = container.resolve(DataProcessor<T, String>.self) else {
                    fatalError("Failed to resolve required dependency 'processor' of type 'DataProcessor<T, String>'")
                }
                
                // Call designated initializer with resolved dependencies
                self.init(repository: repository, processor: processor)
            }
            
            /// Designated initializer with explicit dependencies
            public init(repository: Repository<T>, processor: DataProcessor<T, String>) {
                self.repository = repository
                self.processor = processor
            }
        }

        extension GenericViewModel: ObservableObject {
        }
        """, macros: testMacros)
    }
    
    // MARK: - Test Utilities
    
    private let testMacros: [String: Macro.Type] = [
        "EnvironmentInject": EnvironmentInjectMacro.self,
        "ViewModelInject": ViewModelInjectMacro.self
    ]
}

// MARK: - Supporting Test Types

protocol EdgeCaseUserServiceProtocol {}
protocol EdgeCaseAnalyticsProtocol {}
protocol EdgeCaseOptionalService {}

struct EdgeCaseUser {
    let id: String
    let name: String
}

class SwiftUIGenericService<T> {
    init() {}
}

class SwiftUIRepository<T> {
    init() {}
}

class SwiftUIDataProcessor<T, U> {
    init() {}
}

// Mock types for preview testing
class EdgeCaseMockUserService: EdgeCaseUserServiceProtocol {
    init() {}
}

// Custom attribute types for testing
struct Named {
    let name: String
    init(_ name: String) { self.name = name }
}

struct Service {
    let name: String
    init(_ name: String) { self.name = name }
}

// DIContainer wrapper for testing
struct DIContainer {
    init(_ container: Any) {}
    
    func resolve<T>(_ type: T.Type) -> T? {
        return nil
    }
    
    func resolve<T>(_ type: T.Type, name: String) -> T? {
        return nil
    }
}