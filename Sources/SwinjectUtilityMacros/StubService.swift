// StubService.swift - Test stub generation macro declarations

import Foundation
import os.log
import Swinject

// MARK: - @StubService Macro

/// Generates test stub implementations for protocols with configurable return values and behavior.
///
/// This macro automatically creates stub implementations of protocols, making testing easier by
/// eliminating boilerplate test double code and providing flexible behavior configuration.
///
/// ## Basic Usage
///
/// ```swift
/// protocol UserServiceProtocol {
///     func getUser(id: String) -> User?
///     func updateUser(_ user: User) -> Bool
///     func deleteUser(id: String) throws
/// }
///
/// @StubService
/// extension UserServiceProtocol {
///     // Stub implementation generated automatically
/// }
///
/// // Usage in tests:
/// let userStub = UserServiceProtocolStub()
/// userStub.getUserReturnValue = User(id: "123", name: "Test User")
/// userStub.updateUserReturnValue = true
///
/// XCTAssertEqual(userStub.getUser(id: "123")?.name, "Test User")
/// XCTAssertTrue(userStub.updateUser(User(id: "123", name: "Updated")))
/// ```
///
/// ## Advanced Stub Configuration
///
/// ```swift
/// @StubService(
///     prefix: "Mock",
///     suffix: "Double",
///     recordCalls: true,
///     throwErrors: true
/// )
/// extension PaymentServiceProtocol {
///     // Generated: MockPaymentServiceProtocolDouble
/// }
///
/// // Generated stub with call recording:
/// let paymentStub = MockPaymentServiceProtocolDouble()
/// paymentStub.processPaymentThrowError = PaymentError.insufficientFunds
///
/// // Verify calls were made:
/// XCTAssertEqual(paymentStub.processPaymentCallCount, 1)
/// XCTAssertEqual(paymentStub.processPaymentReceivedArguments?.amount, 100.0)
/// ```
///
/// ## Closure-Based Behavior
///
/// ```swift
/// @StubService(closureSupport: true)
/// extension DataServiceProtocol {
///     func fetchData() async throws -> [DataModel]
///     func processData(_ data: [DataModel]) -> ProcessResult
/// }
///
/// // Generated stub with closure support:
/// let dataStub = DataServiceProtocolStub()
/// dataStub.fetchDataClosure = {
///     return [DataModel(id: 1), DataModel(id: 2)]
/// }
/// dataStub.processDataClosure = { data in
///     return ProcessResult(count: data.count)
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Stub Class**: Complete stub implementation of the protocol
/// 2. **Return Value Properties**: Configurable return values for each method
/// 3. **Call Recording**: Optional call count and argument tracking
/// 4. **Error Throwing**: Configurable error throwing for methods that can throw
/// 5. **Closure Support**: Optional closure-based behavior override
/// 6. **Async Support**: Full async/await compatibility
///
/// ## Generated Features
///
/// ### Return Value Configuration
/// ```swift
/// // For each method, generates:
/// var methodNameReturnValue: ReturnType
/// var methodNameReturnValues: [ReturnType] // For sequence of return values
/// ```
///
/// ### Call Recording (when enabled)
/// ```swift
/// // For each method, generates:
/// var methodNameCallCount: Int
/// var methodNameReceivedArguments: (param1: Type1, param2: Type2)?
/// var methodNameReceivedInvocations: [(param1: Type1, param2: Type2)]
/// ```
///
/// ### Error Configuration
/// ```swift
/// // For throwing methods, generates:
/// var methodNameThrowError: Error?
/// ```
///
/// ### Closure Override
/// ```swift
/// // For methods with closure support, generates:
/// var methodNameClosure: ((Type1, Type2) -> ReturnType)?
/// ```
///
/// ## Testing Integration
///
/// ```swift
/// class UserServiceTests: XCTestCase {
///     var userStub: UserServiceProtocolStub!
///     var sut: UserController!
///
///     override func setUp() {
///         super.setUp()
///         userStub = UserServiceProtocolStub()
///         sut = UserController(userService: userStub)
///     }
///
///     func testGetUserDisplaysCorrectName() {
///         // Given
///         let expectedUser = User(id: "123", name: "John Doe")
///         userStub.getUserReturnValue = expectedUser
///
///         // When
///         let displayName = sut.getDisplayName(for: "123")
///
///         // Then
///         XCTAssertEqual(displayName, "John Doe")
///         XCTAssertEqual(userStub.getUserCallCount, 1)
///         XCTAssertEqual(userStub.getUserReceivedArguments?.id, "123")
///     }
/// }
/// ```
@attached(member, names: arbitrary)
@attached(extension, conformances: StubService)
public macro StubService(
    prefix: String = "",
    suffix: String = "Stub",
    recordCalls: Bool = true,
    throwErrors: Bool = true,
    closureSupport: Bool = false,
    async: Bool = true
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "StubServiceMacro")

