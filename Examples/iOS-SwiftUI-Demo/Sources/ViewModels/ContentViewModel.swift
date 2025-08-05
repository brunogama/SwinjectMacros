// ContentViewModel.swift - Main content view model demonstrating @Injectable and dependency injection patterns
// Copyright © 2025 SwinjectMacros Demo. All rights reserved.

import Combine
import SwiftUI
import Swinject
import SwinjectMacros

// MARK: - Content View Model Protocol

protocol ContentViewModelProtocol: ObservableObject {
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var users: [User] { get }
    var analyticsData: AnalyticsReport? { get }
    var isAuthenticated: Bool { get }

    func loadInitialData() async
    func refreshData() async
    func logout() async
    func trackScreenView()
    func clearError()
}

// MARK: - Content View Model Implementation

@Injectable
class ContentViewModel: ContentViewModelProtocol {

    // Published properties for SwiftUI reactivity
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var users: [User] = []
    @Published var analyticsData: AnalyticsReport?
    @Published var isAuthenticated = false

    // Dependencies injected via constructor
    private let userService: UserServiceProtocol
    private let authService: AuthenticationServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol
    private let navigationCoordinator: NavigationCoordinatorProtocol
    private let logger: LoggerServiceProtocol

    // Reactive subscriptions
    private var cancellables = Set<AnyCancellable>()

    init(
        userService: UserServiceProtocol,
        authService: AuthenticationServiceProtocol,
        analyticsService: AnalyticsServiceProtocol,
        navigationCoordinator: NavigationCoordinatorProtocol,
        logger: LoggerServiceProtocol
    ) {
        self.userService = userService
        self.authService = authService
        self.analyticsService = analyticsService
        self.navigationCoordinator = navigationCoordinator
        self.logger = logger

        logger.info("📱 ContentViewModel initialized with dependency injection")
        setupBindings()
        trackScreenView()
    }

    // MARK: - ContentViewModelProtocol Implementation

    @MainActor
    func loadInitialData() async {
        logger.info("📊 Loading initial data")
        isLoading = true
        errorMessage = nil

        do {
            // Load data concurrently
            async let usersResult = loadUsers()
            async let analyticsResult = loadAnalytics()
            async let authResult = checkAuthenticationStatus()

            // Wait for all operations to complete
            _ = try await (usersResult, analyticsResult, authResult)

            logger.info("✅ Initial data loaded successfully")

        } catch {
            logger.error("❌ Failed to load initial data: \(error)")
            errorMessage = "Failed to load data: \(error.localizedDescription)"

            // Track error in analytics
            await analyticsService.trackError(error, context: [
                "operation": "load_initial_data",
                "view": "content"
            ])
        }

        isLoading = false
    }

    @MainActor
    func refreshData() async {
        logger.info("🔄 Refreshing data")

        do {
            // Refresh all data
            async let usersRefresh = loadUsers()
            async let analyticsRefresh = loadAnalytics()

            _ = try await (usersRefresh, analyticsRefresh)

            logger.info("✅ Data refreshed successfully")

            // Track refresh action
            await analyticsService.trackUserAction(.swipe, userId: getCurrentUserId())

        } catch {
            logger.error("❌ Failed to refresh data: \(error)")
            errorMessage = "Failed to refresh: \(error.localizedDescription)"

            await analyticsService.trackError(error, context: [
                "operation": "refresh_data",
                "view": "content"
            ])
        }
    }

    @MainActor
    func logout() async {
        logger.info("🚪 Logging out user")

        do {
            await analyticsService.trackUserAction(.logout, userId: getCurrentUserId())
            try await authService.logout()

            // Clear user-specific data
            users = []
            analyticsData = nil
            isAuthenticated = false

            // Navigate to login
            navigationCoordinator.navigateToRoot()

            logger.info("✅ Logout successful")

        } catch {
            logger.error("❌ Logout failed: \(error)")
            errorMessage = "Logout failed: \(error.localizedDescription)"

            await analyticsService.trackError(error, context: [
                "operation": "logout",
                "view": "content"
            ])
        }
    }

    func trackScreenView() {
        Task {
            await self.analyticsService.trackScreenView("content_main", userId: self.getCurrentUserId())
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Monitor authentication state changes
        // In a real app, authService would publish authentication state changes
        logger.info("🔗 Setting up reactive bindings")
    }

    private func loadUsers() async throws {
        logger.info("👥 Loading users")

        let loadedUsers = try await userService.getAllUsers()

        await MainActor.run {
            self.users = loadedUsers
        }

        logger.info("✅ Loaded \(loadedUsers.count) users")
    }

    private func loadAnalytics() async throws {
        logger.info("📊 Loading analytics data")

        let timeRange = TimeRange.lastDay()
        let report = try await analyticsService.getAnalyticsReport(timeRange: timeRange)

        await MainActor.run {
            self.analyticsData = report
        }

        logger.info("✅ Analytics data loaded")
    }

    private func checkAuthenticationStatus() async throws {
        logger.info("🔐 Checking authentication status")

        let authenticated = authService.isAuthenticated
        let validSession = try await authService.validateSession()

        await MainActor.run {
            self.isAuthenticated = authenticated && validSession
        }

        logger.info("✅ Authentication status: \(authenticated && validSession)")
    }

    private func getCurrentUserId() -> String? {
        // In a real app, you'd get this from the auth service
        isAuthenticated ? "current_user" : nil
    }
}

// MARK: - Demo Data Extensions

extension ContentViewModel {

