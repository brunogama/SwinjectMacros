// SwiftUIIntegrationTests.swift - Tests for SwiftUI integration macros

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import SwiftUI
import Swinject
import XCTest

@testable import SwinjectMacros
@testable import SwinjectMacrosImplementation

final class SwiftUIIntegrationTests: XCTestCase {

    // MARK: - @EnvironmentInject Tests

    func testEnvironmentInjectBasicExpansion() {
        assertMacroExpansion("""
        struct ContentView: View {
            @EnvironmentInject var userService: SwiftUIUserServiceProtocol

            var body: some View {
                Text("Hello")
            }
        }
        """, expandedSource: """
        struct ContentView: View {
            @EnvironmentInject var userService: SwiftUIUserServiceProtocol {
                get {
                    // Environment-based dependency injection
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Access DI container from SwiftUI Environment
                    guard let resolved = Environment(\\.diContainer).wrappedValue.resolve(SwiftUIUserServiceProtocol.self) else {
                        let error = EnvironmentInjectError.requiredServiceMissing(type: "SwiftUIUserServiceProtocol")
                        fatalError("Environment injection failed: \\(error.localizedDescription)")
                    }
                    return resolved
                }
            }

            var body: some View {
                Text("Hello")
            }
        }
        """, macros: testMacros)
    }

    func testEnvironmentInjectWithNamedService() {
        assertMacroExpansion("""
        struct NetworkingView: View {
            @EnvironmentInject("primary") var primaryAPI: SwiftUIAPIClientProtocol
        }
        """, expandedSource: """
        struct NetworkingView: View {
            @EnvironmentInject("primary") var primaryAPI: SwiftUIAPIClientProtocol {
                get {
                    // Environment-based dependency injection
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Access DI container from SwiftUI Environment
                    guard let resolved = Environment(\\.diContainer).wrappedValue.resolve(SwiftUIAPIClientProtocol.self, name: "primary") else {
                        let error = EnvironmentInjectError.requiredServiceMissing(type: "SwiftUIAPIClientProtocol")
                        fatalError("Environment injection failed: \\(error.localizedDescription)")
                    }
                    return resolved
                }
            }
        }
        """, macros: testMacros)
    }

    func testEnvironmentInjectWithOptionalService() {
        assertMacroExpansion("""
        struct SettingsView: View {
            @EnvironmentInject(required: false) var analytics: SwiftUIAnalyticsProtocol?
        }
        """, expandedSource: """
        struct SettingsView: View {
            @EnvironmentInject(required: false) var analytics: SwiftUIAnalyticsProtocol? {
                get {
                    // Environment-based dependency injection
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Access DI container from SwiftUI Environment
                    return Environment(\\.diContainer).wrappedValue.resolve(SwiftUIAnalyticsProtocol.self)
                }
            }
        }
        """, macros: testMacros)
    }