// MARK: - Stub Service Support Types

/// Protocol marker for generated stub services
public protocol StubService {
    /// Reset all stub configurations to default values
    func resetStub()

    /// Configure the stub with default return values
    func configureDefaults()
}

/// Configuration for stub service generation
public struct StubServiceConfiguration {
    public let prefix: String
    public let suffix: String
    public let recordCalls: Bool
    public let throwErrors: Bool
    public let closureSupport: Bool
    public let asyncSupport: Bool

    public init(
        prefix: String = "",
        suffix: String = "Stub",
        recordCalls: Bool = true,
        throwErrors: Bool = true,
        closureSupport: Bool = false,
        asyncSupport: Bool = true
    ) {
        self.prefix = prefix
        self.suffix = suffix
        self.recordCalls = recordCalls
        self.throwErrors = throwErrors
        self.closureSupport = closureSupport
        self.asyncSupport = asyncSupport
    }

    /// Generate the stub class name for a protocol
    public func stubClassName(for protocolName: String) -> String {
        "\(prefix)\(protocolName)\(suffix)"
    }
}

/// Call recording information for stub methods
public struct StubCallRecord {
    public let methodName: String
    public let arguments: [Any?]
    public let timestamp: Date
    public let callIndex: Int

    public init(methodName: String, arguments: [Any?], timestamp: Date = Date(), callIndex: Int) {
        self.methodName = methodName
        self.arguments = arguments
        self.timestamp = timestamp
        self.callIndex = callIndex
    }
}

/// Registry for managing stub configurations and behaviors
public class StubServiceRegistry {
    public static let shared = StubServiceRegistry()

    private var configurations: [String: StubServiceConfiguration] = [:]
    private var callRecords: [String: [StubCallRecord]] = [:]
    private let lock = NSLock()

    private init() {}

    /// Register a stub configuration for a protocol
    public func register(configuration: StubServiceConfiguration, for protocolName: String) {
        lock.lock()
        defer { lock.unlock() }
        configurations[protocolName] = configuration
    }

    /// Get configuration for a protocol
    public func getConfiguration(for protocolName: String) -> StubServiceConfiguration? {
        lock.lock()
        defer { lock.unlock() }
        return configurations[protocolName]
    }

    /// Record a method call for tracking
    public func recordCall(_ record: StubCallRecord, for stubName: String) {
        lock.lock()
        defer { lock.unlock() }

        if callRecords[stubName] == nil {
            callRecords[stubName] = []
        }
        callRecords[stubName]?.append(record)
    }

    /// Get call records for a stub
    public func getCallRecords(for stubName: String) -> [StubCallRecord] {
        lock.lock()
        defer { lock.unlock() }
        return callRecords[stubName] ?? []
    }

    /// Clear all call records for a stub
    public func clearCallRecords(for stubName: String) {
        lock.lock()
        defer { lock.unlock() }
        callRecords[stubName] = []
    }

    /// Clear all call records
    public func clearAllCallRecords() {
        lock.lock()
        defer { lock.unlock() }
        callRecords.removeAll()
    }
}

// MARK: - Stub Behavior Utilities

/// Utility for managing stub return value sequences
public class StubReturnValueSequence<T> {
    private var values: [T]
    private var currentIndex = 0
    private let lock = NSLock()

    public init(values: [T]) {
        self.values = values
    }

