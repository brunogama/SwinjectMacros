// ContentView.swift - Main content view demonstrating @InjectedStateObject and dependency injection
// Copyright © 2025 SwinJectMacros Demo. All rights reserved.

import SwiftUI
import SwinjectUtilityMacros
import Swinject

struct ContentView: View {
    
    // MARK: - Injected Dependencies
    
    /// Content view model injected using @InjectedStateObject macro
    @InjectedStateObject var viewModel: ContentViewModelProtocol
    
    /// Navigation coordinator injected for routing
    @InjectedStateObject var navigationCoordinator: NavigationCoordinatorProtocol
    
    /// Theme service injected for theming
    @InjectedStateObject var themeService: ThemeServiceProtocol
    
    // MARK: - State
    
    @State private var searchText = ""
    @State private var showingRefreshAlert = false
    @State private var selectedUser: User?
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                themeService.getThemeColors().background
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("SwinJect Demo")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
            .searchable(text: $searchText, prompt: "Search users...")
            .onSubmit(of: .search) {
                Task {
                    await viewModel.searchUsers(searchText)
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(item: $navigationCoordinator.presentedSheet) { sheet in
                NavigationSheetView(sheet: sheet, coordinator: navigationCoordinator)
            }
            .alert(item: $navigationCoordinator.presentedAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK")) {
                        navigationCoordinator.dismissAlert()
                    }
                )
            }
        }
        .onAppear {
            Task {
                await viewModel.loadInitialData()
            }
        }
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                Task {
                    await viewModel.searchUsers("")
                }
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(themeService.getThemeFonts().headline)
                .foregroundColor(themeService.getThemeColors().secondaryText)
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Analytics Summary Card
                if let analyticsData = viewModel.analyticsData {
                    analyticsCard(analyticsData)
                }
                
                // Quick Actions Section
                quickActionsSection
                
                // Users Section
                usersSection
                
                // Demo Actions Section
                demoActionsSection
            }
            .padding()
        }
    }
    
    // MARK: - Analytics Card
    
    private func analyticsCard(_ data: AnalyticsReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(themeService.getThemeColors().accent)
                
                Text("Analytics Summary")
                    .font(themeService.getThemeFonts().headline)
                    .foregroundColor(themeService.getThemeColors().text)
                
                Spacer()
                
                if data.isLocalReport {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(themeService.getThemeColors().warning)
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(data.totalEvents)")
                        .font(themeService.getThemeFonts().title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeService.getThemeColors().primary)
                    Text("Total Events")
                        .font(themeService.getThemeFonts().caption1)
                        .foregroundColor(themeService.getThemeColors().secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("\(data.uniqueUsers)")
                        .font(themeService.getThemeFonts().title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeService.getThemeColors().accent)
                    Text("Unique Users")
                        .font(themeService.getThemeFonts().caption1)
                        .foregroundColor(themeService.getThemeColors().secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text(data.topEvents.first?.0 ?? "None")
                        .font(themeService.getThemeFonts().callout)
                        .fontWeight(.medium)
                        .foregroundColor(themeService.getThemeColors().text)
                        .lineLimit(1)
                    Text("Top Event")
                        .font(themeService.getThemeFonts().caption1)
                        .foregroundColor(themeService.getThemeColors().secondaryText)
                }
            }
        }
        .padding()
        .background(themeService.getThemeColors().surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeConstants.cornerRadius))
        .shadow(radius: ThemeConstants.shadowRadius)
        .onTapGesture {
            navigationCoordinator.presentSheet(.analyticsReport)
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(themeService.getThemeFonts().headline)
                .foregroundColor(themeService.getThemeColors().text)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                quickActionButton(
                    title: "Theme",
                    icon: "paintbrush.fill",
                    color: themeService.getThemeColors().primary
                ) {
                    navigationCoordinator.presentSheet(.themeSelector)
                }
                
                quickActionButton(
                    title: "Debug",
                    icon: "ladybug.fill",
                    color: themeService.getThemeColors().warning
                ) {
                    navigationCoordinator.presentSheet(.debugConsole)
                }
                
                quickActionButton(
                    title: "Settings",
                    icon: "gear.fill",
                    color: themeService.getThemeColors().secondary
                ) {
                    navigationCoordinator.navigate(to: .settings)
                }
            }
        }
    }
    
    private func quickActionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(themeService.getThemeFonts().caption1)
                    .foregroundColor(themeService.getThemeColors().text)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(themeService.getThemeColors().surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeConstants.cornerRadius))
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Users Section
    
    private var usersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Users (\(viewModel.users.count))")
                    .font(themeService.getThemeFonts().headline)
                    .foregroundColor(themeService.getThemeColors().text)
                
                Spacer()
                
                Button("View All") {
                    navigationCoordinator.navigate(to: .userList)
                }
                .font(themeService.getThemeFonts().callout)
                .foregroundColor(themeService.getThemeColors().accent)
            }
            
            if viewModel.users.isEmpty {
                emptyUsersView
            } else {
                usersList
            }
        }
    }
    
    private var emptyUsersView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.slash")
                .font(.system(size: 48))
                .foregroundColor(themeService.getThemeColors().secondaryText)
            
            Text("No users found")
                .font(themeService.getThemeFonts().headline)
                .foregroundColor(themeService.getThemeColors().secondaryText)
            
            Text("Create a demo user to get started")
                .font(themeService.getThemeFonts().body)
                .foregroundColor(themeService.getThemeColors().secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(themeService.getThemeColors().surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeConstants.cornerRadius))
    }
    
    private var usersList: some View {
        LazyVStack(spacing: 8) {
            ForEach(viewModel.users.prefix(5)) { user in
                userRow(user)
            }
        }
    }
    
    private func userRow(_ user: User) -> some View {
        HStack {
            // User Avatar
            Circle()
                .fill(themeService.getThemeColors().accent)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(themeService.getThemeFonts().headline)
                        .foregroundColor(.white)
                )
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.name)
                    .font(themeService.getThemeFonts().body)
                    .foregroundColor(themeService.getThemeColors().text)
                
                Text(user.email)
                    .font(themeService.getThemeFonts().caption1)
                    .foregroundColor(themeService.getThemeColors().secondaryText)
            }
            
            Spacer()
            
            // Actions
            Menu {
                Button("View Details") {
                    selectedUser = user
                    navigationCoordinator.navigate(to: .userDetail)
                }
                
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteUser(user.id)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(themeService.getThemeColors().secondaryText)
            }
        }
        .padding()
        .background(themeService.getThemeColors().surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeConstants.cornerRadius))
        .onTapGesture {
            selectedUser = user
            navigationCoordinator.navigate(to: .userDetail)
        }
    }
    
    // MARK: - Demo Actions Section
    
    private var demoActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Demo Actions")
                .font(themeService.getThemeFonts().headline)
                .foregroundColor(themeService.getThemeColors().text)
            
            VStack(spacing: 8) {
                demoActionButton(
                    title: "Create Demo User",
                    icon: "person.badge.plus",
                    color: themeService.getThemeColors().success
                ) {
                    Task {
                        await viewModel.createDemoUser()
                    }
                }
                
                demoActionButton(
                    title: "Refresh Data",
                    icon: "arrow.clockwise",
                    color: themeService.getThemeColors().primary
                ) {
                    Task {
                        await viewModel.refreshData()
                    }
                }
                
                if viewModel.isAuthenticated {
                    demoActionButton(
                        title: "Logout",
                        icon: "rectangle.portrait.and.arrow.right",
                        color: themeService.getThemeColors().error
                    ) {
                        showingLogoutConfirmation()
                    }
                }
            }
        }
    }
    
    private func demoActionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .font(themeService.getThemeFonts().body)
                    .foregroundColor(themeService.getThemeColors().text)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeService.getThemeColors().secondaryText)
            }
            .padding()
            .background(themeService.getThemeColors().surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeConstants.cornerRadius))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Toolbar Content
    
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    themeService.toggleTheme()
                }) {
                    Image(systemName: themeService.isDarkMode ? "sun.max.fill" : "moon.fill")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Analytics") {
                        navigationCoordinator.presentSheet(.analyticsReport)
                    }
                    
                    Button("Debug Console") {
                        navigationCoordinator.presentSheet(.debugConsole)
                    }
                    
                    Button("About") {
                        navigationCoordinator.navigate(to: .about)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func showingLogoutConfirmation() {
        let alert = AppAlert(
            title: "Logout",
            message: "Are you sure you want to logout?",
            severity: .warning,
            primaryAction: AppAlert.AlertAction(
                title: "Logout",
                style: .destructive
            ) {
                Task {
                    await viewModel.logout()
                }
            },
            secondaryAction: AppAlert.AlertAction(
                title: "Cancel",
                style: .cancel,
                handler: nil
            )
        )
        
        navigationCoordinator.presentAlert(alert)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a container for preview
        let container = Container()
        
        // Register mock services for preview
        container.register(LoggerServiceProtocol.self) { _ in
            MockLoggerService()
        }
        
        container.register(NetworkServiceProtocol.self) { resolver in
            MockNetworkService()
        }
        
        container.register(DatabaseServiceProtocol.self) { resolver in
            MockDatabaseService()
        }
        
        container.register(AuthenticationServiceProtocol.self) { resolver in
            MockAuthenticationService()
        }
        
        container.register(UserServiceProtocol.self) { resolver in
            MockUserService()
        }
        
        container.register(AnalyticsServiceProtocol.self) { resolver in
            MockAnalyticsService()
        }
        
        container.register(ThemeServiceProtocol.self) { resolver in
            MockThemeService()
        }
        
        container.register(NavigationCoordinatorProtocol.self) { resolver in
            MockNavigationCoordinator()
        }
        
        container.register(ContentViewModelProtocol.self) { resolver in
            MockContentViewModel()
        }
        
        return ContentView()
            .stateObjectContainer(container)
    }
}

