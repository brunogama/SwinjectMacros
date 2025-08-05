// NavigationCoordinator.swift - Navigation coordination service demonstrating @Injectable
// Copyright © 2025 SwinjectMacros Demo. All rights reserved.

import SwiftUI
import Swinject
import SwinjectMacros

// MARK: - Navigation Protocol

protocol NavigationCoordinatorProtocol: ObservableObject {
    var currentRoute: AppRoute { get }
    var navigationStack: [AppRoute] { get }
    var presentedSheet: AppSheet? { get }
    var presentedAlert: AppAlert? { get }

    func navigate(to route: AppRoute)
    func navigateBack()
    func navigateToRoot()
    func presentSheet(_ sheet: AppSheet)
    func dismissSheet()
    func presentAlert(_ alert: AppAlert)
    func dismissAlert()
    func canNavigateBack() -> Bool
}

// MARK: - Navigation Coordinator Implementation

@Injectable
class NavigationCoordinator: NavigationCoordinatorProtocol {

    // Published properties for SwiftUI
    @Published var currentRoute: AppRoute = .home
    @Published var navigationStack: [AppRoute] = []
    @Published var presentedSheet: AppSheet? = nil
    @Published var presentedAlert: AppAlert? = nil

    // Dependencies
    private let logger: LoggerServiceProtocol
    private let analytics: AnalyticsServiceProtocol

    // Navigation history for analytics
    private var navigationHistory: [NavigationEvent] = []
    private let maxHistorySize = 100

    init(
        logger: LoggerServiceProtocol,
        analytics: AnalyticsServiceProtocol
    ) {
        self.logger = logger
        self.analytics = analytics

        logger.info("🧭 NavigationCoordinator initialized")
        setupNavigationTracking()
    }

    // MARK: - NavigationCoordinatorProtocol Implementation

    func navigate(to route: AppRoute) {
        logger.info("🧭 Navigating to: \(route)")

        let previousRoute = currentRoute
        currentRoute = route
        navigationStack.append(route)

        // Track navigation event
        trackNavigationEvent(
            from: previousRoute,
            to: route,
            action: .navigate,
            timestamp: Date()
        )

        // Limit stack size to prevent memory issues
        if navigationStack.count > 50 {
            navigationStack.removeFirst(10)
            logger.warning("⚠️ Navigation stack trimmed due to size")
        }
    }

    func navigateBack() {
        guard canNavigateBack() else {
            logger.warning("⚠️ Cannot navigate back - no previous route")
            return
        }

        let previousRoute = currentRoute
        navigationStack.removeLast()

        if let lastRoute = navigationStack.last {
            currentRoute = lastRoute
        } else {
            currentRoute = .home
        }

        logger.info("🔙 Navigated back to: \(currentRoute)")

        // Track navigation event
        trackNavigationEvent(
            from: previousRoute,
            to: currentRoute,
            action: .back,
            timestamp: Date()
        )
    }

    func navigateToRoot() {
        let previousRoute = currentRoute
        currentRoute = .home
        navigationStack = [.home]

        logger.info("🏠 Navigated to root")

        // Track navigation event
        trackNavigationEvent(
            from: previousRoute,
            to: .home,
            action: .root,
            timestamp: Date()
        )
    }

    func presentSheet(_ sheet: AppSheet) {
        logger.info("📋 Presenting sheet: \(sheet)")

        presentedSheet = sheet

        // Track sheet presentation
        Task {
            await self.analytics.trackUserAction(.tap, userId: "current_user")
            await self.analytics.trackScreenView("sheet_\(sheet.rawValue)", userId: "current_user")
        }
    }

    func dismissSheet() {
        guard let sheet = presentedSheet else {
            logger.warning("⚠️ No sheet to dismiss")
            return
        }

        logger.info("❌ Dismissing sheet: \(sheet)")
        presentedSheet = nil

        // Track sheet dismissal
        Task {
            await self.analytics.trackUserAction(.tap, userId: "current_user")
        }
    }

    func presentAlert(_ alert: AppAlert) {
        logger.info("🚨 Presenting alert: \(alert.title)")

        presentedAlert = alert

        // Track alert presentation
        Task {
            await self.analytics.trackEvent(AnalyticsEvent(
                name: "alert_presented",
                properties: [
                    "alert_type": alert.title,
                    "severity": alert.severity.rawValue
                ]
            ))
        }
    }

