// UserService.swift - User management service demonstrating @Injectable and @Retry
// Copyright © 2025 SwinJectMacros Demo. All rights reserved.

import Foundation
import Swinject
import SwinjectUtilityMacros

// MARK: - User Service Protocol

protocol UserServiceProtocol {
    func createUser(_ userData: CreateUserRequest) async throws -> User
    func updateUser(_ userId: String, with data: UpdateUserRequest) async throws -> User
    func deleteUser(_ userId: String) async throws -> Bool
    func getUser(by id: String) async throws -> User?
    func getUserByEmail(_ email: String) async throws -> User?
    func getAllUsers() async throws -> [User]
    func searchUsers(query: String) async throws -> [User]
    func updateUserPreferences(_ userId: String, preferences: UserPreferences) async throws -> Bool
}

// MARK: - User Service Implementation

@Injectable
@Retry(
    maxAttempts: 3,
    delay: 2.0,
    backoffStrategy: .exponential,
    retryableErrors: [UserError.networkError, UserError.serverError]
)
@PerformanceTracked(
    trackExecutionTime: true,
    logSlowOperations: true,
    slowOperationThreshold: 1.5
)
class UserService: UserServiceProtocol {

    // Dependencies
    private let network: NetworkServiceProtocol
    private let database: DatabaseServiceProtocol
    private let auth: AuthenticationServiceProtocol
    private let logger: LoggerServiceProtocol

    // Caching
    private var userCache: [String: User] = [:]
    private let cacheQueue = DispatchQueue(label: "user.cache.queue", attributes: .concurrent)
    private let maxCacheSize = 100
    private let cacheExpiry: TimeInterval = 300 // 5 minutes

    init(
        network: NetworkServiceProtocol,
        database: DatabaseServiceProtocol,
        auth: AuthenticationServiceProtocol,
        logger: LoggerServiceProtocol
    ) {
        self.network = network
        self.database = database
        self.auth = auth
        self.logger = logger

        logger.info("👥 UserService initialized with retry and performance tracking")
        setupCacheCleanup()
    }

    // MARK: - UserServiceProtocol Implementation

    func createUser(_ userData: CreateUserRequest) async throws -> User {
        logger.info("👤 Creating new user: \(userData.email)")

        // Validate input
        try validateCreateUserRequest(userData)

        // Check if user already exists
        if let existingUser = try await getUserByEmail(userData.email) {
            logger.warning("⚠️ User already exists: \(userData.email)")
            throw UserError.userAlreadyExists
        }

        do {
            // Create user via API (with retry macro applied)
            let createdUser: User = try await network.fetchData(
                from: "users",
                type: User.self
            )

            // Store locally
            let userId = try await database.save(createdUser, to: "users")

            // Update cache
            await updateCache(user: createdUser)

            logger.info("✅ User created successfully: \(createdUser.id)")
            return createdUser

        } catch {
            logger.error("❌ Failed to create user: \(error)")
            throw UserError.creationFailed(error)
        }
    }

    func updateUser(_ userId: String, with data: UpdateUserRequest) async throws -> User {
        logger.info("✏️ Updating user: \(userId)")

        // Validate authentication
        guard auth.isAuthenticated else {
            throw UserError.notAuthenticated
        }

        // Get current user
        guard var existingUser = try await getUser(by: userId) else {
            throw UserError.userNotFound
        }

        do {
            // Apply updates
            if let name = data.name {
                existingUser = User(
                    id: existingUser.id,
                    name: name,
                    email: existingUser.email,
                    createdAt: existingUser.createdAt
                )
            }

            // Update via API (with retry macro applied)
            let updatedUser: User = try await network.fetchData(
                from: "users/\(userId)",
                type: User.self
            )

            // Update local storage
            _ = try await database.save(updatedUser, to: "users")

            // Update cache
            await updateCache(user: updatedUser)

            logger.info("✅ User updated successfully: \(userId)")
            return updatedUser

        } catch {
            logger.error("❌ Failed to update user: \(error)")
            throw UserError.updateFailed(error)
        }
    }

