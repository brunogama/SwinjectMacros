// MockResponse.swift - Declarative mock response configuration

import Foundation

// MARK: - @MockResponse Macro

/// Declaratively configure mock responses for HTTP requests and service calls.
///
/// This macro provides a clean, type-safe way to set up mock responses for testing
/// network services, API clients, and other async operations.
///
/// ## Basic Usage
///
/// ```swift
/// class APIClient {
///     @MockResponse([
///         .success(UserProfile.mockProfile, delay: 0.1),
///         .failure(APIError.networkError, delay: 0.2)
///     ])
///     func fetchUserProfile(_ userId: String) async throws -> UserProfile {
///         // Real implementation
///         let url = URL(string: "https://api.example.com/users/\(userId)")!
///         let (data, _) = try await URLSession.shared.data(from: url)
///         return try JSONDecoder().decode(UserProfile.self, from: data)
///     }
/// }
///
/// // In tests:
/// let client = APIClient()
///
/// // First call returns success after 0.1s delay
/// let profile = try await client.fetchUserProfile("123")
/// XCTAssertEqual(profile.name, "Mock User")
///
/// // Second call throws error after 0.2s delay
/// XCTAssertThrowsError(try await client.fetchUserProfile("456"))
/// ```
///
/// ## HTTP Response Mocking
///
/// ```swift
/// class HTTPService {
///     @MockResponse([
///         .httpResponse(
///             statusCode: 200,
///             data: Data(#"{"status": "success"}"#.utf8),
///             headers: ["Content-Type": "application/json"]
///         ),
///         .httpResponse(
///             statusCode: 404,
///             data: Data(#"{"error": "Not found"}"#.utf8)
///         )
///     ])
///     func makeRequest(to endpoint: String) async throws -> HTTPResponse {
///         // Real HTTP implementation
///         let url = URL(string: "https://api.example.com\(endpoint)")!
///         let (data, response) = try await URLSession.shared.data(from: url)
///         return HTTPResponse(data: data, response: response as! HTTPURLResponse)
///     }
/// }
/// ```
///
/// ## Conditional Mocking Based on Parameters
///
/// ```swift
/// class UserService {
///     @MockResponse([
///         .when({ args in args.0.contains("admin") })
///             .return(.success(User.adminUser)),
///         .when({ args in args.0.contains("guest") })
///             .return(.success(User.guestUser)),
///         .default(.failure(UserError.notFound))
///     ])
///     func getUser(byEmail email: String) async throws -> User {
///         // Real implementation
///         return try await repository.findUser(email: email)
///     }
/// }
///
/// // Testing:
/// let service = UserService()
///
/// let admin = try await service.getUser(byEmail: "admin@example.com")
/// XCTAssertTrue(admin.isAdmin)
///
/// let guest = try await service.getUser(byEmail: "guest@example.com")
/// XCTAssertFalse(guest.isAdmin)
///
/// XCTAssertThrowsError(try await service.getUser(byEmail: "unknown@example.com"))
/// ```
///
/// ## Sequence-Based Responses
///
/// ```swift
/// class PaymentService {
///     @MockResponse([
///         .sequence([
///             .success(PaymentResult.processing),
///             .success(PaymentResult.completed),
///             .failure(PaymentError.declined)
///         ])
///     ])
///     func processPayment(_ amount: Decimal) async throws -> PaymentResult {
///         // Real payment processing
///         return try await paymentGateway.charge(amount)
///     }
/// }
///
/// // Testing sequence:
/// let service = PaymentService()
///
/// // First call: processing
/// let result1 = try await service.processPayment(100.0)
/// XCTAssertEqual(result1, .processing)
///
/// // Second call: completed
/// let result2 = try await service.processPayment(100.0)
/// XCTAssertEqual(result2, .completed)
///
/// // Third call: throws declined error
/// XCTAssertThrowsError(try await service.processPayment(100.0))
/// ```
///
/// ## What it generates:
///
/// 1. **Mock Response Storage**: Thread-safe storage for configured responses
/// 2. **Response Selection Logic**: Matches requests to appropriate responses
/// 3. **Delay Simulation**: Realistic async delays for testing
/// 4. **Call Counting**: Tracks which responses have been used
/// 5. **Reset Functionality**: Easy cleanup between tests
/// 6. **Fallback Behavior**: Default responses when mocks are exhausted
///
/// ## Advanced Features
///
/// ### Custom Response Matchers
///
/// ```swift
/// class SearchService {
///     @MockResponse([
///         .matcher({ args in
///             let query = args.0 as String
///             return query.count < 3
///         }).return(.failure(SearchError.queryTooShort)),
///
///         .matcher({ args in
///             let query = args.0 as String
///             return query.contains("swift")
///         }).return(.success(SearchResult.swiftResults)),
///
///         .default(.success(SearchResult.empty))
///     ])
///     func search(_ query: String) async throws -> SearchResult {
///         // Real search implementation
///         return try await searchEngine.query(query)
///     }
/// }
/// ```
///
/// ### Response Chains and State
///
/// ```swift
/// class DatabaseService {
///     @MockResponse([
///         .stateful(initialState: 0) { state, args in
///             let newState = state + 1
///             return (.success("Record \(newState)"), newState)
///         }
///     ])
///     func createRecord(_ data: RecordData) async throws -> String {
///         // Real database implementation
///         return try await database.insert(data)
///     }
/// }
/// ```
///
/// ## Test Integration
///
/// ```swift
/// class APIClientTests: XCTestCase {
///     var apiClient: APIClient!
///
///     override func setUp() {
///         super.setUp()
///         apiClient = APIClient()
///         apiClient.resetMockResponses()
///     }
///
///     func testSuccessfulUserFetch() async throws {
///         // Mock responses are already configured via @MockResponse
///         let user = try await apiClient.fetchUserProfile("123")
///         XCTAssertEqual(user.name, "Mock User")
///
///         // Verify the mock was called
///         XCTAssertEqual(apiClient.fetchUserProfileMockCallCount, 1)
///     }
///
///     func testCustomMockResponse() async throws {
///         // Override configured mocks for specific test
///         apiClient.setFetchUserProfileMockBehavior { userId in
///             if userId == "special" {
///                 return .success(UserProfile.specialUser)
///             }
///             throw APIError.userNotFound
///         }
///
///         let user = try await apiClient.fetchUserProfile("special")
///         XCTAssertEqual(user.type, .special)
///     }
/// }
/// ```
///
/// ## Performance and Memory Considerations
///
/// The @MockResponse macro is optimized for testing scenarios:
/// - Minimal runtime overhead when not in test mode
/// - Efficient response matching algorithms
/// - Memory-conscious storage of mock data
/// - Thread-safe operations for concurrent testing
///
/// ## Parameters:
/// - `responses`: Array of mock response configurations
/// - `fallbackToOriginal`: Whether to call original method when mocks exhausted (default: false)
/// - `resetBetweenCalls`: Whether to reset mock state between calls (default: false)
/// - `trackCallMetrics`: Whether to track detailed call metrics (default: true)
///
/// ## Requirements:
/// - Method must return a value or throw (Void methods supported with completion tracking)
/// - Method should be async or async throws for best experience
/// - Class must be able to store additional properties for mock state
///
/// ## Mock Response Types:
/// - `.success(value, delay:)` - Return successful value with optional delay
/// - `.failure(error, delay:)` - Throw error with optional delay
/// - `.sequence([responses])` - Return responses in sequence
/// - `.when(predicate).return(response)` - Conditional responses
/// - `.matcher(closure).return(response)` - Custom matching logic
/// - `.stateful(initialState:closure)` - Stateful response generation
/// - `.httpResponse(statusCode:data:headers:)` - HTTP-specific responses
@attached(peer, names: arbitrary)
public macro MockResponse(
    _ responses: [MockResponseConfiguration],
    fallbackToOriginal: Bool = false,
    resetBetweenCalls: Bool = false,
    trackCallMetrics: Bool = true
) = #externalMacro(module: "SwinjectUtilityMacrosImplementation", type: "MockResponseMacro")

