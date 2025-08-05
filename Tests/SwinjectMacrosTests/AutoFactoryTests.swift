// AutoFactoryTests.swift - Tests for @AutoFactory macro

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import SwinjectMacros
@testable import SwinjectMacrosImplementation
import XCTest

final class AutoFactoryTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "AutoFactory": AutoFactoryMacro.self
    ]

    func testBasicAutoFactoryExpansion() throws {
        assertMacroExpansion(
            """
            @AutoFactory
            class DocumentService {
                init(repository: DocumentRepository, fileName: String) {}
            }
            """,
            expandedSource: """
            @AutoFactory
            class DocumentService {
                init(repository: DocumentRepository, fileName: String) {}
            }

            protocol DocumentServiceFactory {
                func makeDocumentService(fileName: String) -> DocumentService
            }

            class DocumentServiceFactoryImpl: DocumentServiceFactory {
                private let container: Container

                init(container: Container) {
                    self.container = container
                }

                func makeDocumentService(fileName: String) -> DocumentService {
                    return DocumentService(
                        repository: container.synchronizedResolve(DocumentRepository.self)!,
                        fileName: fileName
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testAutoFactoryMacroRegistration() {
        // Verify the macro is properly registered in the plugin
        let plugin = SwinjectUtilityMacrosPlugin()
        let macroTypes = plugin.providingMacros

        XCTAssertTrue(macroTypes.contains { $0 == AutoFactoryMacro.self })
    }

    func testAutoFactoryErrorCases() throws {
        // Test that macro reports errors for invalid usage (no initializer)
        assertMacroExpansion(
            """
            @AutoFactory
            class InvalidService {
                let property: String = "test"
            }
            """,
            expandedSource: """
            @AutoFactory
            class InvalidService {
                let property: String = "test"
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@AutoFactory requires a class or struct with an initializer",
                    line: 1,
                    column: 1,
                    severity: .error
                )
            ],
            macros: testMacros
        )
    }

    func testAutoFactoryWithRuntimeParameters() throws {
        assertMacroExpansion(
            """
            @AutoFactory
            class UserService {
                init(repository: UserRepository, database: DatabaseService, userId: String, isAdmin: Bool) {}
            }
            """,
            expandedSource: """
            @AutoFactory
            class UserService {
                init(repository: UserRepository, database: DatabaseService, userId: String, isAdmin: Bool) {}
            }

            protocol UserServiceFactory {
                func makeUserService(userId: String, isAdmin: Bool) -> UserService
            }

            class UserServiceFactoryImpl: UserServiceFactory {
                private let container: Container

                init(container: Container) {
                    self.container = container
                }

                func makeUserService(userId: String, isAdmin: Bool) -> UserService {
                    return UserService(
                        repository: container.synchronizedResolve(UserRepository.self)!,
                        database: container.synchronizedResolve(DatabaseService.self)!,
                        userId: userId,
                        isAdmin: isAdmin
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testAutoFactoryWithAsyncSupport() throws {
        assertMacroExpansion(
            """
            @AutoFactory(async: true)
            class AsyncService {
                init(client: APIClient, endpoint: String) async {}
            }
            """,
            expandedSource: """
            @AutoFactory(async: true)
            class AsyncService {
                init(client: APIClient, endpoint: String) async {}
            }

            protocol AsyncServiceFactory {
                func makeAsyncService(endpoint: String) async -> AsyncService
            }

            class AsyncServiceFactoryImpl: AsyncServiceFactory {
                private let container: Container

                init(container: Container) {
                    self.container = container
                }

                func makeAsyncService(endpoint: String) async -> AsyncService {
                    return await AsyncService(
                        client: container.synchronizedResolve(APIClient.self)!,
                        endpoint: endpoint
                    )
                }
            }
            """,
            macros: testMacros
        )
    }

    func testAutoFactoryWithThrowingSupport() throws {
        assertMacroExpansion(
            """
            @AutoFactory(throws: true)
            class ThrowingService {
                init(validator: ValidationService, data: String) throws {}
            }
            """,
            expandedSource: """
            @AutoFactory(throws: true)
            class ThrowingService {
                init(validator: ValidationService, data: String) throws {}
            }

            protocol ThrowingServiceFactory {
                func makeThrowingService(data: String) throws -> ThrowingService
            }

            class ThrowingServiceFactoryImpl: ThrowingServiceFactory {
                private let container: Container

                init(container: Container) {
                    self.container = container
                }

                func makeThrowingService(data: String) throws -> ThrowingService {
                    return try ThrowingService(
                        validator: container.synchronizedResolve(ValidationService.self)!,
                        data: data
                    )
                }
            }
            """,
            macros: testMacros
        )
    }
}