    func deleteUser(_ userId: String) async throws -> Bool {
        logger.info("🗑️ Deleting user: \(userId)")

        // Validate authentication
        guard auth.isAuthenticated else {
            throw UserError.notAuthenticated
        }

        do {
            // Delete via API (with retry macro applied)
            let success = try await network.postData(
                DeleteUserRequest(userId: userId),
                to: "users/\(userId)/delete"
            )

            if success {
                // Delete locally
                _ = try await database.delete(from: "users", id: userId)

                // Remove from cache
                await removeFromCache(userId: userId)

                logger.info("✅ User deleted successfully: \(userId)")
            } else {
                logger.warning("⚠️ User deletion failed: \(userId)")
            }

            return success

        } catch {
            logger.error("❌ Failed to delete user: \(error)")
            throw UserError.deletionFailed(error)
        }
    }

    func getUser(by id: String) async throws -> User? {
        logger.info("🔍 Getting user by ID: \(id)")

        // Check cache first
        if let cachedUser = await getCachedUser(id: id) {
            logger.info("✅ User found in cache: \(id)")
            return cachedUser
        }

        // Try local database
        if let localUser: User = try await database.fetch(
            from: "users",
            id: id,
            type: User.self
        ) {
            await updateCache(user: localUser)
            logger.info("✅ User found in local database: \(id)")
            return localUser
        }

        // Fetch from API (with retry macro applied)
        do {
            let user: User = try await network.fetchData(
                from: "users/\(id)",
                type: User.self
            )

            // Cache the result
            await updateCache(user: user)

            // Store locally
            _ = try await database.save(user, to: "users")

            logger.info("✅ User fetched from API: \(id)")
            return user

        } catch {
            if case NetworkError.httpError(404) = error {
                logger.info("📭 User not found: \(id)")
                return nil
            }

            logger.error("❌ Failed to fetch user: \(error)")
            throw UserError.fetchFailed(error)
        }
    }

    func getUserByEmail(_ email: String) async throws -> User? {
        logger.info("📧 Getting user by email: \(email)")

        // Try local database first
        let localUsers: [User] = try await database.fetchAll(
            from: "users",
            type: User.self
        )

        if let localUser = localUsers.first(where: { $0.email == email }) {
            await updateCache(user: localUser)
            logger.info("✅ User found by email in local database")
            return localUser
        }

        // Search via API (with retry macro applied)
        do {
            let searchResults: [User] = try await network.fetchData(
                from: "users/search?email=\(email)",
                type: [User].self
            )

            if let user = searchResults.first {
                await updateCache(user: user)
                _ = try await database.save(user, to: "users")
                logger.info("✅ User found by email via API")
                return user
            }

            logger.info("📭 User not found by email: \(email)")
            return nil

        } catch {
            logger.error("❌ Failed to search user by email: \(error)")
            throw UserError.searchFailed(error)
        }
    }

    func getAllUsers() async throws -> [User] {
        logger.info("📊 Getting all users")

        do {
            // Fetch from API (with retry macro applied)
            let users: [User] = try await network.fetchData(
                from: "users",
                type: [User].self
            )

            // Update local storage and cache
            for user in users {
                await updateCache(user: user)
                _ = try await database.save(user, to: "users")
            }

            logger.info("✅ Fetched \(users.count) users")
            return users

        } catch {
            logger.warning("⚠️ Failed to fetch from API, trying local database: \(error)")

            // Fallback to local database
            let localUsers: [User] = try await database.fetchAll(
                from: "users",
                type: User.self
            )

            logger.info("📱 Returned \(localUsers.count) users from local database")
            return localUsers
        }
    }

    func searchUsers(query: String) async throws -> [User] {
        logger.info("🔍 Searching users with query: \(query)")

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        do {
            // Search via API (with retry macro applied)
            let results: [User] = try await network.fetchData(
                from: "users/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                type: [User].self
            )

            // Cache results
            for user in results {
                await updateCache(user: user)
            }

            logger.info("✅ Search returned \(results.count) users")
            return results

        } catch {
            logger.error("❌ Search failed: \(error)")
            throw UserError.searchFailed(error)
        }
    }