// MARK: - Mock Response Configuration

/// Configuration for mock responses
public indirect enum MockResponseConfiguration {

    /// Successful response with optional delay
    case success(Any, delay: TimeInterval = 0)

    /// Error response with optional delay
    case failure(Error, delay: TimeInterval = 0)

    /// Sequence of responses to return in order
    case sequence([MockResponseConfiguration])

    /// HTTP response with status code, data, and headers
    case httpResponse(statusCode: Int, data: Data, headers: [String: String] = [:])

    /// Conditional response based on predicate
    case conditional(predicate: (Any) -> Bool, response: MockResponseConfiguration)

    /// Default response when no other conditions match
    case `default`(MockResponseConfiguration)

    /// Stateful response that maintains state between calls
    case stateful(initialState: Any, handler: (Any, Any) -> (MockResponseConfiguration, Any))
}

// MARK: - Mock Response Builder

/// Builder for creating complex mock response configurations
public class MockResponseBuilder {
    var configurations: [MockResponseConfiguration] = []

    /// Add a successful response
    @discardableResult
    public func success(_ value: some Any, delay: TimeInterval = 0) -> MockResponseBuilder {
        configurations.append(.success(value, delay: delay))
        return self
    }

    /// Add an error response
    @discardableResult
    public func failure(_ error: Error, delay: TimeInterval = 0) -> MockResponseBuilder {
        configurations.append(.failure(error, delay: delay))
        return self
    }