// MARK: - Mock Services for Preview

class MockLoggerService: LoggerServiceProtocol {
    func info(_ message: String) { print("INFO: \(message)") }
    func warning(_ message: String) { print("WARN: \(message)") }
    func error(_ message: String) { print("ERROR: \(message)") }
}

class MockNetworkService: NetworkServiceProtocol {
    func fetchData<T: Codable>(from endpoint: String, type: T.Type) async throws -> T {
        throw NetworkError.noData
    }
    func postData<T: Codable>(_ data: T, to endpoint: String) async throws -> Bool { false }
    func uploadImage(_ imageData: Data, to endpoint: String) async throws -> String { "" }
}

class MockDatabaseService: DatabaseServiceProtocol {
    func save<T: Codable>(_ entity: T, to collection: String) async throws -> String { UUID().uuidString }
    func fetch<T: Codable>(from collection: String, id: String, type: T.Type) async throws -> T? { nil }
    func fetchAll<T: Codable>(from collection: String, type: T.Type) async throws -> [T] { [] }
    func delete(from collection: String, id: String) async throws -> Bool { true }
    func query<T: Codable>(from collection: String, where predicate: String, type: T.Type) async throws -> [T] { [] }
}

class MockAuthenticationService: AuthenticationServiceProtocol {
    var isAuthenticated = false
    func login(email: String, password: String) async throws -> AuthResult {
        throw AuthError.invalidCredentials
    }
    func logout() async throws {}
    func refreshToken() async throws -> String { "" }
    func getCurrentUser() async throws -> User? { nil }
    func validateSession() async throws -> Bool { false }
}

