// AuthenticationService.swift - Authentication service demonstrating @Injectable and @Cache
// Copyright © 2025 SwinJectMacros Demo. All rights reserved.

import Foundation
import Swinject
import SwinjectUtilityMacros

// MARK: - Authentication Protocol

protocol AuthenticationServiceProtocol {
    func login(email: String, password: String) async throws -> AuthResult
    func logout() async throws
    func refreshToken() async throws -> String
    func getCurrentUser() async throws -> User?
    func validateSession() async throws -> Bool
    var isAuthenticated: Bool { get }
}

// MARK: - Authentication Service Implementation

@Injectable
@Cache(
    strategy: .memory,
    ttl: 3600, // 1 hour cache
    maxSize: 100,
    keyPrefix: "auth"
)
@Retry(
    maxAttempts: 3,
    delay: 1.0,
    backoffStrategy: .exponential
)
class AuthenticationService: AuthenticationServiceProtocol {

    // Dependencies
    private let network: NetworkServiceProtocol
    private let database: DatabaseServiceProtocol
    private let logger: LoggerServiceProtocol

    // Authentication state
    private var currentToken: String?
    private var currentUser: User?
    private let authQueue = DispatchQueue(label: "auth.queue", attributes: .concurrent)

    var isAuthenticated: Bool {
        currentToken != nil && currentUser != nil
    }

    init(
        network: NetworkServiceProtocol,
        database: DatabaseServiceProtocol,
        logger: LoggerServiceProtocol
    ) {
        self.network = network
        self.database = database
        self.logger = logger

        logger.info("🔐 AuthenticationService initialized with caching and retry")
        loadStoredCredentials()
    }

    // MARK: - AuthenticationServiceProtocol Implementation

    func login(email: String, password: String) async throws -> AuthResult {
        logger.info("🔑 Attempting login for user: \(email)")

        // Validate input
        guard !email.isEmpty, !password.isEmpty else {
            throw AuthError.invalidCredentials
        }

        guard isValidEmail(email) else {
            throw AuthError.invalidEmailFormat
        }

        // Prepare login request
        let loginRequest = LoginRequest(email: email, password: password)

        do {
            // Make network request (with retry macro applied)
            let response: LoginResponse = try await network.fetchData(
                from: "auth/login",
                type: LoginResponse.self
            )

            // Store authentication data
            currentToken = response.token
            currentUser = response.user

            // Cache user data (with cache macro applied)
            try await database.save(response.user, to: "current_user")

            let authResult = AuthResult(
                user: response.user,
                token: response.token,
                expiresAt: response.expiresAt
            )

            logger.info("✅ Login successful for user: \(email)")
            return authResult

        } catch {
            logger.error("❌ Login failed for user: \(email) - \(error)")

            // Try offline authentication for demo
            if let demoUser = try await attemptDemoLogin(email: email, password: password) {
                logger.info("🔓 Demo login successful")
                return demoUser
            }

            throw AuthError.loginFailed(error)
        }
    }

    func logout() async throws {
        logger.info("🚪 Logging out current user")

        guard isAuthenticated else {
            logger.warning("⚠️ No user currently authenticated")
            return
        }

        do {
            // Notify server of logout
            _ = try await network.postData(
                LogoutRequest(token: currentToken!),
                to: "auth/logout"
            )
        } catch {
            logger.warning("⚠️ Server logout failed, proceeding with local logout: \(error)")
        }

        // Clear local authentication state
        await clearAuthenticationState()

        logger.info("✅ Logout completed")
    }

    func refreshToken() async throws -> String {
        logger.info("🔄 Refreshing authentication token")

        guard let currentToken = currentToken else {
            throw AuthError.notAuthenticated
        }

        let refreshRequest = RefreshTokenRequest(token: currentToken)

        do {
            let response: RefreshTokenResponse = try await network.fetchData(
                from: "auth/refresh",
                type: RefreshTokenResponse.self
            )

            self.currentToken = response.newToken

            logger.info("✅ Token refreshed successfully")
            return response.newToken

        } catch {
            logger.error("❌ Token refresh failed: \(error)")

            // Clear authentication state on refresh failure
            await clearAuthenticationState()
            throw AuthError.tokenRefreshFailed(error)
        }
    }

    func getCurrentUser() async throws -> User? {
        logger.info("👤 Getting current user")

        if let user = currentUser {
            return user
        }

        // Try to load from cache/database
        if let cachedUser: User = try await database.fetch(
            from: "current_user",
            id: "current",
            type: User.self
        ) {
            currentUser = cachedUser
            logger.info("✅ Loaded user from cache")
            return cachedUser
        }

        logger.info("📭 No current user found")
        return nil
    }

    func validateSession() async throws -> Bool {
        logger.info("🔍 Validating current session")

        guard let token = currentToken else {
            logger.info("❌ No token available for validation")
            return false
        }

        do {
            let validationRequest = ValidateSessionRequest(token: token)
            let isValid: Bool = try await network.fetchData(
                from: "auth/validate",
                type: Bool.self
            )

            if !isValid {
                await clearAuthenticationState()
                logger.warning("⚠️ Session validation failed - clearing state")
            } else {
                logger.info("✅ Session is valid")
            }

            return isValid

        } catch {
            logger.error("❌ Session validation error: \(error)")
            await clearAuthenticationState()
            return false
        }
    }

    // MARK: - Helper Methods

    private func loadStoredCredentials() {
        Task {
            do {
                if let user: User = try await database.fetch(
                    from: "current_user",
                    id: "current",
                    type: User.self
                ) {
                    self.currentUser = user
                    self.logger.info("🔄 Restored user session from storage")
                }
            } catch {
                self.logger.info("ℹ️ No stored credentials found")
            }
        }
    }

    private func clearAuthenticationState() async {
        currentToken = nil
        currentUser = nil

        // Clear cached data
        do {
            _ = try await database.delete(from: "current_user", id: "current")
        } catch {
            logger.warning("⚠️ Failed to clear cached user data: \(error)")
        }
    }

    private func attemptDemoLogin(email: String, password: String) async throws -> AuthResult? {
        // Demo login for testing purposes
        guard email == "demo@example.com" && password == "password123" else {
            return nil
        }

        let demoUser = User(
            name: "Demo User",
            email: email
        )

        let demoToken = "demo_token_\(UUID().uuidString)"

        currentUser = demoUser
        currentToken = demoToken

        return AuthResult(
            user: demoUser,
            token: demoToken,
            expiresAt: Date().addingTimeInterval(3600) // 1 hour
        )
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

// MARK: - Authentication Errors

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case invalidEmailFormat
    case loginFailed(Error)
    case notAuthenticated
    case tokenRefreshFailed(Error)
    case sessionExpired
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid email or password"
        case .invalidEmailFormat:
            "Invalid email format"
        case .loginFailed(let error):
            "Login failed: \(error.localizedDescription)"
        case .notAuthenticated:
            "User is not authenticated"
        case .tokenRefreshFailed(let error):
            "Token refresh failed: \(error.localizedDescription)"
        case .sessionExpired:
            "Session has expired"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Authentication Data Models

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let user: User
    let token: String
    let expiresAt: Date
}

struct LogoutRequest: Codable {
    let token: String
}

struct RefreshTokenRequest: Codable {
    let token: String
}

struct RefreshTokenResponse: Codable {
    let newToken: String
    let expiresAt: Date
}

struct ValidateSessionRequest: Codable {
    let token: String
}

struct AuthResult {
    let user: User
    let token: String
    let expiresAt: Date

    var isExpired: Bool {
        Date() > expiresAt
    }

    var timeUntilExpiry: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }
}
