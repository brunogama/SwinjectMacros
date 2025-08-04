// CacheMacroTests.swift - Tests for @Cache macro expansion
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwinjectUtilityMacrosImplementation

final class CacheMacroTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "Cache": CacheMacro.self
    ]

    // MARK: - Basic Functionality Tests

    func testBasicCacheExpansion() throws {
        assertMacroExpansion(
            """
            @Cache
            func fetchUserData(userId: String) throws -> UserData {
                return UserData(id: userId)
            }
            """,
            expandedSource: """
            func fetchUserData(userId: String) throws -> UserData {
                return UserData(id: userId)
            }

            public func fetchUserDataCached(userId: String) throws -> UserData {
                let cacheKey = "fetchUserData:\\(userId)"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: "fetchUserData",
                    ttl: 300.0,
                    maxEntries: 1000,
                    evictionPolicy: .lru
                )

                // Record cache operation start time
                let startTime = CFAbsoluteTimeGetCurrent()

                // Check for cached result
                if let cachedResult = cache.get(key: cacheKey, type: UserData.self) {
                    // Cache hit - record metrics and return cached result
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let hitOperation = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: responseTime,
                        valueSize: MemoryLayout.size(ofValue: cachedResult)
                    )
                    CacheRegistry.recordOperation(hitOperation, for: "fetchUserData")

                    return cachedResult
                }

                // Cache miss - execute original method
                let result = try fetchUserData(userId: userId)

                // Record cache miss metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000

                let missOperation = CacheOperation(
                    wasHit: false,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: result)
                )
                CacheRegistry.recordOperation(missOperation, for: "fetchUserData")

                // Store result in cache
                cache.set(key: cacheKey, value: result)

                return result
            }
            """,
            macros: testMacros
        )
    }

    func testCacheWithCustomTTL() throws {
        assertMacroExpansion(
            """
            @Cache(ttl: 600.0, maxEntries: 500)
            func getConfiguration(configId: String) throws -> Config {
                return Config(id: configId)
            }
            """,
            expandedSource: """
            func getConfiguration(configId: String) throws -> Config {
                return Config(id: configId)
            }

            public func getConfigurationCached(configId: String) throws -> Config {
                let cacheKey = "getConfiguration:\\(configId)"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: "getConfiguration",
                    ttl: 600.0,
                    maxEntries: 500,
                    evictionPolicy: .lru
                )

                // Record cache operation start time
                let startTime = CFAbsoluteTimeGetCurrent()

                // Check for cached result
                if let cachedResult = cache.get(key: cacheKey, type: Config.self) {
                    // Cache hit - record metrics and return cached result
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let hitOperation = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: responseTime,
                        valueSize: MemoryLayout.size(ofValue: cachedResult)
                    )
                    CacheRegistry.recordOperation(hitOperation, for: "getConfiguration")

                    return cachedResult
                }

                // Cache miss - execute original method
                let result = try getConfiguration(configId: configId)

                // Record cache miss metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000

                let missOperation = CacheOperation(
                    wasHit: false,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: result)
                )
                CacheRegistry.recordOperation(missOperation, for: "getConfiguration")

                // Store result in cache
                cache.set(key: cacheKey, value: result)

                return result
            }
            """,
            macros: testMacros
        )
    }

    func testCacheWithEvictionPolicy() throws {
        assertMacroExpansion(
            """
            @Cache(evictionPolicy: .lfu, maxEntries: 2000)
            func searchProducts(query: String) throws -> [Product] {
                return []
            }
            """,
            expandedSource: """
            func searchProducts(query: String) throws -> [Product] {
                return []
            }

            public func searchProductsCached(query: String) throws -> [Product] {
                let cacheKey = "searchProducts:\\(query)"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: "searchProducts",
                    ttl: 300.0,
                    maxEntries: 2000,
                    evictionPolicy: .lfu
                )

                // Record cache operation start time
                let startTime = CFAbsoluteTimeGetCurrent()

                // Check for cached result
                if let cachedResult = cache.get(key: cacheKey, type: [Product].self) {
                    // Cache hit - record metrics and return cached result
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let hitOperation = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: responseTime,
                        valueSize: MemoryLayout.size(ofValue: cachedResult)
                    )
                    CacheRegistry.recordOperation(hitOperation, for: "searchProducts")

                    return cachedResult
                }

                // Cache miss - execute original method
                let result = try searchProducts(query: query)

                // Record cache miss metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000

                let missOperation = CacheOperation(
                    wasHit: false,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: result)
                )
                CacheRegistry.recordOperation(missOperation, for: "searchProducts")

                // Store result in cache
                cache.set(key: cacheKey, value: result)

                return result
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Async Function Tests

    func testAsyncCache() throws {
        assertMacroExpansion(
            """
            @Cache(ttl: 120.0)
            func fetchDataAsync(from url: URL) async throws -> Data {
                return Data()
            }
            """,
            expandedSource: """
            func fetchDataAsync(from url: URL) async throws -> Data {
                return Data()
            }

            public func fetchDataAsyncCached(from url: URL) async throws -> Data {
                let cacheKey = "fetchDataAsync:\\(url)"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: "fetchDataAsync",
                    ttl: 120.0,
                    maxEntries: 1000,
                    evictionPolicy: .lru
                )

                // Record cache operation start time
                let startTime = CFAbsoluteTimeGetCurrent()

                // Check for cached result
                if let cachedResult = cache.get(key: cacheKey, type: Data.self) {
                    // Cache hit - record metrics and return cached result
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let hitOperation = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: responseTime,
                        valueSize: MemoryLayout.size(ofValue: cachedResult)
                    )
                    CacheRegistry.recordOperation(hitOperation, for: "fetchDataAsync")

                    return cachedResult
                }

                // Cache miss - execute original method
                let result = try await fetchDataAsync(from: url)

                // Record cache miss metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000

                let missOperation = CacheOperation(
                    wasHit: false,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: result)
                )
                CacheRegistry.recordOperation(missOperation, for: "fetchDataAsync")

                // Store result in cache
                cache.set(key: cacheKey, value: result)

                return result
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Static Method Tests

    func testStaticMethodCache() throws {
        assertMacroExpansion(
            """
            @Cache(ttl: 900.0)
            static func computeValue(input: Int) -> Int {
                return input * 2
            }
            """,
            expandedSource: """
            static func computeValue(input: Int) -> Int {
                return input * 2
            }

            public static func computeValueCached(input: Int) -> Int {
                let cacheKey = "computeValue:\\(input)"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: "computeValue",
                    ttl: 900.0,
                    maxEntries: 1000,
                    evictionPolicy: .lru
                )

                // Record cache operation start time
                let startTime = CFAbsoluteTimeGetCurrent()

                // Check for cached result
                if let cachedResult = cache.get(key: cacheKey, type: Int.self) {
                    // Cache hit - record metrics and return cached result
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let hitOperation = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: responseTime,
                        valueSize: MemoryLayout.size(ofValue: cachedResult)
                    )
                    CacheRegistry.recordOperation(hitOperation, for: "computeValue")

                    return cachedResult
                }

                // Cache miss - execute original method
                let result = computeValue(input: input)

                // Record cache miss metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000

                let missOperation = CacheOperation(
                    wasHit: false,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: result)
                )
                CacheRegistry.recordOperation(missOperation, for: "computeValue")

                // Store result in cache
                cache.set(key: cacheKey, value: result)

                return result
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Non-Throwing Method Tests

    func testNonThrowingMethodCache() throws {
        assertMacroExpansion(
            """
            @Cache(ttl: 60.0)
            func processData(data: String) -> ProcessedData {
                return ProcessedData(data)
            }
            """,
            expandedSource: """
            func processData(data: String) -> ProcessedData {
                return ProcessedData(data)
            }

            public func processDataCached(data: String) -> ProcessedData {
                let cacheKey = "processData:\\(data)"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: "processData",
                    ttl: 60.0,
                    maxEntries: 1000,
                    evictionPolicy: .lru
                )

                // Record cache operation start time
                let startTime = CFAbsoluteTimeGetCurrent()

                // Check for cached result
                if let cachedResult = cache.get(key: cacheKey, type: ProcessedData.self) {
                    // Cache hit - record metrics and return cached result
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let hitOperation = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: responseTime,
                        valueSize: MemoryLayout.size(ofValue: cachedResult)
                    )
                    CacheRegistry.recordOperation(hitOperation, for: "processData")

                    return cachedResult
                }

                // Cache miss - execute original method
                let result = processData(data: data)

                // Record cache miss metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000

                let missOperation = CacheOperation(
                    wasHit: false,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: result)
                )
                CacheRegistry.recordOperation(missOperation, for: "processData")

                // Store result in cache
                cache.set(key: cacheKey, value: result)

                return result
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Void Return Type Tests

    func testVoidReturnTypeCache() throws {
        assertMacroExpansion(
            """
            @Cache(ttl: 30.0)
            func performAction() {
                // Action implementation
            }
            """,
            expandedSource: """
            func performAction() {
                // Action implementation
            }

            public func performActionCached() {
                let cacheKey = "performAction"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: "performAction",
                    ttl: 30.0,
                    maxEntries: 1000,
                    evictionPolicy: .lru
                )

                // Record cache operation start time
                let startTime = CFAbsoluteTimeGetCurrent()

                // Check for cached result
                if let cachedResult = cache.get(key: cacheKey, type: Void.self) {
                    // Cache hit - record metrics and return cached result
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let hitOperation = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: responseTime,
                        valueSize: MemoryLayout.size(ofValue: cachedResult)
                    )
                    CacheRegistry.recordOperation(hitOperation, for: "performAction")

                    return cachedResult
                }

                // Cache miss - execute original method
                let result = performAction()

                // Record cache miss metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000

                let missOperation = CacheOperation(
                    wasHit: false,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: result)
                )
                CacheRegistry.recordOperation(missOperation, for: "performAction")

                // Store result in cache
                cache.set(key: cacheKey, value: result)

            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Error Cases

    func testCacheOnNonFunction() throws {
        assertMacroExpansion(
            """
            @Cache
            struct TestStruct {
                let value: String
            }
            """,
            expandedSource: """
            struct TestStruct {
                let value: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Cache can only be applied to functions and methods", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    // MARK: - Complex Parameter Tests

    func testCacheWithComplexParameters() throws {
        assertMacroExpansion(
            """
            @Cache(ttl: 180.0, maxEntries: 250)
            func queryDatabase(table: String, filters: [String: Any] = [:], limit: Int = 100) async throws -> [Row] {
                return []
            }
            """,
            expandedSource: """
            func queryDatabase(table: String, filters: [String: Any] = [:], limit: Int = 100) async throws -> [Row] {
                return []
            }

            public func queryDatabaseCached(table: String, filters: [String: Any] = [:], limit: Int = 100) async throws -> [Row] {
                let cacheKey = "queryDatabase:\\(table):\\(filters):\\(limit)"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: "queryDatabase",
                    ttl: 180.0,
                    maxEntries: 250,
                    evictionPolicy: .lru
                )

                // Record cache operation start time
                let startTime = CFAbsoluteTimeGetCurrent()

                // Check for cached result
                if let cachedResult = cache.get(key: cacheKey, type: [Row].self) {
                    // Cache hit - record metrics and return cached result
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let hitOperation = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: responseTime,
                        valueSize: MemoryLayout.size(ofValue: cachedResult)
                    )
                    CacheRegistry.recordOperation(hitOperation, for: "queryDatabase")

                    return cachedResult
                }

                // Cache miss - execute original method
                let result = try await queryDatabase(table: table, filters: filters, limit: limit)

                // Record cache miss metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000

                let missOperation = CacheOperation(
                    wasHit: false,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: result)
                )
                CacheRegistry.recordOperation(missOperation, for: "queryDatabase")

                // Store result in cache
                cache.set(key: cacheKey, value: result)

                return result
            }
            """,
            macros: testMacros
        )
    }

    func testCacheWithMultipleEvictionPolicies() throws {
        assertMacroExpansion(
            """
            @Cache(evictionPolicy: .fifo, ttl: 450.0)
            func calculateExpensiveValue(seed: Double) -> Double {
                return seed * 3.14159
            }
            """,
            expandedSource: """
            func calculateExpensiveValue(seed: Double) -> Double {
                return seed * 3.14159
            }

            public func calculateExpensiveValueCached(seed: Double) -> Double {
                let cacheKey = "calculateExpensiveValue:\\(seed)"

                // Get or create cache instance
                let cache = CacheRegistry.getCache(
                    for: "calculateExpensiveValue",
                    ttl: 450.0,
                    maxEntries: 1000,
                    evictionPolicy: .fifo
                )

                // Record cache operation start time
                let startTime = CFAbsoluteTimeGetCurrent()

                // Check for cached result
                if let cachedResult = cache.get(key: cacheKey, type: Double.self) {
                    // Cache hit - record metrics and return cached result
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let responseTime = (endTime - startTime) * 1000 // Convert to milliseconds

                    let hitOperation = CacheOperation(
                        wasHit: true,
                        key: cacheKey,
                        responseTime: responseTime,
                        valueSize: MemoryLayout.size(ofValue: cachedResult)
                    )
                    CacheRegistry.recordOperation(hitOperation, for: "calculateExpensiveValue")

                    return cachedResult
                }

                // Cache miss - execute original method
                let result = calculateExpensiveValue(seed: seed)

                // Record cache miss metrics
                let endTime = CFAbsoluteTimeGetCurrent()
                let responseTime = (endTime - startTime) * 1000

                let missOperation = CacheOperation(
                    wasHit: false,
                    key: cacheKey,
                    responseTime: responseTime,
                    valueSize: MemoryLayout.size(ofValue: result)
                )
                CacheRegistry.recordOperation(missOperation, for: "calculateExpensiveValue")

                // Store result in cache
                cache.set(key: cacheKey, value: result)

                return result
            }
            """,
            macros: testMacros
        )
    }
}
