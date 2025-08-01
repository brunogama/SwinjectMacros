// Spy.swift - Method call tracking for testing

import Foundation

// MARK: - @Spy Macro

/// Automatically tracks method calls and arguments for testing purposes.
///
/// This macro transforms methods into spy implementations that record calls, arguments,
/// and return values while preserving the original functionality.
///
/// ## Basic Usage
///
/// ```swift
/// class UserService {
///     @Spy
///     func getUserById(_ id: String) -> User? {
///         // Original implementation
///         return repository.findUser(id: id)
///     }
///     
///     @Spy
///     func createUser(_ user: User) throws -> Bool {
///         // Original implementation
///         return try repository.save(user)
///     }
/// }
/// 
/// // In tests:
/// let service = UserService()
/// let user = service.getUserById("123")
/// 
/// // Verify calls
/// XCTAssertEqual(service.getUserByIdSpyCalls.count, 1)
/// XCTAssertEqual(service.getUserByIdSpyCalls[0].arguments.0, "123")
/// XCTAssertEqual(service.getUserByIdSpyCalls[0].returnValue, user)
/// ```
///
/// ## Advanced Spying with Custom Behavior
///
/// ```swift
/// class NetworkService {
///     @Spy
///     func fetchData(from url: URL) async throws -> Data {
///         // Original implementation
///         let (data, _) = try await URLSession.shared.data(from: url)
///         return data
///     }
/// }
///
/// // In tests - mock specific calls:
/// let service = NetworkService()
/// service.fetchDataSpyBehavior = { url in
///     if url.absoluteString.contains("error") {
///         throw NetworkError.serverError
///     }
///     return Data("mock response".utf8)
/// }
/// 
/// let result = try await service.fetchData(from: URL(string: "https://api.example.com/data")!)
/// XCTAssertEqual(String(data: result, encoding: .utf8), "mock response")
/// ```
///
/// ## What it generates:
///
/// 1. **Call Recording**: Stores method calls with timestamps and arguments
/// 2. **Argument Capture**: Records all input parameters for verification
/// 3. **Return Value Tracking**: Captures return values and thrown errors
/// 4. **Call Count Verification**: Easy access to call statistics
/// 5. **Behavior Override**: Optional mock behavior for testing scenarios
/// 6. **Thread Safety**: All spy operations are thread-safe
///
/// ## Generated Properties and Methods:
///
/// For a method `func getUserById(_ id: String) -> User?`, the macro generates:
///
/// ```swift
/// // Call recording structure
/// struct GetUserByIdSpyCall {
///     let timestamp: Date
///     let arguments: (String)
///     let returnValue: User?
///     let thrownError: Error?
/// }
/// 
/// // Spy state
/// private var _getUserByIdSpyCalls: [GetUserByIdSpyCall] = []
/// private let _getUserByIdSpyLock = NSLock()
/// 
/// // Public access to spy data
/// var getUserByIdSpyCalls: [GetUserByIdSpyCall] {
///     _getUserByIdSpyLock.lock()
///     defer { _getUserByIdSpyLock.unlock() }
///     return _getUserByIdSpyCalls
/// }
/// 
/// // Optional behavior override
/// var getUserByIdSpyBehavior: ((String) -> User?)?
/// 
/// // Reset spy data
/// func resetGetUserByIdSpy() {
///     _getUserByIdSpyLock.lock()
///     defer { _getUserByIdSpyLock.unlock() }
///     _getUserByIdSpyCalls.removeAll()
/// }
/// ```
///
/// ## Testing Utilities
///
/// The macro also generates helpful testing utilities:
///
/// ```swift
/// extension UserService {
///     /// Reset all spy data for clean test setup
///     func resetAllSpies() {
///         resetGetUserByIdSpy()
///         resetCreateUserSpy()
///         // ... other spy resets
///     }
///     
///     /// Get total number of spy calls across all methods
///     var totalSpyCalls: Int {
///         return getUserByIdSpyCalls.count + createUserSpyCalls.count
///     }
/// }
/// ```
///
/// ## Error and Exception Handling
///
/// ```swift
/// class PaymentService {
///     @Spy
///     func processPayment(_ amount: Decimal) throws -> PaymentResult {
///         // Implementation that may throw
///         guard amount > 0 else {
///             throw PaymentError.invalidAmount
///         }
///         return PaymentResult.success
///     }
/// }
/// 
/// // In tests:
/// let service = PaymentService()
/// XCTAssertThrowsError(try service.processPayment(-10)) { error in
///     XCTAssertTrue(error is PaymentError)
/// }
/// 
/// // Verify the error was recorded
/// XCTAssertEqual(service.processPaymentSpyCalls.count, 1)
/// XCTAssertNotNil(service.processPaymentSpyCalls[0].thrownError)
/// ```
///
/// ## Async Method Support
///
/// ```swift
/// class DataService {
///     @Spy
///     func loadUserProfile(_ userId: String) async throws -> UserProfile {
///         // Async implementation
///         return try await apiClient.fetchUserProfile(userId)
///     }
/// }
/// 
/// // Testing async spied methods:
/// let service = DataService()
/// let profile = try await service.loadUserProfile("user123")
/// 
/// XCTAssertEqual(service.loadUserProfileSpyCalls.count, 1)
/// XCTAssertEqual(service.loadUserProfileSpyCalls[0].arguments.0, "user123")
/// ```
///
/// ## Integration with XCTest
///
/// ```swift
/// import XCTest
/// 
/// class UserServiceTests: XCTestCase {
///     var userService: UserService!
///     
///     override func setUp() {
///         super.setUp()
///         userService = UserService()
///         userService.resetAllSpies()
///     }
///     
///     func testUserCreation() {
///         // Setup spy behavior
///         userService.createUserSpyBehavior = { user in
///             return user.id != nil
///         }
///         
///         // Execute
///         let result = try! userService.createUser(User(name: "John"))
///         
///         // Verify
///         XCTAssertTrue(result)
///         XCTAssertEqual(userService.createUserSpyCalls.count, 1)
///         XCTAssertEqual(userService.createUserSpyCalls[0].arguments.0.name, "John")
///     }
/// }
/// ```
///
/// ## Performance Considerations
///
/// The @Spy macro is designed with minimal performance overhead:
/// - Call recording uses efficient data structures
/// - Thread safety uses lightweight locks
/// - Memory usage is optimized for typical test scenarios
/// - Original method performance is preserved
///
/// ## Requirements:
/// - Method must be in a class (not struct or protocol)
/// - Method body should be preserved (not pure protocol methods)
/// - Compatible with both sync and async methods
/// - Supports throwing methods
///
/// ## Parameters:
/// - `captureArguments`: Whether to capture method arguments (default: true)
/// - `captureReturnValue`: Whether to capture return values (default: true)
/// - `captureErrors`: Whether to capture thrown errors (default: true)
/// - `threadSafe`: Whether spy operations should be thread-safe (default: true)
///
/// ## Generated Files:
/// The macro generates spy infrastructure while preserving original method implementation,
/// making it safe to use in both test and production code with minimal overhead.
@attached(peer, names: arbitrary)
public macro Spy(
    captureArguments: Bool = true,
    captureReturnValue: Bool = true,
    captureErrors: Bool = true,
    threadSafe: Bool = true
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "SpyMacro")