    /// Get the next return value in the sequence
    public func nextValue() -> T? {
        lock.lock()
        defer { lock.unlock() }

        guard !values.isEmpty else { return nil }

        let value = values[currentIndex % values.count]
        currentIndex += 1
        return value
    }

    /// Reset sequence to beginning
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        currentIndex = 0
    }

    /// Update the values in the sequence
    public func updateValues(_ newValues: [T]) {
        lock.lock()
        defer { lock.unlock() }
        values = newValues
        currentIndex = 0
    }
}

/// Async stub behavior support
public actor AsyncStubBehavior<T> {
    private var returnValue: T?
    private var throwError: Error?
    private var closure: (() async throws -> T)?

    public init() {}

    /// Set return value for async method
    public func setReturnValue(_ value: T) {
        returnValue = value
        closure = nil
        throwError = nil
    }

    /// Set error to throw for async method
    public func setThrowError(_ error: Error) {
        throwError = error
        returnValue = nil
        closure = nil
    }

    /// Set closure behavior for async method
    public func setClosure(_ behavior: @escaping () async throws -> T) {
        closure = behavior
        returnValue = nil
        throwError = nil
    }

    /// Execute the configured behavior
    public func execute() async throws -> T {
        if let closure = closure {
            return try await closure()
        }

        if let error = throwError {
            throw error
        }

        guard let value = returnValue else {
            throw StubServiceError.noBehaviorConfigured("No behavior configured for async stub method")
        }

        return value
    }
}

// MARK: - Container Extensions for Stubs

extension Container {

    /// Register a stub implementation for a protocol
    public func registerStub<T>(
        _ protocolType: T.Type,
        stub: T,
        name: String? = nil
    ) {
        register(protocolType, name: name) { _ in stub }
    }

    /// Create a test container with stub registrations
    public static func testContainerWithStubs(
        _ stubRegistrations: (Container) -> Void
    ) -> Container {
        let container = Container()
        stubRegistrations(container)
        return container
    }

    /// Register multiple stubs at once
    public func registerStubs(_ registrations: [String: Any]) {
        for (typeName, stub) in registrations {
            // Note: This would require runtime type information
            // In practice, this would be generated by the macro
            // Log stub registration for debugging
            os_log(
                "Registering stub for %{public}@",
                log: OSLog(subsystem: "com.swinjectutilitymacros", category: "stubs"),
                type: .debug,
                typeName
            )
        }
    }
}

// MARK: - XCTest Integration Helpers

#if canImport(XCTest)
    import XCTest

    /// XCTest assertions for stub verification
    extension XCTestCase {

        /// Assert that a stub method was called with expected count
        public func assertStubMethodCalled(
            _ stub: some StubService,
            method: String,
            count: Int,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            let records = StubServiceRegistry.shared.getCallRecords(for: String(describing: type(of: stub)))
            let methodCalls = records.filter { $0.methodName == method }

            XCTAssertEqual(
                methodCalls.count,
                count,
                "Expected \(method) to be called \(count) times, but was called \(methodCalls.count) times",
                file: file,
                line: line
            )
        }

        /// Assert that a stub method was never called
        public func assertStubMethodNotCalled(
            _ stub: some StubService,
            method: String,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            assertStubMethodCalled(stub, method: method, count: 0, file: file, line: line)
        }

        /// Assert that stub methods were called in specific order
        public func assertStubMethodsCalledInOrder(
            _ stub: some StubService,
            methods: [String],
            file: StaticString = #file,
            line: UInt = #line
        ) {
            let records = StubServiceRegistry.shared.getCallRecords(for: String(describing: type(of: stub)))
            let actualOrder = records.map { $0.methodName }

            XCTAssertEqual(
                actualOrder,
                methods,
                "Expected methods to be called in order \(methods), but actual order was \(actualOrder)",
                file: file,
                line: line
            )
        }
    }
#endif

// MARK: - Stub Service Errors

/// Errors that can occur during stub service operations
public enum StubServiceError: Error, LocalizedError {
    case noBehaviorConfigured(String)

    public var errorDescription: String? {
        switch self {
        case .noBehaviorConfigured(let message):
            "Stub service error: \(message)"
        }
    }
}