    func dismissAlert() {
        guard let alert = presentedAlert else {
            logger.warning("⚠️ No alert to dismiss")
            return
        }

        logger.info("❌ Dismissing alert: \(alert.title)")
        presentedAlert = nil

        // Track alert dismissal
        Task {
            await self.analytics.trackEvent(AnalyticsEvent(
                name: "alert_dismissed",
                properties: [
                    "alert_type": alert.title
                ]
            ))
        }
    }

    func canNavigateBack() -> Bool {
        navigationStack.count > 1
    }

    // MARK: - Navigation Tracking

    private func setupNavigationTracking() {
        // Track initial route
        trackNavigationEvent(
            from: .home,
            to: .home,
            action: .initial,
            timestamp: Date()
        )
    }

    private func trackNavigationEvent(
        from: AppRoute,
        to: AppRoute,
        action: NavigationAction,
        timestamp: Date
    ) {
        let event = NavigationEvent(
            from: from,
            to: to,
            action: action,
            timestamp: timestamp,
            stackDepth: navigationStack.count
        )

        navigationHistory.append(event)

        // Limit history size
        if navigationHistory.count > maxHistorySize {
            navigationHistory.removeFirst(10)
        }

        // Track in analytics
        Task {
            await self.analytics.trackEvent(AnalyticsEvent(
                name: "navigation",
                properties: [
                    "from_route": from.rawValue,
                    "to_route": to.rawValue,
                    "action": action.rawValue,
                    "stack_depth": self.navigationStack.count
                ]
            ))

            await self.analytics.trackScreenView(to.rawValue, userId: "current_user")
        }
    }

    // MARK: - Navigation Analytics

    func getNavigationAnalytics() -> NavigationAnalytics {
        let totalNavigations = navigationHistory.count
        let routeCounts = navigationHistory.reduce(into: [String: Int]()) { counts, event in
            counts[event.to.rawValue, default: 0] += 1
        }

        let mostVisitedRoutes = routeCounts.sorted { $0.value > $1.value }.prefix(5)
        let averageStackDepth = navigationHistory.isEmpty ? 0 :
            Double(navigationHistory.map { $0.stackDepth }.reduce(0, +)) / Double(navigationHistory.count)

        return NavigationAnalytics(
            totalNavigations: totalNavigations,
            mostVisitedRoutes: Array(mostVisitedRoutes),
            averageStackDepth: averageStackDepth,
            currentStackDepth: navigationStack.count,
            generatedAt: Date()
        )
    }
}

// MARK: - Navigation Models

enum AppRoute: String, CaseIterable, Identifiable {
    case home = "home"
    case profile = "profile"
    case settings = "settings"
    case userList = "user_list"
    case userDetail = "user_detail"
    case analytics = "analytics"
    case debug = "debug"
    case about = "about"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .home: "Home"
        case .profile: "Profile"
        case .settings: "Settings"
        case .userList: "Users"
        case .userDetail: "User Details"
        case .analytics: "Analytics"
        case .debug: "Debug"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .profile: "person.fill"
        case .settings: "gear.fill"
        case .userList: "person.3.fill"
        case .userDetail: "person.crop.circle.fill"
        case .analytics: "chart.bar.fill"
        case .debug: "ladybug.fill"
        case .about: "info.circle.fill"
        }
    }
}

enum AppSheet: String, CaseIterable {
    case createUser = "create_user"
    case editProfile = "edit_profile"
    case themeSelector = "theme_selector"
    case debugConsole = "debug_console"
    case analyticsReport = "analytics_report"
    case appSettings = "app_settings"

    var displayName: String {
        switch self {
        case .createUser: "Create User"
        case .editProfile: "Edit Profile"
        case .themeSelector: "Theme Selector"
        case .debugConsole: "Debug Console"
        case .analyticsReport: "Analytics Report"
        case .appSettings: "App Settings"
        }
    }
}

struct AppAlert {
    let title: String
    let message: String
    let severity: AlertSeverity
    let primaryAction: AlertAction?
    let secondaryAction: AlertAction?

    enum AlertSeverity: String {
        case info = "info"
        case warning = "warning"
        case error = "error"
        case success = "success"
    }

    struct AlertAction {
        let title: String
        let style: ActionStyle
        let handler: (() -> Void)?

        enum ActionStyle {
            case `default`
            case cancel
            case destructive
        }
    }