class MockUserService: UserServiceProtocol {
    func createUser(_ userData: CreateUserRequest) async throws -> User {
        User(name: userData.name, email: userData.email)
    }
    func updateUser(_ userId: String, with data: UpdateUserRequest) async throws -> User {
        User(name: data.name ?? "Unknown", email: "unknown@example.com")
    }
    func deleteUser(_ userId: String) async throws -> Bool { true }
    func getUser(by id: String) async throws -> User? { nil }
    func getUserByEmail(_ email: String) async throws -> User? { nil }
    func getAllUsers() async throws -> [User] { [] }
    func searchUsers(query: String) async throws -> [User] { [] }
    func updateUserPreferences(_ userId: String, preferences: UserPreferences) async throws -> Bool { true }
}

class MockAnalyticsService: AnalyticsServiceProtocol {
    func trackEvent(_ event: AnalyticsEvent) async {}
    func trackUserAction(_ action: UserAction, userId: String) async {}
    func trackScreenView(_ screenName: String, userId: String?) async {}
    func trackError(_ error: Error, context: [String: Any]?) async {}
    func trackPerformanceMetric(_ metric: PerformanceMetric) async {}
    func setUserProperties(_ properties: [String: Any], userId: String) async {}
    func flush() async throws {}
    func getAnalyticsReport(timeRange: TimeRange) async throws -> AnalyticsReport {
        AnalyticsReport(timeRange: timeRange, totalEvents: 0, uniqueUsers: 0, topEvents: [])
    }
}

class MockThemeService: ThemeServiceProtocol {
    @Published var currentTheme: AppTheme = .system
    @Published var isDarkMode = false
    func setTheme(_ theme: AppTheme) {}
    func toggleTheme() {}
    func applySystemTheme() {}
    func getThemeColors() -> ThemeColors { .light }
    func getThemeFonts() -> ThemeFonts { .system }
}

class MockNavigationCoordinator: NavigationCoordinatorProtocol {
    @Published var currentRoute: AppRoute = .home
    @Published var navigationStack: [AppRoute] = []
    @Published var presentedSheet: AppSheet?
    @Published var presentedAlert: AppAlert?
    func navigate(to route: AppRoute) {}
    func navigateBack() {}
    func navigateToRoot() {}
    func presentSheet(_ sheet: AppSheet) {}
    func dismissSheet() {}
    func presentAlert(_ alert: AppAlert) {}
    func dismissAlert() {}
    func canNavigateBack() -> Bool { false }
}

class MockContentViewModel: ContentViewModelProtocol {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var users: [User] = []
    @Published var analyticsData: AnalyticsReport?
    @Published var isAuthenticated = false
    func loadInitialData() async {}
    func refreshData() async {}
    func logout() async {}
    func trackScreenView() {}
    func clearError() {}
}