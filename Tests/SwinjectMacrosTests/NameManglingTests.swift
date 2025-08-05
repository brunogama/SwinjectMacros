// NameManglingTests.swift - Tests for variable name mangling functionality

@testable import SwinjectMacrosImplementation
import XCTest

final class NameManglingTests: XCTestCase {

    // MARK: - Basic Name Mangling Tests

    func testBasicNameMangling() {
        let mangledName = MacroUtilities.mangledVariableName(
            baseName: "startTime",
            context: "fetchData",
            macroType: "PerformanceTracked"
        )

        // Should include macro type, context, and base name
        XCTAssertTrue(mangledName.contains("PerformanceTracked"))
        XCTAssertTrue(mangledName.contains("FetchData"))
        XCTAssertTrue(mangledName.contains("StartTime"))

        // Should be unique
        XCTAssertNotEqual(mangledName, "startTime")
        XCTAssertTrue(mangledName.hasPrefix("_"))
    }

    func testNameManglingUniqueness() {
        let name1 = MacroUtilities.mangledVariableName(
            baseName: "result",
            context: "fetchUser",
            macroType: "Retry"
        )

        let name2 = MacroUtilities.mangledVariableName(
            baseName: "result",
            context: "fetchProduct",
            macroType: "Retry"
        )

        let name3 = MacroUtilities.mangledVariableName(
            baseName: "result",
            context: "fetchUser",
            macroType: "PerformanceTracked"
        )

        // Same base name but different contexts/macros should produce different names
        XCTAssertNotEqual(name1, name2)
        XCTAssertNotEqual(name1, name3)
        XCTAssertNotEqual(name2, name3)
    }

    func testNameManglingConsistency() {
        let name1 = MacroUtilities.mangledVariableName(
            baseName: "duration",
            context: "processOrder",
            macroType: "PerformanceTracked"
        )

        let name2 = MacroUtilities.mangledVariableName(
            baseName: "duration",
            context: "processOrder",
            macroType: "PerformanceTracked"
        )

        // Same parameters should produce identical names
        XCTAssertEqual(name1, name2)
    }

    func testNameManglingWithSuffix() {
        let nameWithoutSuffix = MacroUtilities.mangledVariableName(
            baseName: "timeout",
            context: "apiCall",
            macroType: "Retry"
        )

        let nameWithSuffix = MacroUtilities.mangledVariableName(
            baseName: "timeout",
            context: "apiCall",
            macroType: "Retry",
            suffix: "v2"
        )

        // Names should be different when suffix is provided
        XCTAssertNotEqual(nameWithoutSuffix, nameWithSuffix)
        XCTAssertTrue(nameWithSuffix.contains("v2"))
    }

    // MARK: - Specialized Name Mangling Tests

    func testBackingVariableName() {
        let backingName = MacroUtilities.mangledBackingVariableName(
            propertyName: "userService",
            macroType: "LazyInject"
        )

        XCTAssertTrue(backingName.contains("LazyInject"))
        XCTAssertTrue(backingName.contains("UserService"))
        XCTAssertTrue(backingName.contains("Backing"))
        XCTAssertTrue(backingName.hasPrefix("_"))
    }

    func testLockVariableName() {
        let lockName = MacroUtilities.mangledLockVariableName(
            propertyName: "repository",
            macroType: "LazyInject"
        )

        XCTAssertTrue(lockName.contains("LazyInject"))
        XCTAssertTrue(lockName.contains("Repository"))
        XCTAssertTrue(lockName.contains("Lock"))
        XCTAssertTrue(lockName.hasPrefix("_"))
    }

    func testOnceTokenVariableName() {
        let tokenName = MacroUtilities.mangledOnceTokenVariableName(
            propertyName: "apiClient",
            macroType: "LazyInject"
        )

        XCTAssertTrue(tokenName.contains("LazyInject"))
        XCTAssertTrue(tokenName.contains("ApiClient"))
        XCTAssertTrue(tokenName.contains("OnceToken"))
        XCTAssertTrue(tokenName.hasPrefix("_"))
    }

    func testMethodVariableName() {
        let variableName = MacroUtilities.mangledMethodVariableName(
            baseName: "startTime",
            methodName: "fetchUserData",
            macroType: "PerformanceTracked"
        )

        XCTAssertTrue(variableName.contains("PerformanceTracked"))
        XCTAssertTrue(variableName.contains("FetchUserData"))
        XCTAssertTrue(variableName.contains("StartTime"))
        XCTAssertTrue(variableName.hasPrefix("_"))
    }

    // MARK: - Edge Cases

