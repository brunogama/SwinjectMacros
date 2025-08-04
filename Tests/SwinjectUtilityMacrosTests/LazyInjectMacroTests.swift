// LazyInjectMacroTests.swift - Tests for @LazyInject macro expansion
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwinjectUtilityMacrosImplementation

final class LazyInjectMacroTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "LazyInject": LazyInjectMacro.self
    ]

    // MARK: - Basic Functionality Tests

    func testBasicLazyInjectExpansion() throws {
        assertMacroExpansion(
            """
            class UserService {
                @LazyInject var database: DatabaseProtocol
            }
            """,
            expandedSource: """
            class UserService {
                @LazyInject var database: DatabaseProtocol

                private var _databaseBacking: DatabaseProtocol?

                private var _databaseOnceToken = pthread_once_t()

                private func _databaseLazyAccessor() -> DatabaseProtocol {
                    // Thread-safe lazy initialization
                    pthread_once(&_databaseOnceToken) {
                        let startTime = CFAbsoluteTimeGetCurrent()

                        // Register property for metrics tracking
                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "database",
                            propertyType: "DatabaseProtocol",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolving,
                            resolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(pendingInfo)

                        do {
                            // Resolve dependency
                            guard let resolved = Container.shared.synchronizedResolve(DatabaseProtocol.self) else {
                                let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "DatabaseProtocol")

                                // Record failed resolution
                                let failedInfo = LazyPropertyInfo(
                                    propertyName: "database",
                                    propertyType: "DatabaseProtocol",
                                    containerName: "default",
                                    serviceName: nil,
                                    isRequired: true,
                                    state: .failed,
                                    resolutionTime: Date(),
                                    resolutionError: error,
                                    threadInfo: ThreadInfo()
                                )
                                LazyInjectionMetrics.recordResolution(failedInfo)

                                fatalError("Required lazy property 'database' of type 'DatabaseProtocol' could not be resolved: \\(error.localizedDescription)")
                            }

                            _databaseBacking = resolved

                            // Record successful resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "database",
                                propertyType: "DatabaseProtocol",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .resolved,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(resolvedInfo)

                        } catch {
                            // Record failed resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let failedInfo = LazyPropertyInfo(
                                propertyName: "database",
                                propertyType: "DatabaseProtocol",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            if true {
                                fatalError("Failed to resolve required lazy property 'database': \\(error.localizedDescription)")
                            }
                        }
                    }

                    return _databaseBacking!
                }
            }
            """,
            macros: testMacros
        )
    }

    func testLazyInjectWithNamedService() throws {
        assertMacroExpansion(
            """
            class PaymentService {
                @LazyInject("primary") var primaryDB: DatabaseProtocol
            }
            """,
            expandedSource: """
            class PaymentService {
                @LazyInject("primary") var primaryDB: DatabaseProtocol

                private var _primaryDBBacking: DatabaseProtocol?

                private var _primaryDBOnceToken = pthread_once_t()

                private func _primaryDBLazyAccessor() -> DatabaseProtocol {
                    // Thread-safe lazy initialization
                    pthread_once(&_primaryDBOnceToken) {
                        let startTime = CFAbsoluteTimeGetCurrent()

                        // Register property for metrics tracking
                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "primaryDB",
                            propertyType: "DatabaseProtocol",
                            containerName: "default",
                            serviceName: "primary",
                            isRequired: true,
                            state: .resolving,
                            resolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(pendingInfo)

                        do {
                            // Resolve dependency
                            guard let resolved = Container.shared.synchronizedResolve(DatabaseProtocol.self, name: "primary") else {
                                let error = LazyInjectionError.serviceNotRegistered(serviceName: "primary", type: "DatabaseProtocol")

                                // Record failed resolution
                                let failedInfo = LazyPropertyInfo(
                                    propertyName: "primaryDB",
                                    propertyType: "DatabaseProtocol",
                                    containerName: "default",
                                    serviceName: "primary",
                                    isRequired: true,
                                    state: .failed,
                                    resolutionTime: Date(),
                                    resolutionError: error,
                                    threadInfo: ThreadInfo()
                                )
                                LazyInjectionMetrics.recordResolution(failedInfo)

                                fatalError("Required lazy property 'primaryDB' of type 'DatabaseProtocol' could not be resolved: \\(error.localizedDescription)")
                            }

                            _primaryDBBacking = resolved

                            // Record successful resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "primaryDB",
                                propertyType: "DatabaseProtocol",
                                containerName: "default",
                                serviceName: "primary",
                                isRequired: true,
                                state: .resolved,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(resolvedInfo)

                        } catch {
                            // Record failed resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let failedInfo = LazyPropertyInfo(
                                propertyName: "primaryDB",
                                propertyType: "DatabaseProtocol",
                                containerName: "default",
                                serviceName: "primary",
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            if true {
                                fatalError("Failed to resolve required lazy property 'primaryDB': \\(error.localizedDescription)")
                            }
                        }
                    }

                    return _primaryDBBacking!
                }
            }
            """,
            macros: testMacros
        )
    }

    func testLazyInjectWithCustomContainer() throws {
        assertMacroExpansion(
            """
            class TestService {
                @LazyInject(container: "test") var mockService: ServiceProtocol
            }
            """,
            expandedSource: """
            class TestService {
                @LazyInject(container: "test") var mockService: ServiceProtocol

                private var _mockServiceBacking: ServiceProtocol?

                private var _mockServiceOnceToken = pthread_once_t()

                private func _mockServiceLazyAccessor() -> ServiceProtocol {
                    // Thread-safe lazy initialization
                    pthread_once(&_mockServiceOnceToken) {
                        let startTime = CFAbsoluteTimeGetCurrent()

                        // Register property for metrics tracking
                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "mockService",
                            propertyType: "ServiceProtocol",
                            containerName: "test",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolving,
                            resolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(pendingInfo)

                        do {
                            // Resolve dependency
                            guard let resolved = Container.named("test").resolve(ServiceProtocol.self) else {
                                let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "ServiceProtocol")

                                // Record failed resolution
                                let failedInfo = LazyPropertyInfo(
                                    propertyName: "mockService",
                                    propertyType: "ServiceProtocol",
                                    containerName: "test",
                                    serviceName: nil,
                                    isRequired: true,
                                    state: .failed,
                                    resolutionTime: Date(),
                                    resolutionError: error,
                                    threadInfo: ThreadInfo()
                                )
                                LazyInjectionMetrics.recordResolution(failedInfo)

                                fatalError("Required lazy property 'mockService' of type 'ServiceProtocol' could not be resolved: \\(error.localizedDescription)")
                            }

                            _mockServiceBacking = resolved

                            // Record successful resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "mockService",
                                propertyType: "ServiceProtocol",
                                containerName: "test",
                                serviceName: nil,
                                isRequired: true,
                                state: .resolved,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(resolvedInfo)

                        } catch {
                            // Record failed resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let failedInfo = LazyPropertyInfo(
                                propertyName: "mockService",
                                propertyType: "ServiceProtocol",
                                containerName: "test",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            if true {
                                fatalError("Failed to resolve required lazy property 'mockService': \\(error.localizedDescription)")
                            }
                        }
                    }

                    return _mockServiceBacking!
                }
            }
            """,
            macros: testMacros
        )
    }

    func testLazyInjectOptionalService() throws {
        assertMacroExpansion(
            """
            class AnalyticsService {
                @LazyInject(required: false) var optionalTracker: TrackerProtocol?
            }
            """,
            expandedSource: """
            class AnalyticsService {
                @LazyInject(required: false) var optionalTracker: TrackerProtocol?

                private var _optionalTrackerBacking: TrackerProtocol??

                private var _optionalTrackerOnceToken = pthread_once_t()

                private func _optionalTrackerLazyAccessor() -> TrackerProtocol? {
                    // Thread-safe lazy initialization
                    pthread_once(&_optionalTrackerOnceToken) {
                        let startTime = CFAbsoluteTimeGetCurrent()

                        // Register property for metrics tracking
                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "optionalTracker",
                            propertyType: "TrackerProtocol?",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: false,
                            state: .resolving,
                            resolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(pendingInfo)

                        do {
                            // Resolve dependency
                            _optionalTrackerBacking = Container.shared.synchronizedResolve(TrackerProtocol?.self)

                            // Record successful resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "optionalTracker",
                                propertyType: "TrackerProtocol?",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: false,
                                state: .resolved,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(resolvedInfo)

                        } catch {
                            // Record failed resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let failedInfo = LazyPropertyInfo(
                                propertyName: "optionalTracker",
                                propertyType: "TrackerProtocol?",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: false,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            if false {
                                fatalError("Failed to resolve required lazy property 'optionalTracker': \\(error.localizedDescription)")
                            }
                        }
                    }

                    return _optionalTrackerBacking!
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Error Cases

    func testLazyInjectOnNonVariable() throws {
        assertMacroExpansion(
            """
            class TestClass {
                @LazyInject func testMethod() {}
            }
            """,
            expandedSource: """
            class TestClass {
                @LazyInject func testMethod() {}
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@LazyInject can only be applied to variable properties", line: 2, column: 5)
            ],
            macros: testMacros
        )
    }

    func testLazyInjectOnComputedProperty() throws {
        assertMacroExpansion(
            """
            class TestClass {
                @LazyInject var computedProp: String {
                    get { return "test" }
                }
            }
            """,
            expandedSource: """
            class TestClass {
                @LazyInject var computedProp: String {
                    get { return "test" }
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@LazyInject can only be applied to stored properties", line: 2, column: 5)
            ],
            macros: testMacros
        )
    }

    func testLazyInjectWithoutTypeAnnotation() throws {
        assertMacroExpansion(
            """
            class TestClass {
                @LazyInject var service = MyService()
            }
            """,
            expandedSource: """
            class TestClass {
                @LazyInject var service = MyService()
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@LazyInject requires an explicit type annotation", line: 2, column: 5)
            ],
            macros: testMacros
        )
    }

    // MARK: - Complex Configuration Tests

    func testLazyInjectWithAllParameters() throws {
        assertMacroExpansion(
            """
            class ComplexService {
                @LazyInject("premium", container: "production", required: true) var premiumService: PremiumServiceProtocol
            }
            """,
            expandedSource: """
            class ComplexService {
                @LazyInject("premium", container: "production", required: true) var premiumService: PremiumServiceProtocol

                private var _premiumServiceBacking: PremiumServiceProtocol?

                private var _premiumServiceOnceToken = pthread_once_t()

                private func _premiumServiceLazyAccessor() -> PremiumServiceProtocol {
                    // Thread-safe lazy initialization
                    pthread_once(&_premiumServiceOnceToken) {
                        let startTime = CFAbsoluteTimeGetCurrent()

                        // Register property for metrics tracking
                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "premiumService",
                            propertyType: "PremiumServiceProtocol",
                            containerName: "production",
                            serviceName: "premium",
                            isRequired: true,
                            state: .resolving,
                            resolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(pendingInfo)

                        do {
                            // Resolve dependency
                            guard let resolved = Container.named("production").resolve(PremiumServiceProtocol.self, name: "premium") else {
                                let error = LazyInjectionError.serviceNotRegistered(serviceName: "premium", type: "PremiumServiceProtocol")

                                // Record failed resolution
                                let failedInfo = LazyPropertyInfo(
                                    propertyName: "premiumService",
                                    propertyType: "PremiumServiceProtocol",
                                    containerName: "production",
                                    serviceName: "premium",
                                    isRequired: true,
                                    state: .failed,
                                    resolutionTime: Date(),
                                    resolutionError: error,
                                    threadInfo: ThreadInfo()
                                )
                                LazyInjectionMetrics.recordResolution(failedInfo)

                                fatalError("Required lazy property 'premiumService' of type 'PremiumServiceProtocol' could not be resolved: \\(error.localizedDescription)")
                            }

                            _premiumServiceBacking = resolved

                            // Record successful resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "premiumService",
                                propertyType: "PremiumServiceProtocol",
                                containerName: "production",
                                serviceName: "premium",
                                isRequired: true,
                                state: .resolved,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(resolvedInfo)

                        } catch {
                            // Record failed resolution
                            let endTime = CFAbsoluteTimeGetCurrent()
                            let resolutionDuration = endTime - startTime

                            let failedInfo = LazyPropertyInfo(
                                propertyName: "premiumService",
                                propertyType: "PremiumServiceProtocol",
                                containerName: "production",
                                serviceName: "premium",
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionDuration: resolutionDuration,
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            if true {
                                fatalError("Failed to resolve required lazy property 'premiumService': \\(error.localizedDescription)")
                            }
                        }
                    }

                    return _premiumServiceBacking!
                }
            }
            """,
            macros: testMacros
        )
    }
}