    /// Add an HTTP response
    @discardableResult
    public func httpResponse(
        statusCode: Int,
        data: Data,
        headers: [String: String] = [:]
    ) -> MockResponseBuilder {
        configurations.append(.httpResponse(statusCode: statusCode, data: data, headers: headers))
        return self
    }

    /// Add a conditional response
    @discardableResult
    public func when(_ predicate: @escaping (Any) -> Bool) -> ConditionalResponseBuilder {
        ConditionalResponseBuilder(builder: self, predicate: predicate)
    }

    /// Build the final configuration array
    public func build() -> [MockResponseConfiguration] {
        configurations
    }
}

/// Builder for conditional responses
public class ConditionalResponseBuilder {
    private let builder: MockResponseBuilder
    private let predicate: (Any) -> Bool

    init(builder: MockResponseBuilder, predicate: @escaping (Any) -> Bool) {
        self.builder = builder
        self.predicate = predicate
    }

    /// Set the response for this condition
    @discardableResult
    public func `return`(_ value: some Any) -> MockResponseBuilder {
        let response = MockResponseConfiguration.success(value)
        builder.configurations.append(.conditional(predicate: predicate, response: response))
        return builder
    }

    /// Set an error response for this condition
    @discardableResult
    public func throwError(_ error: Error) -> MockResponseBuilder {
        let response = MockResponseConfiguration.failure(error)
        builder.configurations.append(.conditional(predicate: predicate, response: response))
        return builder
    }
}

// MARK: - Mock Response Utilities

/// Utilities for working with mock responses in tests
public enum MockResponseUtilities {

    /// Create a simple success response
    public static func success(_ value: some Any, delay: TimeInterval = 0) -> [MockResponseConfiguration] {
        [.success(value, delay: delay)]
    }

    /// Create a simple error response
    public static func failure(_ error: Error, delay: TimeInterval = 0) -> [MockResponseConfiguration] {
        [.failure(error, delay: delay)]
    }

    /// Create an HTTP response
    public static func httpResponse(
        statusCode: Int,
        data: Data,
        headers: [String: String] = [:]
    ) -> [MockResponseConfiguration] {
        [.httpResponse(statusCode: statusCode, data: data, headers: headers)]
    }

    /// Create a JSON response
    public static func jsonResponse(
        _ object: some Codable,
        statusCode: Int = 200,
        headers: [String: String] = [:]
    ) throws -> [MockResponseConfiguration] {
        let data = try JSONEncoder().encode(object)
        var responseHeaders = headers
        responseHeaders["Content-Type"] = "application/json"
        return [.httpResponse(statusCode: statusCode, data: data, headers: responseHeaders)]
    }
}

// MARK: - HTTP Response Types

/// HTTP response container for mocked responses
public struct HTTPResponse {
    public let data: Data
    public let statusCode: Int
    public let headers: [String: String]

    public init(data: Data, statusCode: Int, headers: [String: String] = [:]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }

    public init(data: Data, response: HTTPURLResponse) {
        self.data = data
        statusCode = response.statusCode

        var headerDict: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headerDict[keyString] = valueString
            }
        }
        headers = headerDict
    }
}

// MARK: - Mock Response Errors

/// Errors that can occur during mock response handling
public enum MockResponseError: Error, LocalizedError {
    case noResponseConfigured
    case invalidResponseType
    case mockResponsesExhausted
    case predicateEvaluationFailed

    public var errorDescription: String? {
        switch self {
        case .noResponseConfigured:
            "No mock response configured for this method call"
        case .invalidResponseType:
            "Mock response type does not match expected return type"
        case .mockResponsesExhausted:
            "All configured mock responses have been used"
        case .predicateEvaluationFailed:
            "Failed to evaluate mock response predicate"
        }
    }
}