    func testNameManglingWithSpecialCharacters() {
        let mangledName = MacroUtilities.mangledVariableName(
            baseName: "result",
            context: "fetch_user_data",
            macroType: "Retry"
        )

        // Should handle underscores in context
        XCTAssertTrue(mangledName.contains("Retry"))
        XCTAssertTrue(mangledName.contains("Result"))
        // Context should be properly capitalized
        XCTAssertTrue(mangledName.contains("Fetch_user_data"))
    }

    func testNameManglingWithLongNames() {
        let longBaseName = "veryLongVariableNameThatShouldStillWork"
        let longContext = "veryLongMethodNameWithLotsOfCharacters"
        let longMacroType = "VeryLongMacroTypeName"

        let mangledName = MacroUtilities.mangledVariableName(
            baseName: longBaseName,
            context: longContext,
            macroType: longMacroType
        )

        // Should still work with long names
        XCTAssertTrue(mangledName.contains(longMacroType))
        XCTAssertTrue(mangledName.hasPrefix("_"))
        XCTAssertFalse(mangledName.isEmpty)
    }

    func testNameManglingWithEmptyValues() {
        let mangledName = MacroUtilities.mangledVariableName(
            baseName: "",
            context: "method",
            macroType: "Macro"
        )

        // Should handle empty base name gracefully
        XCTAssertTrue(mangledName.contains("Macro"))
        XCTAssertTrue(mangledName.contains("Method"))
        XCTAssertTrue(mangledName.hasPrefix("_"))
    }

    // MARK: - Collision Prevention Tests

    func testNoCollisionBetweenDifferentMacros() {
        let performanceName = MacroUtilities.mangledMethodVariableName(
            baseName: "result",
            methodName: "processData",
            macroType: "PerformanceTracked"
        )

        let retryName = MacroUtilities.mangledMethodVariableName(
            baseName: "result",
            methodName: "processData",
            macroType: "Retry"
        )

        let cacheName = MacroUtilities.mangledMethodVariableName(
            baseName: "result",
            methodName: "processData",
            macroType: "Cache"
        )

        // All should be different despite same base name and method
        XCTAssertNotEqual(performanceName, retryName)
        XCTAssertNotEqual(performanceName, cacheName)
        XCTAssertNotEqual(retryName, cacheName)
    }

    func testNoCollisionBetweenDifferentMethods() {
        let method1Name = MacroUtilities.mangledMethodVariableName(
            baseName: "duration",
            methodName: "saveUser",
            macroType: "PerformanceTracked"
        )

        let method2Name = MacroUtilities.mangledMethodVariableName(
            baseName: "duration",
            methodName: "deleteUser",
            macroType: "PerformanceTracked"
        )

        // Same macro type and base name but different methods should be unique
        XCTAssertNotEqual(method1Name, method2Name)
    }

    func testNoCollisionBetweenPropertyTypes() {
        let backingName = MacroUtilities.mangledBackingVariableName(
            propertyName: "service",
            macroType: "LazyInject"
        )

        let lockName = MacroUtilities.mangledLockVariableName(
            propertyName: "service",
            macroType: "LazyInject"
        )

        let tokenName = MacroUtilities.mangledOnceTokenVariableName(
            propertyName: "service",
            macroType: "LazyInject"
        )

        // Different types of supporting properties should have unique names
        XCTAssertNotEqual(backingName, lockName)
        XCTAssertNotEqual(backingName, tokenName)
        XCTAssertNotEqual(lockName, tokenName)
    }

    // MARK: - Hash Consistency Tests

    func testHashConsistencyAcrossRuns() {
        // Run multiple times to ensure hash is deterministic
        let names = (0..<10).map { _ in
            MacroUtilities.mangledVariableName(
                baseName: "testVar",
                context: "testMethod",
                macroType: "TestMacro"
            )
        }

        // All names should be identical
        let uniqueNames = Set(names)
        XCTAssertEqual(uniqueNames.count, 1, "Hash should be deterministic across multiple calls")
    }

    func testValidSwiftIdentifiers() {
        let testCases = [
            ("result", "fetchData", "Retry"),
            ("startTime", "processOrder", "PerformanceTracked"),
            ("cacheKey", "getUserInfo", "Cache"),
            ("backingStore", "userService", "LazyInject")
        ]

        for (baseName, context, macroType) in testCases {
            let mangledName = MacroUtilities.mangledVariableName(
                baseName: baseName,
                context: context,
                macroType: macroType
            )

            // Should be valid Swift identifier
            XCTAssertTrue(mangledName.hasPrefix("_"), "Should start with underscore: \(mangledName)")
            XCTAssertFalse(mangledName.contains(" "), "Should not contain spaces: \(mangledName)")
            XCTAssertFalse(mangledName.contains("-"), "Should not contain hyphens: \(mangledName)")

            // Should not be empty or just underscore
            XCTAssertGreaterThan(mangledName.count, 1, "Should be longer than just underscore: \(mangledName)")
        }
    }
}
