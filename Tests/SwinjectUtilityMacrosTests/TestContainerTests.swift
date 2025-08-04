// TestContainerTests.swift - Tests for @TestContainer macro

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import SwinjectUtilityMacros
@testable import SwinjectUtilityMacrosImplementation
import XCTest

final class TestContainerTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "TestContainer": TestContainerMacro.self
    ]

    func testBasicTestContainerExpansion() throws {
        assertMacroExpansion(
            """
            @TestContainer
            class UserServiceTests {
                var userRepository: UserRepository!
                var apiClient: APIClient!
            }
            """,
            expandedSource: """
            @TestContainer
            class UserServiceTests {
                var userRepository: UserRepository!
                var apiClient: APIClient!

                func setupTestContainer() -> Container {
                    let container = Container()
                    registerAPIClient(mock: MockAPIClient())
                    registerUserRepository(mock: MockUserRepository())
                    return container
                }

                func registerAPIClient(mock: APIClient) {
                    container.register(APIClient.self) { _ in mock }.inObjectScope(.graph)
                }

                func registerUserRepository(mock: UserRepository) {
                    container.register(UserRepository.self) { _ in mock }.inObjectScope(.graph)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testTestContainerMacroRegistration() {
        // Verify the macro is properly registered in the plugin
        let plugin = SwinjectUtilityMacrosPlugin()
        let macroTypes = plugin.providingMacros

        XCTAssertTrue(macroTypes.contains { $0 == TestContainerMacro.self })
    }

    func testTestContainerErrorCases() throws {
        // Test that macro reports errors for invalid usage (applied to enum)
        assertMacroExpansion(
            """
            @TestContainer
            enum InvalidTarget {
                case test
            }
            """,
            expandedSource: """
            @TestContainer
            enum InvalidTarget {
                case test
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@TestContainer can only be applied to classes or structs", line: 1, column: 1, severity: .error)
            ],
            macros: testMacros
        )
    }

    func testTestContainerWithAutoMocking() throws {
        assertMacroExpansion(
            """
            @TestContainer(autoMock: true)
            class TestCase {
                var service: DatabaseService!
                var client: NetworkClient!
            }
            """,
            expandedSource: """
            @TestContainer(autoMock: true)
            class TestCase {
                var service: DatabaseService!
                var client: NetworkClient!

                func setupTestContainer() -> Container {
                    let container = Container()
                    registerDatabaseService(mock: MockDatabaseService())
                    registerNetworkClient(mock: MockNetworkClient())
                    return container
                }

                func registerDatabaseService(mock: DatabaseService) {
                    container.register(DatabaseService.self) { _ in mock }.inObjectScope(.graph)
                }

                func registerNetworkClient(mock: NetworkClient) {
                    container.register(NetworkClient.self) { _ in mock }.inObjectScope(.graph)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testTestContainerWithCustomMockPrefix() throws {
        assertMacroExpansion(
            """
            @TestContainer(mockPrefix: "Stub")
            class StubTests {
                var repository: UserRepository!
            }
            """,
            expandedSource: """
            @TestContainer(mockPrefix: "Stub")
            class StubTests {
                var repository: UserRepository!

                func setupTestContainer() -> Container {
                    let container = Container()
                    registerUserRepository(mock: StubUserRepository())
                    return container
                }

                func registerUserRepository(mock: UserRepository) {
                    container.register(UserRepository.self) { _ in mock }.inObjectScope(.graph)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testTestContainerWithSpyGeneration() throws {
        assertMacroExpansion(
            """
            @TestContainer(generateSpies: true)
            class SpyTests {
                var service: LoggingService!
            }
            """,
            expandedSource: """
            @TestContainer(generateSpies: true)
            class SpyTests {
                var service: LoggingService!

                func setupTestContainer() -> Container {
                    let container = Container()
                    registerLoggingService(mock: MockLoggingService())
                    return container
                }

                func registerLoggingService(mock: LoggingService) {
                    container.register(LoggingService.self) { _ in mock }.inObjectScope(.graph)
                }

                func createLoggingServiceSpy() -> LoggingServiceSpy {
                    return LoggingServiceSpy()
                }
            }
            """,
            macros: testMacros
        )
    }
}
