// StringExtensions.swift - Shared string utilities
// Copyright © 2025 SwinjectUtilityMacros. All rights reserved.

import Foundation

extension String {
    /// String repetition operator
    /// Allows syntax like "═" * 50 to create repeated strings
    static func * (left: String, right: Int) -> String {
        String(repeating: left, count: right)
    }
}
