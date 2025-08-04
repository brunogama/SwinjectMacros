// InjectableTests.swift - Tests for @Injectable macro

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import SwinjectUtilityMacros
@testable import SwinjectUtilityMacrosImplementation
import XCTest

final class InjectableTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "Injectable": InjectableMacro.self
    ]

    func testBasicInjectableExpansion() throws {
        assertMacroExpansion(
            """
            @Injectable
            class UserService {
                init(apiClient: APIClient, database: Database) {}
            }
            """,
            expandedSource: """
            class UserService {
                init(apiClient: APIClient, database: Database) {}

                static func register(in container: Container) {
                    container.register(UserService.self) { resolver in
                        UserService(
                            apiClient: resolver.synchronizedResolve(APIClient.self)!,
                            database: resolver.synchronizedResolve(Database.self)!
                        )
                    }.inObjectScope(.graph)
                }
            }

            extension UserService: Injectable {
            }
            """,
            macros: testMacros
        )
    }

    func testInjectableWithOptionalDependencies() throws {
        assertMacroExpansion(
            """
            @Injectable
            class OptionalService {
                init(required: RequiredService, optional: OptionalService?) {}
            }
            """,
            expandedSource: """
            class OptionalService {
                init(required: RequiredService, optional: OptionalService?) {}

                static func register(in container: Container) {
                    container.register(OptionalService.self) { resolver in
                        OptionalService(
                            required: resolver.synchronizedResolve(RequiredService.self)!,
                            optional: resolver.synchronizedResolve(OptionalService?.self)
                        )
                    }.inObjectScope(.graph)
                }
            }

            extension OptionalService: Injectable {
            }
            """,
            macros: testMacros
        )
    }

    func testInjectableWithGenericTypes() throws {
        assertMacroExpansion(
            """
            @Injectable
            class GenericService<T> {
                init(provider: Provider<T>, logger: LoggerProtocol) {}
            }
            """,
            expandedSource: """
            class GenericService<T> {
                init(provider: Provider<T>, logger: LoggerProtocol) {}

                static func register(in container: Container) {
                    container.register(GenericService.self) { resolver in
                        GenericService(
                            provider: resolver.synchronizedResolve(Provider<T>.self)!,
                            logger: resolver.synchronizedResolve(LoggerProtocol.self)!
                        )
                    }.inObjectScope(.graph)
                }
            }

            extension GenericService: Injectable {
            }
            """,
            macros: testMacros
        )
    }

    func testInjectableWithCustomScope() throws {
        assertMacroExpansion(
            """
            @Injectable(scope: .container)
            class SingletonService {
                init() {}
            }
            """,
            expandedSource: """
            class SingletonService {
                init() {}

                static func register(in container: Container) {
                    container.register(SingletonService.self) { resolver in
                        SingletonService()
                    }.inObjectScope(.container)
                }
            }

            extension SingletonService: Injectable {
            }
            """,
            macros: testMacros
        )
    }

    func testInjectableWithNamedService() throws {
        assertMacroExpansion(
            """
            @Injectable(name: "primary")
            class NamedService {
                init(dependency: SomeDependency) {}
            }
            """,
            expandedSource: """
            class NamedService {
                init(dependency: SomeDependency) {}

                static func register(in container: Container) {
                    container.register(NamedService.self, name: "primary") { resolver in
                        NamedService(
                            dependency: resolver.synchronizedResolve(SomeDependency.self)!
                        )
                    }.inObjectScope(.graph)
                }
            }

            extension NamedService: Injectable {
            }
            """,
            macros: testMacros
        )
    }

    func testInjectableErrorCases() throws {
        assertMacroExpansion(
            """
            @Injectable
            class NoInitializerService {
                let property: String = "test"
            }
            """,
            expandedSource: """
            class NoInitializerService {
                let property: String = "test"
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Injectable requires a class or struct with at least one initializer.",
                    line: 1,
                    column: 1,
                    severity: .error
                )
            ],
            macros: testMacros
        )
    }
}
