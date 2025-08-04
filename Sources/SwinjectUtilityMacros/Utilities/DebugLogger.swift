// DebugLogger.swift - Conditional debug logging utility
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation
import os.log

/// Debug logging utility that only outputs in DEBUG builds
public enum DebugLogger {

    /// Shared logger instance for os_log
    private static let logger = Logger(subsystem: "com.swinject.utilities", category: "DependencyInjection")

    /// Cache for file names to avoid repeated URL operations
    private static var fileNameCache: [String: String] = [:]
    private static let cachelock = NSLock()

    /// Environment variable to control debug logging
    private static let isDebugLoggingEnabled: Bool = {
        #if DEBUG
            return ProcessInfo.processInfo.environment["SWINJECT_DEBUG"] == "1"
        #else
            return false
        #endif
    }()

    /// Log level for filtering messages
    public enum Level: Int, Comparable {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4

        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var prefix: String {
            switch self {
            case .verbose: "[VERBOSE]"
            case .debug: "[DEBUG]"
            case .info: "[INFO]"
            case .warning: "[WARNING]"
            case .error: "[ERROR]"
            }
        }
    }

    /// Current minimum log level
    private static var _minimumLevel: Level = .info
    private static let levelLock = NSLock()

    /// Set the minimum log level
    public static func setMinimumLevel(_ level: Level) {
        levelLock.lock()
        defer { levelLock.unlock() }
        _minimumLevel = level
    }

    /// Get the current minimum log level (thread-safe)
    private static var minimumLevel: Level {
        levelLock.lock()
        defer { levelLock.unlock() }
        return _minimumLevel
    }

    /// Get cached file name or compute and cache it
    private static func getCachedFileName(for filePath: String) -> String {
        cachelock.lock()
        defer { cachelock.unlock() }

        if let cached = fileNameCache[filePath] {
            return cached
        }

        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        fileNameCache[filePath] = fileName
        return fileName
    }

    /// Log a message at the specified level
    public static func log(
        _ message: @autoclosure () -> String,
        level: Level = .debug,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isDebugLoggingEnabled && level >= minimumLevel else { return }

        let fileName = getCachedFileName(for: file)
        let logMessage = "[\(fileName):\(line)] \(function) - \(message())"

        #if DEBUG
            switch level {
            case .verbose:
                logger.trace("\(logMessage)")
            case .debug:
                logger.debug("\(logMessage)")
            case .info:
                logger.info("\(logMessage)")
            case .warning:
                logger.warning("\(logMessage)")
            case .error:
                logger.error("\(logMessage)")
            }
        #endif
    }

    /// Log verbose message
    public static func verbose(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .verbose, file: file, function: function, line: line)
    }

    /// Log debug message
    public static func debug(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .debug, file: file, function: function, line: line)
    }

    /// Log info message
    public static func info(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .info, file: file, function: function, line: line)
    }

    /// Log warning message
    public static func warning(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .warning, file: file, function: function, line: line)
    }

    /// Log error message
    public static func error(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .error, file: file, function: function, line: line)
    }

    /// Log performance metrics
    public static func performance(
        _ operation: String,
        duration: TimeInterval,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let formattedDuration = String(format: "%.4f", duration)
        let message = "Performance: \(operation) took \(formattedDuration) seconds"
        log(message, level: .debug, file: file, function: function, line: line)
    }

    /// Log dependency graph information
    public static func graph(
        _ message: @autoclosure () -> String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log("[GRAPH] \(message())", level: .debug, file: file, function: function, line: line)
    }
}
