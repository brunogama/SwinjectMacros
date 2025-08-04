// ThemeService.swift - Theme management service demonstrating @Injectable and @ScopedService
// Copyright © 2025 SwinJectMacros Demo. All rights reserved.

import SwiftUI
import Swinject
import SwinjectUtilityMacros

// MARK: - Theme Protocol

protocol ThemeServiceProtocol: ObservableObject {
    var currentTheme: AppTheme { get }
    var isDarkMode: Bool { get }

    func setTheme(_ theme: AppTheme)
    func toggleTheme()
    func applySystemTheme()
    func getThemeColors() -> ThemeColors
    func getThemeFonts() -> ThemeFonts
}

// MARK: - Theme Service Implementation

@Injectable
@ScopedService(.container)
class ThemeService: ThemeServiceProtocol {

    // Published properties for SwiftUI reactivity
    @Published var currentTheme: AppTheme = .system
    @Published var isDarkMode = false

    // Dependencies
    private let logger: LoggerServiceProtocol
    private let database: DatabaseServiceProtocol

    // Theme colors and fonts
    private var themeColors: ThemeColors = .light
    private var themeFonts: ThemeFonts = .system

    init(
        logger: LoggerServiceProtocol,
        database: DatabaseServiceProtocol
    ) {
        self.logger = logger
        self.database = database

        logger.info("🎨 ThemeService initialized with container scope")
        loadSavedTheme()
        setupThemeObservation()
    }

    // MARK: - ThemeServiceProtocol Implementation

    func setTheme(_ theme: AppTheme) {
        logger.info("🎨 Setting theme to: \(theme)")

        currentTheme = theme
        updateThemeProperties()
        saveTheme()

        // Notify analytics
        Task {
            // In a real app, you'd inject analytics service
            self.logger.info("📊 Theme change tracked: \(theme)")
        }
    }

    func toggleTheme() {
        let newTheme: AppTheme = switch currentTheme {
        case .light:
            .dark
        case .dark:
            .light
        case .system:
            isDarkMode ? .light : .dark
        }

        setTheme(newTheme)
        logger.info("🔄 Theme toggled to: \(newTheme)")
    }

    func applySystemTheme() {
        logger.info("🔧 Applying system theme")
        setTheme(.system)
    }

    func getThemeColors() -> ThemeColors {
        themeColors
    }

    func getThemeFonts() -> ThemeFonts {
        themeFonts
    }

    // MARK: - Private Methods

    private func loadSavedTheme() {
        Task { @MainActor in
            do {
                if let savedThemeData: ThemeData = try await database.fetch(
                    from: "user_preferences",
                    id: "theme",
                    type: ThemeData.self
                ) {
                    let savedTheme = AppTheme(rawValue: savedThemeData.themeName) ?? .system
                    self.currentTheme = savedTheme
                    self.updateThemeProperties()
                    self.logger.info("✅ Loaded saved theme: \(savedTheme)")
                } else {
                    self.logger.info("ℹ️ No saved theme found, using system default")
                }
            } catch {
                self.logger.warning("⚠️ Failed to load saved theme: \(error)")
            }
        }
    }

    private func saveTheme() {
        Task {
            do {
                let themeData = ThemeData(
                    themeName: currentTheme.rawValue,
                    isDarkMode: self.isDarkMode,
                    lastUpdated: Date()
                )

                _ = try await self.database.save(themeData, to: "user_preferences")
                self.logger.info("💾 Theme saved successfully")
            } catch {
                self.logger.warning("⚠️ Failed to save theme: \(error)")
            }
        }
    }

    private func setupThemeObservation() {
        // Listen for system theme changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateSystemThemeIfNeeded()
        }
    }

    private func updateSystemThemeIfNeeded() {
        if currentTheme == .system {
            updateThemeProperties()
        }
    }

    private func updateThemeProperties() {
        let wasInDarkMode = isDarkMode

        switch currentTheme {
        case .light:
            isDarkMode = false
            themeColors = .light
        case .dark:
            isDarkMode = true
            themeColors = .dark
        case .system:
            // Detect system theme
            if #available(iOS 13.0, *) {
                isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            } else {
                isDarkMode = false
            }
            themeColors = isDarkMode ? .dark : .light
        }

        // Update fonts based on theme
        themeFonts = isDarkMode ? .darkTheme : .lightTheme

        if wasInDarkMode != isDarkMode {
            logger.info("🌓 Dark mode changed: \(isDarkMode)")
        }
    }
}

// MARK: - Theme Models

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var icon: String {
        switch self {
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        case .system: "gear"
        }
    }
}