    func updateUserPreferences(_ userId: String, preferences: UserPreferences) async throws -> Bool {
        logger.info("⚙️ Updating preferences for user: \(userId)")

        guard auth.isAuthenticated else {
            throw UserError.notAuthenticated
        }

        do {
            // Update via API (with retry macro applied)
            let success = try await network.postData(
                UpdatePreferencesRequest(userId: userId, preferences: preferences),
                to: "users/\(userId)/preferences"
            )

            if success {
                logger.info("✅ User preferences updated: \(userId)")
            } else {
                logger.warning("⚠️ Failed to update user preferences: \(userId)")
            }

            return success

        } catch {
            logger.error("❌ Failed to update preferences: \(error)")
            throw UserError.updateFailed(error)
        }
    }

    // MARK: - Cache Management

    private func setupCacheCleanup() {
        // Clean up cache every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                await self.cleanupExpiredCache()
            }
        }
    }

    private func getCachedUser(id: String) async -> User? {
        await cacheQueue.sync {
            self.userCache[id]
        }
    }

    private func updateCache(user: User) async {
        await cacheQueue.sync(flags: .barrier) {
            self.userCache[user.id] = user

            // Limit cache size
            if self.userCache.count > self.maxCacheSize {
                let keysToRemove = Array(userCache.keys.prefix(self.userCache.count - self.maxCacheSize))
                for key in keysToRemove {
                    self.userCache.removeValue(forKey: key)
                }
            }
        }
    }

    private func removeFromCache(userId: String) async {
        await cacheQueue.sync(flags: .barrier) {
            self.userCache.removeValue(forKey: userId)
        }
    }

    private func cleanupExpiredCache() async {
        await cacheQueue.sync(flags: .barrier) {
            // In a real implementation, you'd track cache timestamps
            // For demo purposes, we'll just limit the cache size
            if self.userCache.count > self.maxCacheSize / 2 {
                let keysToRemove = Array(userCache.keys.prefix(self.userCache.count - self.maxCacheSize / 2))
                for key in keysToRemove {
                    self.userCache.removeValue(forKey: key)
                }
            }
        }
    }

    // MARK: - Validation

    private func validateCreateUserRequest(_ request: CreateUserRequest) throws {
        guard !request.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw UserError.invalidName
        }

        guard !request.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw UserError.invalidEmail
        }

        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard request.email.range(of: emailRegex, options: .regularExpression) != nil else {
            throw UserError.invalidEmailFormat
        }
    }
}

// MARK: - User Errors

enum UserError: Error, LocalizedError {
    case userNotFound
    case userAlreadyExists
    case invalidName
    case invalidEmail
    case invalidEmailFormat
    case notAuthenticated
    case creationFailed(Error)
    case updateFailed(Error)
    case deletionFailed(Error)
    case fetchFailed(Error)
    case searchFailed(Error)
    case networkError(Error)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .userNotFound:
            "User not found"
        case .userAlreadyExists:
            "User already exists with this email"
        case .invalidName:
            "Invalid name provided"
        case .invalidEmail:
            "Invalid email provided"
        case .invalidEmailFormat:
            "Invalid email format"
        case .notAuthenticated:
            "User is not authenticated"
        case .creationFailed(let error):
            "Failed to create user: \(error.localizedDescription)"
        case .updateFailed(let error):
            "Failed to update user: \(error.localizedDescription)"
        case .deletionFailed(let error):
            "Failed to delete user: \(error.localizedDescription)"
        case .fetchFailed(let error):
            "Failed to fetch user: \(error.localizedDescription)"
        case .searchFailed(let error):
            "Search failed: \(error.localizedDescription)"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .serverError(let code):
            "Server error: \(code)"
        }
    }
}

// MARK: - Request Models

struct CreateUserRequest: Codable {
    let name: String
    let email: String
    let preferences: UserPreferences?
}

struct UpdateUserRequest: Codable {
    let name: String?
    let preferences: UserPreferences?
}

struct DeleteUserRequest: Codable {
    let userId: String
}

struct UpdatePreferencesRequest: Codable {
    let userId: String
    let preferences: UserPreferences
}

struct UserPreferences: Codable {
    let theme: String
    let notifications: Bool
    let language: String

    init(theme: String = "system", notifications: Bool = true, language: String = "en") {
        self.theme = theme
        self.notifications = notifications
        self.language = language
    }
}