// MARK: - Spy Infrastructure

/// Base protocol for all spy call records
public protocol SpyCall {
    var timestamp: Date { get }
    var methodName: String { get }
}

/// Protocol for spy-enabled objects
public protocol Spyable {
    /// Reset all spy data for this object
    func resetAllSpies()
    
    /// Get total number of spy calls across all methods
    var totalSpyCalls: Int { get }
}

/// Thread-safe spy call recorder
public class SpyCallRecorder<CallType: SpyCall> {
    private var calls: [CallType] = []
    private let lock = NSLock()
    
    /// Record a new spy call
    public func record(_ call: CallType) {
        lock.lock()
        defer { lock.unlock() }
        calls.append(call)
    }
    
    /// Get all recorded calls
    public var allCalls: [CallType] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
    
    /// Reset all recorded calls
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        calls.removeAll()
    }
    
    /// Get number of recorded calls
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls.count
    }
}

// MARK: - Spy Verification Utilities

/// Utilities for verifying spy calls in tests
public enum SpyVerification {
    
    /// Verify that a method was called a specific number of times
    public static func verifyCalled<T: SpyCall>(
        _ calls: [T],
        times expectedCount: Int,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard calls.count == expectedCount else {
            fatalError(
                "Expected \(expectedCount) calls but got \(calls.count)",
                file: file,
                line: line
            )
        }
    }
    
    /// Verify that a method was never called
    public static func verifyNeverCalled<T: SpyCall>(
        _ calls: [T],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        verifyCalled(calls, times: 0, file: file, line: line)
    }
    
    /// Verify that a method was called at least once
    public static func verifyCalledAtLeastOnce<T: SpyCall>(
        _ calls: [T],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard !calls.isEmpty else {
            fatalError("Expected at least one call but method was never called", file: file, line: line)
        }
    }
    
    /// Verify call order between different spy methods
    public static func verifyCallOrder<T: SpyCall, U: SpyCall>(
        _ firstCalls: [T],
        before secondCalls: [U],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let firstCall = firstCalls.first,
              let secondCall = secondCalls.first else {
            fatalError("Both methods must be called to verify order", file: file, line: line)
        }
        
        guard firstCall.timestamp < secondCall.timestamp else {
            fatalError("Expected \(firstCall.methodName) to be called before \(secondCall.methodName)", file: file, line: line)
        }
    }
}