struct ThemeColors {
    let background: Color
    let secondaryBackground: Color
    let surface: Color
    let primary: Color
    let secondary: Color
    let accent: Color
    let text: Color
    let secondaryText: Color
    let border: Color
    let error: Color
    let warning: Color
    let success: Color

    static let light = ThemeColors(
        background: Color(UIColor.systemBackground),
        secondaryBackground: Color(UIColor.secondarySystemBackground),
        surface: Color(UIColor.systemGroupedBackground),
        primary: Color.blue,
        secondary: Color.gray,
        accent: Color.orange,
        text: Color(UIColor.label),
        secondaryText: Color(UIColor.secondaryLabel),
        border: Color(UIColor.separator),
        error: Color.red,
        warning: Color.yellow,
        success: Color.green
    )

    static let dark = ThemeColors(
        background: Color(UIColor.systemBackground),
        secondaryBackground: Color(UIColor.secondarySystemBackground),
        surface: Color(UIColor.systemGroupedBackground),
        primary: Color.blue,
        secondary: Color.gray,
        accent: Color.orange,
        text: Color(UIColor.label),
        secondaryText: Color(UIColor.secondaryLabel),
        border: Color(UIColor.separator),
        error: Color.red,
        warning: Color.yellow,
        success: Color.green
    )
}

struct ThemeFonts {
    let largeTitle: Font
    let title1: Font
    let title2: Font
    let title3: Font
    let headline: Font
    let body: Font
    let callout: Font
    let subheadline: Font
    let footnote: Font
    let caption1: Font
    let caption2: Font

    static let system = ThemeFonts(
        largeTitle: .largeTitle,
        title1: .title,
        title2: .title2,
        title3: .title3,
        headline: .headline,
        body: .body,
        callout: .callout,
        subheadline: .subheadline,
        footnote: .footnote,
        caption1: .caption,
        caption2: .caption2
    )

    static let lightTheme = ThemeFonts(
        largeTitle: .system(.largeTitle, design: .default, weight: .bold),
        title1: .system(.title, design: .default, weight: .bold),
        title2: .system(.title2, design: .default, weight: .semibold),
        title3: .system(.title3, design: .default, weight: .medium),
        headline: .system(.headline, design: .default, weight: .semibold),
        body: .system(.body, design: .default, weight: .regular),
        callout: .system(.callout, design: .default, weight: .regular),
        subheadline: .system(.subheadline, design: .default, weight: .regular),
        footnote: .system(.footnote, design: .default, weight: .regular),
        caption1: .system(.caption, design: .default, weight: .regular),
        caption2: .system(.caption2, design: .default, weight: .regular)
    )

    static let darkTheme = ThemeFonts(
        largeTitle: .system(.largeTitle, design: .default, weight: .heavy),
        title1: .system(.title, design: .default, weight: .bold),
        title2: .system(.title2, design: .default, weight: .semibold),
        title3: .system(.title3, design: .default, weight: .medium),
        headline: .system(.headline, design: .default, weight: .semibold),
        body: .system(.body, design: .default, weight: .regular),
        callout: .system(.callout, design: .default, weight: .regular),
        subheadline: .system(.subheadline, design: .default, weight: .regular),
        footnote: .system(.footnote, design: .default, weight: .regular),
        caption1: .system(.caption, design: .default, weight: .regular),
        caption2: .system(.caption2, design: .default, weight: .regular)
    )
}

struct ThemeData: Codable {
    let themeName: String
    let isDarkMode: Bool
    let lastUpdated: Date
}

// MARK: - Theme Environment

struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeServiceProtocol? = nil
}

extension EnvironmentValues {
    var themeService: ThemeServiceProtocol? {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - SwiftUI Extensions

extension View {
    func themeColors(_ colors: ThemeColors) -> some View {
        environment(\.colorScheme, colors.background == ThemeColors.dark.background ? .dark : .light)
    }

    func themeFonts(_ fonts: ThemeFonts) -> some View {
        self // In a real app, you'd apply font modifiers
    }

    func themedBackground() -> some View {
        background(Color(UIColor.systemBackground))
    }

    func themedSurface() -> some View {
        background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Theme Constants

enum ThemeConstants {
    static let cornerRadius: CGFloat = 12
    static let shadowRadius: CGFloat = 4
    static let borderWidth: CGFloat = 1
    static let animationDuration = 0.3

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Layout {
        static let maxContentWidth: CGFloat = 375
        static let cardHeight: CGFloat = 120
        static let buttonHeight: CGFloat = 44
        static let textFieldHeight: CGFloat = 40
    }
}