    // Convenience initializers
    static func error(
        title: String = "Error",
        message: String,
        action: AlertAction? = nil
    ) -> AppAlert {
        AppAlert(
            title: title,
            message: message,
            severity: .error,
            primaryAction: action,
            secondaryAction: nil
        )
    }

    static func warning(
        title: String = "Warning",
        message: String,
        primaryAction: AlertAction? = nil,
        secondaryAction: AlertAction? = nil
    ) -> AppAlert {
        AppAlert(
            title: title,
            message: message,
            severity: .warning,
            primaryAction: primaryAction,
            secondaryAction: secondaryAction
        )
    }

    static func info(
        title: String = "Information",
        message: String
    ) -> AppAlert {
        AppAlert(
            title: title,
            message: message,
            severity: .info,
            primaryAction: AlertAction(
                title: "OK",
                style: .default,
                handler: nil
            ),
            secondaryAction: nil
        )
    }

    static func success(
        title: String = "Success",
        message: String
    ) -> AppAlert {
        AppAlert(
            title: title,
            message: message,
            severity: .success,
            primaryAction: AlertAction(
                title: "OK",
                style: .default,
                handler: nil
            ),
            secondaryAction: nil
        )
    }
}

enum NavigationAction: String {
    case initial = "initial"
    case navigate = "navigate"
    case back = "back"
    case root = "root"
    case replace = "replace"
}

struct NavigationEvent {
    let from: AppRoute
    let to: AppRoute
    let action: NavigationAction
    let timestamp: Date
    let stackDepth: Int
}

struct NavigationAnalytics {
    let totalNavigations: Int
    let mostVisitedRoutes: [(String, Int)]
    let averageStackDepth: Double
    let currentStackDepth: Int
    let generatedAt: Date
}

// MARK: - SwiftUI Integration

struct NavigationCoordinatorEnvironmentKey: EnvironmentKey {
    static let defaultValue: NavigationCoordinatorProtocol? = nil
}

extension EnvironmentValues {
    var navigationCoordinator: NavigationCoordinatorProtocol? {
        get { self[NavigationCoordinatorEnvironmentKey.self] }
        set { self[NavigationCoordinatorEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    func navigationCoordinator(_ coordinator: NavigationCoordinatorProtocol) -> some View {
        environment(\.navigationCoordinator, coordinator)
    }

    func handleNavigationSheet(
        item: Binding<AppSheet?>,
        coordinator: NavigationCoordinatorProtocol
    ) -> some View {
        sheet(item: item) { sheet in
            NavigationSheetView(sheet: sheet, coordinator: coordinator)
        }
    }

    func handleNavigationAlert(
        alert: Binding<AppAlert?>,
        coordinator: NavigationCoordinatorProtocol
    ) -> some View {
        self.alert(item: alert) { alertItem in
            Alert(
                title: Text(alertItem.title),
                message: Text(alertItem.message),
                primaryButton: alertItem.primaryAction.map { action in
                    Alert.Button.default(Text(action.title)) {
                        action.handler?()
                        coordinator.dismissAlert()
                    }
                } ?? .default(Text("OK")) {
                    coordinator.dismissAlert()
                },
                secondaryButton: alertItem.secondaryAction.map { action in
                    Alert.Button.cancel(Text(action.title)) {
                        action.handler?()
                        coordinator.dismissAlert()
                    }
                }
            )
        }
    }
}

// Helper for AppAlert to conform to Identifiable
extension AppAlert: Identifiable {
    var id: String {
        "\(title)_\(message)_\(severity.rawValue)"
    }
}

// Helper for AppSheet to conform to Identifiable
extension AppSheet: Identifiable {
    var id: String { rawValue }
}

// MARK: - Navigation Sheet View

struct NavigationSheetView: View {
    let sheet: AppSheet
    let coordinator: NavigationCoordinatorProtocol

    var body: some View {
        NavigationView {
            Group {
                switch sheet {
                case .createUser:
                    Text("Create User Sheet")
                case .editProfile:
                    Text("Edit Profile Sheet")
                case .themeSelector:
                    Text("Theme Selector Sheet")
                case .debugConsole:
                    Text("Debug Console Sheet")
                case .analyticsReport:
                    Text("Analytics Report Sheet")
                case .appSettings:
                    Text("App Settings Sheet")
                }
            }
            .navigationTitle(sheet.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        coordinator.dismissSheet()
                    }
                }
            }
        }
    }
}