    /// Create demo user for testing purposes
    func createDemoUser() async {
        logger.info("👤 Creating demo user")

        do {
            let demoUserRequest = CreateUserRequest(
                name: "Demo User \(users.count + 1)",
                email: "demo\(users.count + 1)@example.com",
                preferences: UserPreferences()
            )

            let newUser = try await userService.createUser(demoUserRequest)

            await MainActor.run {
                self.users.append(newUser)
            }

            // Track user creation
            await analyticsService.trackEvent(AnalyticsEvent(
                name: "demo_user_created",
                properties: [
                    "user_id": newUser.id,
                    "user_name": newUser.name
                ]
            ))

            logger.info("✅ Demo user created: \(newUser.name)")

        } catch {
            logger.error("❌ Failed to create demo user: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to create demo user: \(error.localizedDescription)"
            }

            await analyticsService.trackError(error, context: [
                "operation": "create_demo_user",
                "view": "content"
            ])
        }
    }

    /// Delete user by ID
    func deleteUser(_ userId: String) async {
        logger.info("🗑️ Deleting user: \(userId)")

        do {
            let success = try await userService.deleteUser(userId)

            if success {
                await MainActor.run {
                    self.users.removeAll { $0.id == userId }
                }

                // Track user deletion
                await analyticsService.trackEvent(AnalyticsEvent(
                    name: "user_deleted",
                    properties: [
                        "user_id": userId
                    ],
                    userId: getCurrentUserId()
                ))

                logger.info("✅ User deleted successfully")
            } else {
                throw UserError.deletionFailed(NSError(
                    domain: "UserDeletion",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Deletion returned false"]
                ))
            }

        } catch {
            logger.error("❌ Failed to delete user: \(error)")
            await MainActor.run {
                self.errorMessage = "Failed to delete user: \(error.localizedDescription)"
            }

            await analyticsService.trackError(error, context: [
                "operation": "delete_user",
                "user_id": userId,
                "view": "content"
            ])
        }
    }

    /// Search users with query
    func searchUsers(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // If query is empty, reload all users
            await loadUsers()
            return
        }

        logger.info("🔍 Searching users with query: \(query)")

        do {
            let searchResults = try await userService.searchUsers(query: query)

            await MainActor.run {
                self.users = searchResults
            }

            // Track search
            await analyticsService.trackEvent(AnalyticsEvent(
                name: "user_search",
                properties: [
                    "query": query,
                    "results_count": searchResults.count
                ],
                userId: getCurrentUserId()
            ))

            logger.info("✅ Search completed: \(searchResults.count) results")

        } catch {
            logger.error("❌ Search failed: \(error)")
            await MainActor.run {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
            }

            await analyticsService.trackError(error, context: [
                "operation": "search_users",
                "query": query,
                "view": "content"
            ])
        }
    }

    /// Get analytics summary for display
    var analyticsSummary: String {
        guard let data = analyticsData else {
            return "No analytics data available"
        }

        return """
        Total Events: \(data.totalEvents)
        Unique Users: \(data.uniqueUsers)
        Top Event: \(data.topEvents.first?.0 ?? "None")
        Generated: \(DateFormatter.localizedString(from: data.generatedAt, dateStyle: .short, timeStyle: .short))
        """
    }

    /// Check if data needs refresh based on last update time
    var needsRefresh: Bool {
        guard let data = analyticsData else { return true }
        return Date().timeIntervalSince(data.generatedAt) > 300 // 5 minutes
    }
}

// MARK: - Error Handling

extension ContentViewModel {

    /// Handle common errors with user-friendly messages
    private func handleError(_ error: Error, operation: String) async {
        let userFriendlyMessage: String = switch error {
        case let userError as UserError:
            userError.localizedDescription
        case let authError as AuthError:
            authError.localizedDescription
        case let networkError as NetworkError:
            "Network issue: \(networkError.localizedDescription)"
        case let analyticsError as AnalyticsError:
            "Analytics issue: \(analyticsError.localizedDescription)"
        default:
            "An unexpected error occurred"
        }

        await MainActor.run {
            self.errorMessage = userFriendlyMessage
        }

        // Track error in analytics
        await analyticsService.trackError(error, context: [
            "operation": operation,
            "view": "content",
            "error_type": String(describing: type(of: error))
        ])

        logger.error("❌ \(operation) failed: \(error)")
    }
}

// MARK: - Performance Tracking

extension ContentViewModel {

    /// Track performance metrics for operations
    private func trackPerformanceMetric(name: String, startTime: Date) async {
        let duration = Date().timeIntervalSince(startTime)

        let metric = PerformanceMetric(
            name: name,
            value: duration,
            unit: "seconds",
            tags: [
                "view": "content",
                "operation": name
            ]
        )

        await analyticsService.trackPerformanceMetric(metric)
    }

    /// Measure and track the performance of an async operation
    private func measurePerformance<T>(
        operation: String,
        block: () async throws -> T
    ) async throws -> T {
        let startTime = Date()

        do {
            let result = try await block()
            await trackPerformanceMetric(name: operation, startTime: startTime)
            return result
        } catch {
            await trackPerformanceMetric(name: "\(operation)_failed", startTime: startTime)
            throw error
        }
    }
}