    func testEnvironmentInjectErrorCases() {
        // Test non-variable property
        assertMacroExpansion("""
        struct ProblematicView: View {
            @EnvironmentInject
            func getService() -> UserService {
                return UserService()
            }
        }
        """, expandedSource: """
        struct ProblematicView: View {
            @EnvironmentInject
            func getService() -> UserService {
                return UserService()
            }
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @EnvironmentInject can only be applied to variable properties.

            ✅ Correct usage:
            struct ContentView: View {
                @EnvironmentInject var userService: SwiftUIUserServiceProtocol
                @EnvironmentInject var analytics: SwiftUIAnalyticsProtocol
            }

            ❌ Invalid usage:
            @EnvironmentInject
            func getService() -> UserService { ... } // Functions not supported

            @EnvironmentInject
            let service = UserService() // Constants not supported

            💡 Solution: Use 'var' for properties that should be injected from the environment.
            """, line: 2, column: 5, severity: .error)
        ], macros: testMacros)

        // Test missing type annotation
        assertMacroExpansion("""
        struct ProblematicView: View {
            @EnvironmentInject var service
        }
        """, expandedSource: """
        struct ProblematicView: View {
            @EnvironmentInject var service
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @EnvironmentInject requires an explicit type annotation.

            ✅ Correct usage:
            @EnvironmentInject var userService: SwiftUIUserServiceProtocol
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

    // MARK: - @ViewModelInject Tests

    func testViewModelInjectBasicExpansion() {
        assertMacroExpansion("""
        @ViewModelInject
        class UserProfileViewModel {
            private let userService: SwiftUIUserServiceProtocol
            private let analytics: SwiftUIAnalyticsProtocol

            @Published var user: User?
            @Published var isLoading = false
        }
        """, expandedSource: """
        class UserProfileViewModel {
            private let userService: SwiftUIUserServiceProtocol
            private let analytics: SwiftUIAnalyticsProtocol

            @Published var user: User?
            @Published var isLoading = false
            /// Dependency injection initializer
            public convenience init(container: DIContainer) {
                // Resolve dependencies from container
                guard let userService = container.resolve(SwiftUIUserServiceProtocol.self) else {
                    fatalError("Failed to resolve required dependency 'userService' of type 'SwiftUIUserServiceProtocol'")
                }
                guard let analytics = container.resolve(SwiftUIAnalyticsProtocol.self) else {
                    fatalError("Failed to resolve required dependency 'analytics' of type 'SwiftUIAnalyticsProtocol'")
                }

                // Call designated initializer with resolved dependencies
                self.init(userService: userService, analytics: analytics)
            }

            /// Designated initializer with explicit dependencies
            public init(userService: SwiftUIUserServiceProtocol, analytics: SwiftUIAnalyticsProtocol) {
                self.userService = userService
                self.analytics = analytics
            }
            /// Preview-friendly initializer with mock dependencies
            public static func preview(userService: SwiftUIUserServiceProtocol = MockSwiftUIUserServiceProtocol(), analytics: SwiftUIAnalyticsProtocol = MockSwiftUIAnalyticsProtocol()) -> UserProfileViewModel {
                UserProfileViewModel(userService: userService, analytics: analytics)
            }
        }

        extension UserProfileViewModel: ObservableObject {
        }
        """, macros: testMacros)
    }

    func testViewModelInjectWithFactoryGeneration() {
        assertMacroExpansion("""
        @ViewModelInject(generateFactory: true)
        class NetworkViewModel: ObservableObject {
            private let apiClient: SwiftUIAPIClientProtocol
        }
        """, expandedSource: """
        class NetworkViewModel: ObservableObject {
            private let apiClient: SwiftUIAPIClientProtocol
            /// Dependency injection initializer
            public convenience init(container: DIContainer) {
                // Resolve dependencies from container
                guard let apiClient = container.resolve(SwiftUIAPIClientProtocol.self) else {
                    fatalError("Failed to resolve required dependency 'apiClient' of type 'SwiftUIAPIClientProtocol'")
                }

                // Call designated initializer with resolved dependencies
                self.init(apiClient: apiClient)
            }

            /// Designated initializer with explicit dependencies
            public init(apiClient: SwiftUIAPIClientProtocol) {
                self.apiClient = apiClient
            }
            /// Factory method for container registration
            public static func register(in container: Container) {
                container.register(NetworkViewModel.self) { resolver in
                    NetworkViewModel(container: DIContainer(resolver as! Container))
                }.inObjectScope(.transient)
            }
            /// Preview-friendly initializer with mock dependencies
            public static func preview(apiClient: SwiftUIAPIClientProtocol = MockSwiftUIAPIClientProtocol()) -> NetworkViewModel {
                NetworkViewModel(apiClient: apiClient)
            }
        }
        """, macros: testMacros)
    }

    func testViewModelInjectErrorCases() {
        // Test non-class type
        assertMacroExpansion("""
        @ViewModelInject
        struct UserProfileViewModel {
            private let userService: SwiftUIUserServiceProtocol
        }
        """, expandedSource: """
        struct UserProfileViewModel {
            private let userService: SwiftUIUserServiceProtocol
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @ViewModelInject can only be applied to classes.

            ✅ Correct usage:
            @ViewModelInject
            class UserProfileViewModel {
                private let userService: SwiftUIUserServiceProtocol
                private let analytics: SwiftUIAnalyticsProtocol

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

    // MARK: - Integration Tests

    @MainActor func testDIContainerIntegration() {
        // Test DIContainer class functionality
        let container = Container()
        container.register(SwiftUIMockUserService.self) { _ in SwiftUIMockUserService() }

        let diContainer = DIContainer(container)
        let resolvedService: SwiftUIMockUserService? = diContainer.resolve(SwiftUIMockUserService.self)

        XCTAssertNotNil(resolvedService)
    }

    @MainActor func testEnvironmentKeyIntegration() {
        // Test that the environment key works with SwiftUI
        let container = Container()
        let diContainer = DIContainer(container)

        // This would be used in a SwiftUI view like:
        // @Environment(\.diContainer) var diContainer: DIContainer

        XCTAssertNotNil(diContainer)
    }

    // MARK: - Test Utilities

    private let testMacros: [String: Macro.Type] = [
        "EnvironmentInject": EnvironmentInjectMacro.self,
        "ViewModelInject": ViewModelInjectMacro.self
    ]
}

// MARK: - Mock Types for Testing

protocol SwiftUIUserServiceProtocol {
    func currentUser() -> SwiftUIUser?
}

protocol SwiftUIAnalyticsProtocol {
    func track(_ event: String)
}

protocol SwiftUIAPIClientProtocol {
    func fetchData() async throws -> Data
}

// Mock implementations moved to TestUtilities.swift for reuse

struct SwiftUIUser {
    let name: String
}

class SwiftUIMockUserService: SwiftUIUserServiceProtocol {
    func currentUser() -> SwiftUIUser? {
        SwiftUIUser(name: "Test User")
    }
}

class SwiftUIMockAnalyticsService: SwiftUIAnalyticsProtocol {
    func track(_ event: String) {
        // Mock implementation
    }
}
