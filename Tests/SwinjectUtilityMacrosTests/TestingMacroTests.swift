// TestingMacroTests.swift - Comprehensive tests for testing-related macros

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwinjectUtilityMacrosImplementation

final class TestingMacroTests: XCTestCase {

    // MARK: - @Spy Macro Tests

    func testSpyOnNonFunction() {
        assertMacroExpansion("""
        @Spy
        var userName: String = "test"
        """, expandedSource: """
        var userName: String = "test"
        """, diagnostics: [
            DiagnosticSpec(message: """
            @Spy can only be applied to methods.

            ✅ Correct usage:
            class UserService {
                @Spy
                func getUserById(_ id: String) -> User? {
                    return repository.findUser(id: id)
                }
            }

            ❌ Invalid usage:
            @Spy
            class UserService { ... } // Classes not supported

            @Spy
            var userName: String // Properties not supported

            💡 Solution: Apply @Spy to individual methods that need call tracking.
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }

    func testSpyOnClass() {
        assertMacroExpansion("""
        @Spy
        class UserService {
            func getUser() -> User? { nil }
        }
        """, expandedSource: """
        class UserService {
            func getUser() -> User? { nil }
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @Spy can only be applied to methods.

            ✅ Correct usage:
            class UserService {
                @Spy
                func getUserById(_ id: String) -> User? {
                    return repository.findUser(id: id)
                }
            }

            ❌ Invalid usage:
            @Spy
            class UserService { ... } // Classes not supported

            @Spy
            var userName: String // Properties not supported

            💡 Solution: Apply @Spy to individual methods that need call tracking.
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }

    func testSpyBasicFunction() {
        assertMacroExpansion("""
        class UserService {
            @Spy
            func getUserById(_ id: String) -> User? {
                return repository.findUser(id: id)
            }
        }
        """, expandedSource: """
        class UserService {
            @Spy
            func getUserById(_ id: String) -> User? {
                return repository.findUser(id: id)
            }

            struct GetUserByIdSpyCall: SpyCall {
                let timestamp: Date
                let methodName: String
                let arguments: (String)
                let returnValue: User??
            }

            private var _getUserByIdSpyCalls: [GetUserByIdSpyCall] = []
            private let _getUserByIdSpyLock = NSLock()
            var getUserByIdSpyBehavior: ((String) -> User?)?

            var getUserByIdSpyCalls: [GetUserByIdSpyCall] {
                _getUserByIdSpyLock.lock()
                defer { _getUserByIdSpyLock.unlock() }
                return _getUserByIdSpyCalls
            }

            func resetGetUserByIdSpy() {
                _getUserByIdSpyLock.lock()
                defer { _getUserByIdSpyLock.unlock() }
                _getUserByIdSpyCalls.removeAll()
            }
        }
        """, macros: testMacros)
    }

    func testSpyFunctionWithNoParameters() {
        assertMacroExpansion("""
        class UserService {
            @Spy
            func refreshCache() {
                cache.refresh()
            }
        }
        """, expandedSource: """
        class UserService {
            @Spy
            func refreshCache() {
                cache.refresh()
            }

            struct RefreshCacheSpyCall: SpyCall {
                let timestamp: Date
                let methodName: String
            }

            private var _refreshCacheSpyCalls: [RefreshCacheSpyCall] = []
            private let _refreshCacheSpyLock = NSLock()
            var refreshCacheSpyBehavior: (() -> Void)?

            var refreshCacheSpyCalls: [RefreshCacheSpyCall] {
                _refreshCacheSpyLock.lock()
                defer { _refreshCacheSpyLock.unlock() }
                return _refreshCacheSpyCalls
            }

            func resetRefreshCacheSpy() {
                _refreshCacheSpyLock.lock()
                defer { _refreshCacheSpyLock.unlock() }
                _refreshCacheSpyCalls.removeAll()
            }
        }
        """, macros: testMacros)
    }

    func testSpyThrowingFunction() {
        assertMacroExpansion("""
        class APIService {
            @Spy
            func fetchData() throws -> Data {
                throw APIError.networkError
            }
        }
        """, expandedSource: """
        class APIService {
            @Spy
            func fetchData() throws -> Data {
                throw APIError.networkError
            }

            struct FetchDataSpyCall: SpyCall {
                let timestamp: Date
                let methodName: String
                let returnValue: Data?
                let thrownError: Error?
            }

            private var _fetchDataSpyCalls: [FetchDataSpyCall] = []
            private let _fetchDataSpyLock = NSLock()
            var fetchDataSpyBehavior: (() -> Data)?

            var fetchDataSpyCalls: [FetchDataSpyCall] {
                _fetchDataSpyLock.lock()
                defer { _fetchDataSpyLock.unlock() }
                return _fetchDataSpyCalls
            }

            func resetFetchDataSpy() {
                _fetchDataSpyLock.lock()
                defer { _fetchDataSpyLock.unlock() }
                _fetchDataSpyCalls.removeAll()
            }
        }
        """, macros: testMacros)
    }

    func testSpyWithCustomConfiguration() {
        assertMacroExpansion("""
        class DataProcessor {
            @Spy(captureArguments: false, captureReturnValue: false, threadSafe: false)
            func processData(_ data: Data) -> ProcessedData {
                return ProcessedData(data: data)
            }
        }
        """, expandedSource: """
        class DataProcessor {
            @Spy(captureArguments: false, captureReturnValue: false, threadSafe: false)
            func processData(_ data: Data) -> ProcessedData {
                return ProcessedData(data: data)
            }

            struct ProcessDataSpyCall: SpyCall {
                let timestamp: Date
                let methodName: String
            }

            private var _processDataSpyCalls: [ProcessDataSpyCall] = []
            var processDataSpyBehavior: ((Data) -> ProcessedData)?

            var processDataSpyCalls: [ProcessDataSpyCall] {

                return _processDataSpyCalls
            }

            func resetProcessDataSpy() {

                _processDataSpyCalls.removeAll()
            }
        }
        """, macros: testMacros)
    }

    func testSpyComplexFunction() {
        assertMacroExpansion("""
        class ComplexService {
            @Spy
            func processUserData(_ user: User, options: ProcessingOptions, callback: @escaping (Result<ProcessedUser, Error>) -> Void) async throws -> ProcessingResult {
                // Complex processing logic
                return ProcessingResult()
            }
        }
        """, expandedSource: """
        class ComplexService {
            @Spy
            func processUserData(_ user: User, options: ProcessingOptions, callback: @escaping (Result<ProcessedUser, Error>) -> Void) async throws -> ProcessingResult {
                // Complex processing logic
                return ProcessingResult()
            }

            struct ProcessUserDataSpyCall: SpyCall {
                let timestamp: Date
                let methodName: String
                let arguments: (User, ProcessingOptions, (Result<ProcessedUser, Error>) -> Void)
                let returnValue: ProcessingResult?
                let thrownError: Error?
            }

            private var _processUserDataSpyCalls: [ProcessUserDataSpyCall] = []
            private let _processUserDataSpyLock = NSLock()
            var processUserDataSpyBehavior: ((User, ProcessingOptions, @escaping (Result<ProcessedUser, Error>) -> Void) -> ProcessingResult)?

            var processUserDataSpyCalls: [ProcessUserDataSpyCall] {
                _processUserDataSpyLock.lock()
                defer { _processUserDataSpyLock.unlock() }
                return _processUserDataSpyCalls
            }

            func resetProcessUserDataSpy() {
                _processUserDataSpyLock.lock()
                defer { _processUserDataSpyLock.unlock() }
                _processUserDataSpyCalls.removeAll()
            }
        }
        """, macros: testMacros)
    }

    // MARK: - @MockResponse Macro Tests

    func testMockResponseOnNonFunction() {
        assertMacroExpansion("""
        @MockResponse([.success("test")])
        var apiEndpoint: String = "https://api.example.com"
        """, expandedSource: """
        var apiEndpoint: String = "https://api.example.com"
        """, diagnostics: [
            DiagnosticSpec(message: """
            @MockResponse can only be applied to methods.

            ✅ Correct usage:
            class APIService {
                @MockResponse([.success(UserData.mock)])
                func fetchUser(_ id: String) async throws -> UserData {
                    // Real implementation
                    return try await apiClient.fetchUser(id)
                }
            }

            ❌ Invalid usage:
            @MockResponse([.success("test")])
            class APIService { ... } // Classes not supported

            @MockResponse([.success(true)])
            var isLoading: Bool // Properties not supported

            💡 Solution: Apply @MockResponse to methods that need mock responses.
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }

    func testMockResponseOnClass() {
        assertMacroExpansion("""
        @MockResponse([.success("test")])
        class APIService {
            func fetchData() -> String { "real data" }
        }
        """, expandedSource: """
        class APIService {
            func fetchData() -> String { "real data" }
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            @MockResponse can only be applied to methods.

            ✅ Correct usage:
            class APIService {
                @MockResponse([.success(UserData.mock)])
                func fetchUser(_ id: String) async throws -> UserData {
                    // Real implementation
                    return try await apiClient.fetchUser(id)
                }
            }

            ❌ Invalid usage:
            @MockResponse([.success("test")])
            class APIService { ... } // Classes not supported

            @MockResponse([.success(true)])
            var isLoading: Bool // Properties not supported

            💡 Solution: Apply @MockResponse to methods that need mock responses.
            """, line: 1, column: 1, severity: .error)
        ], macros: testMacros)
    }

    func testMockResponseBasicFunction() {
        assertMacroExpansion("""
        class APIService {
            @MockResponse
            func fetchUser(_ id: String) async throws -> UserData {
                return try await apiClient.fetchUser(id)
            }
        }
        """, expandedSource: """
        class APIService {
            @MockResponse
            func fetchUser(_ id: String) async throws -> UserData {
                return try await apiClient.fetchUser(id)
            }

            private var _fetchUserMockResponses: [MockResponseConfiguration] = []
            private var _fetchUserMockResponseIndex: Int = 0
            private let _fetchUserMockLock = NSLock()
            private var _fetchUserMockCallCount: Int = 0
            private var _fetchUserMockCallHistory: [(arguments: Any, timestamp: Date)] = []
            var fetchUserMockBehavior: ((String) async throws -> UserData)?

            var fetchUserMockCallCount: Int {
                _fetchUserMockLock.lock()
                defer { _fetchUserMockLock.unlock() }
                return _fetchUserMockCallCount
            }

            var fetchUserMockCallHistory: [(arguments: Any, timestamp: Date)] {
                _fetchUserMockLock.lock()
                defer { _fetchUserMockLock.unlock() }
                return _fetchUserMockCallHistory
            }

            func resetFetchUserMockResponses() {
                _fetchUserMockLock.lock()
                defer { _fetchUserMockLock.unlock() }
                _fetchUserMockResponseIndex = 0
                _fetchUserMockCallCount = 0
                _fetchUserMockCallHistory.removeAll()
            }

            func setFetchUserMockResponses(_ responses: [MockResponseConfiguration]) {
                _fetchUserMockLock.lock()
                defer { _fetchUserMockLock.unlock() }
                _fetchUserMockResponses = responses
                _fetchUserMockResponseIndex = 0
            }

            func setFetchUserMockBehavior(_ behavior: @escaping (String) async throws -> UserData) {
                fetchUserMockBehavior = behavior
            }
        }
        """, macros: testMacros)
    }

    func testMockResponseWithConfiguration() {
        assertMacroExpansion("""
        class APIService {
            @MockResponse(fallbackToOriginal: true, trackCallMetrics: false)
            func fetchData() -> String {
                return "real data"
            }
        }
        """, expandedSource: """
        class APIService {
            @MockResponse(fallbackToOriginal: true, trackCallMetrics: false)
            func fetchData() -> String {
                return "real data"
            }

            private var _fetchDataMockResponses: [MockResponseConfiguration] = []
            private var _fetchDataMockResponseIndex: Int = 0
            private let _fetchDataMockLock = NSLock()
            var fetchDataMockBehavior: (() async throws -> String)?

            func resetFetchDataMockResponses() {
                _fetchDataMockLock.lock()
                defer { _fetchDataMockLock.unlock() }
                _fetchDataMockResponseIndex = 0

            }

            func setFetchDataMockResponses(_ responses: [MockResponseConfiguration]) {
                _fetchDataMockLock.lock()
                defer { _fetchDataMockLock.unlock() }
                _fetchDataMockResponses = responses
                _fetchDataMockResponseIndex = 0
            }

            func setFetchDataMockBehavior(_ behavior: @escaping () async throws -> String) {
                fetchDataMockBehavior = behavior
            }
        }
        """, macros: testMacros)
    }

    func testMockResponseNoParameters() {
        assertMacroExpansion("""
        class StatusService {
            @MockResponse
            func getSystemStatus() async -> SystemStatus {
                return SystemStatus.healthy
            }
        }
        """, expandedSource: """
        class StatusService {
            @MockResponse
            func getSystemStatus() async -> SystemStatus {
                return SystemStatus.healthy
            }

            private var _getSystemStatusMockResponses: [MockResponseConfiguration] = []
            private var _getSystemStatusMockResponseIndex: Int = 0
            private let _getSystemStatusMockLock = NSLock()
            private var _getSystemStatusMockCallCount: Int = 0
            private var _getSystemStatusMockCallHistory: [(arguments: Any, timestamp: Date)] = []
            var getSystemStatusMockBehavior: (() async throws -> SystemStatus)?

            var getSystemStatusMockCallCount: Int {
                _getSystemStatusMockLock.lock()
                defer { _getSystemStatusMockLock.unlock() }
                return _getSystemStatusMockCallCount
            }

            var getSystemStatusMockCallHistory: [(arguments: Any, timestamp: Date)] {
                _getSystemStatusMockLock.lock()
                defer { _getSystemStatusMockLock.unlock() }
                return _getSystemStatusMockCallHistory
            }

            func resetGetSystemStatusMockResponses() {
                _getSystemStatusMockLock.lock()
                defer { _getSystemStatusMockLock.unlock() }
                _getSystemStatusMockResponseIndex = 0
                _getSystemStatusMockCallCount = 0
                _getSystemStatusMockCallHistory.removeAll()
            }

            func setGetSystemStatusMockResponses(_ responses: [MockResponseConfiguration]) {
                _getSystemStatusMockLock.lock()
                defer { _getSystemStatusMockLock.unlock() }
                _getSystemStatusMockResponses = responses
                _getSystemStatusMockResponseIndex = 0
            }

            func setGetSystemStatusMockBehavior(_ behavior: @escaping () async throws -> SystemStatus) {
                getSystemStatusMockBehavior = behavior
            }
        }
        """, macros: testMacros)
    }

    func testMockResponseSyncFunction() {
        assertMacroExpansion("""
        class CacheService {
            @MockResponse
            func getCachedValue(for key: String) -> String? {
                return cache[key]
            }
        }
        """, expandedSource: """
        class CacheService {
            @MockResponse
            func getCachedValue(for key: String) -> String? {
                return cache[key]
            }

            private var _getCachedValueMockResponses: [MockResponseConfiguration] = []
            private var _getCachedValueMockResponseIndex: Int = 0
            private let _getCachedValueMockLock = NSLock()
            private var _getCachedValueMockCallCount: Int = 0
            private var _getCachedValueMockCallHistory: [(arguments: Any, timestamp: Date)] = []
            var getCachedValueMockBehavior: ((String) async throws -> String?)?

            var getCachedValueMockCallCount: Int {
                _getCachedValueMockLock.lock()
                defer { _getCachedValueMockLock.unlock() }
                return _getCachedValueMockCallCount
            }

            var getCachedValueMockCallHistory: [(arguments: Any, timestamp: Date)] {
                _getCachedValueMockLock.lock()
                defer { _getCachedValueMockLock.unlock() }
                return _getCachedValueMockCallHistory
            }

            func resetGetCachedValueMockResponses() {
                _getCachedValueMockLock.lock()
                defer { _getCachedValueMockLock.unlock() }
                _getCachedValueMockResponseIndex = 0
                _getCachedValueMockCallCount = 0
                _getCachedValueMockCallHistory.removeAll()
            }

            func setGetCachedValueMockResponses(_ responses: [MockResponseConfiguration]) {
                _getCachedValueMockLock.lock()
                defer { _getCachedValueMockLock.unlock() }
                _getCachedValueMockResponses = responses
                _getCachedValueMockResponseIndex = 0
            }

            func setGetCachedValueMockBehavior(_ behavior: @escaping (String) async throws -> String?) {
                getCachedValueMockBehavior = behavior
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Edge Cases and Complex Scenarios

    func testSpyAndMockResponseCombination() {
        assertMacroExpansion("""
        class TestableService {
            @Spy
            @MockResponse
            func complexOperation(_ input: ComplexInput) async throws -> ComplexOutput {
                return try await realImplementation(input)
            }
        }
        """, expandedSource: """
        class TestableService {
            @Spy
            @MockResponse
            func complexOperation(_ input: ComplexInput) async throws -> ComplexOutput {
                return try await realImplementation(input)
            }

            struct ComplexOperationSpyCall: SpyCall {
                let timestamp: Date
                let methodName: String
                let arguments: (ComplexInput)
                let returnValue: ComplexOutput?
                let thrownError: Error?
            }

            private var _complexOperationSpyCalls: [ComplexOperationSpyCall] = []
            private let _complexOperationSpyLock = NSLock()
            var complexOperationSpyBehavior: ((ComplexInput) -> ComplexOutput)?

            var complexOperationSpyCalls: [ComplexOperationSpyCall] {
                _complexOperationSpyLock.lock()
                defer { _complexOperationSpyLock.unlock() }
                return _complexOperationSpyCalls
            }

            func resetComplexOperationSpy() {
                _complexOperationSpyLock.lock()
                defer { _complexOperationSpyLock.unlock() }
                _complexOperationSpyCalls.removeAll()
            }

            private var _complexOperationMockResponses: [MockResponseConfiguration] = []
            private var _complexOperationMockResponseIndex: Int = 0
            private let _complexOperationMockLock = NSLock()
            private var _complexOperationMockCallCount: Int = 0
            private var _complexOperationMockCallHistory: [(arguments: Any, timestamp: Date)] = []
            var complexOperationMockBehavior: ((ComplexInput) async throws -> ComplexOutput)?

            var complexOperationMockCallCount: Int {
                _complexOperationMockLock.lock()
                defer { _complexOperationMockLock.unlock() }
                return _complexOperationMockCallCount
            }

            var complexOperationMockCallHistory: [(arguments: Any, timestamp: Date)] {
                _complexOperationMockLock.lock()
                defer { _complexOperationMockLock.unlock() }
                return _complexOperationMockCallHistory
            }

            func resetComplexOperationMockResponses() {
                _complexOperationMockLock.lock()
                defer { _complexOperationMockLock.unlock() }
                _complexOperationMockResponseIndex = 0
                _complexOperationMockCallCount = 0
                _complexOperationMockCallHistory.removeAll()
            }

            func setComplexOperationMockResponses(_ responses: [MockResponseConfiguration]) {
                _complexOperationMockLock.lock()
                defer { _complexOperationMockLock.unlock() }
                _complexOperationMockResponses = responses
                _complexOperationMockResponseIndex = 0
            }

            func setComplexOperationMockBehavior(_ behavior: @escaping (ComplexInput) async throws -> ComplexOutput) {
                complexOperationMockBehavior = behavior
            }
        }
        """, macros: testMacros)
    }

    func testSpyWithGenericFunction() {
        assertMacroExpansion("""
        class GenericService<T> {
            @Spy
            func processItem<U>(_ item: T, converter: (T) -> U) -> U {
                return converter(item)
            }
        }
        """, expandedSource: """
        class GenericService<T> {
            @Spy
            func processItem<U>(_ item: T, converter: (T) -> U) -> U {
                return converter(item)
            }

            struct ProcessItemSpyCall: SpyCall {
                let timestamp: Date
                let methodName: String
                let arguments: (T, (T) -> U)
                let returnValue: U?
            }

            private var _processItemSpyCalls: [ProcessItemSpyCall] = []
            private let _processItemSpyLock = NSLock()
            var processItemSpyBehavior: ((T, (T) -> U) -> U)?

            var processItemSpyCalls: [ProcessItemSpyCall] {
                _processItemSpyLock.lock()
                defer { _processItemSpyLock.unlock() }
                return _processItemSpyCalls
            }

            func resetProcessItemSpy() {
                _processItemSpyLock.lock()
                defer { _processItemSpyLock.unlock() }
                _processItemSpyCalls.removeAll()
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Test Utilities

    private let testMacros: [String: Macro.Type] = [
        "Spy": SpyMacro.self,
        "MockResponse": MockResponseMacro.self
    ]
}

// MARK: - Supporting Test Types

protocol SpyCall {
    var timestamp: Date { get }
    var methodName: String { get }
}

struct MockResponseConfiguration {
    // Mock configuration structure
}

// Test data types
struct TestingUser {
    let id: String
    let name: String
}

struct TestingUserData {
    let id: String
    let name: String
    let email: String

    static let mock = TestingUserData(id: "1", name: "Test User", email: "test@example.com")
}

struct TestingProcessedData {
    let data: Data
}

struct TestingProcessingOptions {
    let priority: Int
    let async: Bool
}

struct TestingProcessedUser {
    let user: TestingUser
    let processedAt: Date
}

struct ProcessingResult {
    let success: Bool
    let metadata: [String: Any] = [:]
}

struct ComplexInput {
    let data: String
}

struct ComplexOutput {
    let result: String
}

enum SystemStatus {
    case healthy
    case degraded
    case down
}

enum APIError: Error {
    case networkError
    case invalidResponse
    case unauthorized
}
