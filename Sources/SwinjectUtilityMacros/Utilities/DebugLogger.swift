// DebugLogger.swift - Conditional debug logging utility
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation

/// Debug logging utility that only outputs in DEBUG builds
public struct DebugLogger {

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
            case .verbose: return "[VERBOSE]"
            case .debug: return "[DEBUG]"
            case .info: return "[INFO]"
            case .warning: return "[WARNING]"
            case .error: return "[ERROR]"
            }
        }
    }

    /// Current minimum log level
    private static var minimumLevel: Level = .info

    /// Set the minimum log level
    public static func setMinimumLevel(_ level: Level) {
        minimumLevel = level
    }

    /// Log a message at the specified level
    public static func log(_ message: @autoclosure () -> String,
                           level: Level = .debug,
                           file: String = #file,
                           function: String = #function,
                           line: Int = #line)
    {
        guard isDebugLoggingEnabled && level >= minimumLevel else { return }

        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "\(level.prefix) [\(fileName):\(line)] \(function) - \(message())"

        #if DEBUG
            print(logMessage)
        #endif
    }

    /// Log verbose message
    public static func verbose(_ message: @autoclosure () -> String,
                               file: String = #file,
                               function: String = #function,
                               line: Int = #line)
    {
        log(message(), level: .verbose, file: file, function: function, line: line)
    }

    /// Log debug message
    public static func debug(_ message: @autoclosure () -> String,
                             file: String = #file,
                             function: String = #function,
                             line: Int = #line)
    {
        log(message(), level: .debug, file: file, function: function, line: line)
    }

    /// Log info message
    public static func info(_ message: @autoclosure () -> String,
                            file: String = #file,
                            function: String = #function,
                            line: Int = #line)
    {
        log(message(), level: .info, file: file, function: function, line: line)
    }

    /// Log warning message
    public static func warning(_ message: @autoclosure () -> String,
                               file: String = #file,
                               function: String = #function,
                               line: Int = #line)
    {
        log(message(), level: .warning, file: file, function: function, line: line)
    }

    /// Log error message
    public static func error(_ message: @autoclosure () -> String,
                             file: String = #file,
                             function: String = #function,
                             line: Int = #line)
    {
        log(message(), level: .error, file: file, function: function, line: line)
    }

    /// Log performance metrics
    public static func performance(_ operation: String,
                                   duration: TimeInterval,
                                   file: String = #file,
                                   function: String = #function,
                                   line: Int = #line)
    {
        let message = "Performance: \(operation) took \(String(format: "%.4f", duration)) seconds"
        log(message, level: .debug, file: file, function: function, line: line)
    }

    /// Log dependency graph information
    public static func graph(_ message: @autoclosure () -> String,
                             file: String = #file,
                             function: String = #function,
                             line: Int = #line)
    {
        log("[GRAPH] \(message())", level: .debug, file: file, function: function, line: line)
    }
}
