// PerformanceTrackedMacroTests.swift - Tests for @PerformanceTracked macro
// Copyright © 2025 SwinJectMacros. All rights reserved.

import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

final class PerformanceTrackedMacroTests: XCTestCase {
    
    // MARK: - Test Utilities
    
    let testMacros: [String: Macro.Type] = [
        "PerformanceTracked": PerformanceTrackedMacro.self
    ]
    
    // MARK: - Basic Functionality Tests
    
    func testBasicPerformanceTrackedExpansion() {
        assertMacroExpansion(
            """
            @PerformanceTracked
            func processData(input: String) -> String {
                return input.uppercased()
            }
            """,
            expandedSource: """
            func processData(input: String) -> String {
                return input.uppercased()
            }
            
            public func processDataPerformanceTracked(input: String) -> String {
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory: Int64 = 0
                let peakMemory: Int64 = 0
                
                let methodName = "processData"
                let typeName = String(describing: type(of: self))
                let category = String(describing: type(of: self))
                
                do {
                    // Execute original method with memory tracking
                    let result = processData(input: input)
                    let memoryUsed: Int64 = 0
                    let finalPeakMemory: Int64 = 0
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = nil
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any]? = nil
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 1000.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 1000.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: nil,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testPerformanceTrackedWithCustomThreshold() {
        assertMacroExpansion(
            """
            @PerformanceTracked(threshold: 500)
            func slowOperation() throws -> Result {
                return performSlowWork()
            }
            """,
            expandedSource: """
            func slowOperation() throws -> Result {
                return performSlowWork()
            }
            
            public func slowOperationPerformanceTracked() throws -> Result {
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory: Int64 = 0
                let peakMemory: Int64 = 0
                
                let methodName = "slowOperation"
                let typeName = String(describing: type(of: self))
                let category = String(describing: type(of: self))
                
                do {
                    // Execute original method with memory tracking
                    let result = try slowOperation()
                    let memoryUsed: Int64 = 0
                    let finalPeakMemory: Int64 = 0
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = nil
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any]? = nil
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 500.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 500.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: nil,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testPerformanceTrackedWithMemoryTracking() {
        assertMacroExpansion(
            """
            @PerformanceTracked(memoryTracking: true)
            func processLargeDataset(data: [String]) -> [String] {
                return data.map { $0.uppercased() }
            }
            """,
            expandedSource: """
            func processLargeDataset(data: [String]) -> [String] {
                return data.map { $0.uppercased() }
            }
            
            public func processLargeDatasetPerformanceTracked(data: [String]) -> [String] {
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory = MemoryMonitor.getCurrentMemoryUsage()
                var peakMemory = initialMemory
                
                let methodName = "processLargeDataset"
                let typeName = String(describing: type(of: self))
                let category = String(describing: type(of: self))
                
                do {
                    // Execute original method with memory tracking
                    let memoryResult = MemoryMonitor.trackMemoryUsage {
                        processLargeDataset(data: data)
                    }
                    let result = memoryResult.result
                    let memoryUsed = memoryResult.memoryUsed
                    let finalPeakMemory = memoryResult.peakMemory
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = nil
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any]? = nil
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 1000.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 1000.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: nil,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testPerformanceTrackedWithSampling() {
        assertMacroExpansion(
            """
            @PerformanceTracked(sampleRate: 0.1)
            func frequentOperation(id: Int) -> String {
                return "result_\\(id)"
            }
            """,
            expandedSource: """
            func frequentOperation(id: Int) -> String {
                return "result_\\(id)"
            }
            
            public func frequentOperationPerformanceTracked(id: Int) -> String {
                // Sample rate check - only track 10.0% of calls
                guard Double.random(in: 0...1) <= 0.1 else {
                    // Execute without performance tracking
                    return frequentOperation(id: id)
                }
                
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory: Int64 = 0
                let peakMemory: Int64 = 0
                
                let methodName = "frequentOperation"
                let typeName = String(describing: type(of: self))
                let category = String(describing: type(of: self))
                
                do {
                    // Execute original method with memory tracking
                    let result = frequentOperation(id: id)
                    let memoryUsed: Int64 = 0
                    let finalPeakMemory: Int64 = 0
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = nil
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any]? = nil
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 1000.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 1000.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: nil,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testPerformanceTrackedWithIncludeParameters() {
        assertMacroExpansion(
            """
            @PerformanceTracked(includeParameters: true)
            func calculateValue(x: Double, y: Double, factor: Double = 1.0) -> Double {
                return (x + y) * factor
            }
            """,
            expandedSource: """
            func calculateValue(x: Double, y: Double, factor: Double = 1.0) -> Double {
                return (x + y) * factor
            }
            
            public func calculateValuePerformanceTracked(x: Double, y: Double, factor: Double = 1.0) -> Double {
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory: Int64 = 0
                let peakMemory: Int64 = 0
                
                let methodName = "calculateValue"
                let typeName = String(describing: type(of: self))
                let category = String(describing: type(of: self))
                
                do {
                    // Execute original method with memory tracking
                    let result = calculateValue(x: x, y: y, factor: factor)
                    let memoryUsed: Int64 = 0
                    let finalPeakMemory: Int64 = 0
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = nil
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any] = ["x": x, "y": y, "factor": factor]
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 1000.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 1000.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testPerformanceTrackedWithCustomCategory() {
        assertMacroExpansion(
            """
            @PerformanceTracked(category: "ImageProcessing")
            func processImage(image: UIImage) -> UIImage {
                return applyFilters(to: image)
            }
            """,
            expandedSource: """
            func processImage(image: UIImage) -> UIImage {
                return applyFilters(to: image)
            }
            
            public func processImagePerformanceTracked(image: UIImage) -> UIImage {
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory: Int64 = 0
                let peakMemory: Int64 = 0
                
                let methodName = "processImage"
                let typeName = String(describing: type(of: self))
                let category = "ImageProcessing"
                
                do {
                    // Execute original method with memory tracking
                    let result = processImage(image: image)
                    let memoryUsed: Int64 = 0
                    let finalPeakMemory: Int64 = 0
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = nil
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any]? = nil
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 1000.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 1000.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: nil,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testPerformanceTrackedWithStackTrace() {
        assertMacroExpansion(
            """
            @PerformanceTracked(includeStackTrace: true, threshold: 100)
            func criticalOperation() throws -> CriticalResult {
                return try performCriticalWork()
            }
            """,
            expandedSource: """
            func criticalOperation() throws -> CriticalResult {
                return try performCriticalWork()
            }
            
            public func criticalOperationPerformanceTracked() throws -> CriticalResult {
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory: Int64 = 0
                let peakMemory: Int64 = 0
                
                let methodName = "criticalOperation"
                let typeName = String(describing: type(of: self))
                let category = String(describing: type(of: self))
                
                do {
                    // Execute original method with memory tracking
                    let result = try criticalOperation()
                    let memoryUsed: Int64 = 0
                    let finalPeakMemory: Int64 = 0
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = if executionTime > 100.0 {
                        Thread.callStackSymbols
                    } else {
                        nil
                    }
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any]? = nil
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 100.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 100.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: nil,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testAsyncPerformanceTracked() {
        assertMacroExpansion(
            """
            @PerformanceTracked
            func fetchData(from url: URL) async throws -> Data {
                return try await URLSession.shared.data(from: url).0
            }
            """,
            expandedSource: """
            func fetchData(from url: URL) async throws -> Data {
                return try await URLSession.shared.data(from: url).0
            }
            
            public func fetchDataPerformanceTracked(from url: URL) async throws -> Data {
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory: Int64 = 0
                let peakMemory: Int64 = 0
                
                let methodName = "fetchData"
                let typeName = String(describing: type(of: self))
                let category = String(describing: type(of: self))
                
                do {
                    // Execute original method with memory tracking
                    let result = try await fetchData(from: url)
                    let memoryUsed: Int64 = 0
                    let finalPeakMemory: Int64 = 0
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = nil
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any]? = nil
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 1000.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 1000.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: nil,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testStaticMethodPerformanceTracked() {
        assertMacroExpansion(
            """
            @PerformanceTracked
            static func staticCalculation(value: Int) -> Int {
                return value * 2
            }
            """,
            expandedSource: """
            static func staticCalculation(value: Int) -> Int {
                return value * 2
            }
            
            public static func staticCalculationPerformanceTracked(value: Int) -> Int {
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory: Int64 = 0
                let peakMemory: Int64 = 0
                
                let methodName = "staticCalculation"
                let typeName = String(describing: type(of: self))
                let category = String(describing: type(of: self))
                
                do {
                    // Execute original method with memory tracking
                    let result = staticCalculation(value: value)
                    let memoryUsed: Int64 = 0
                    let finalPeakMemory: Int64 = 0
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = nil
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any]? = nil
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 1000.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 1000.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: nil,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    // MARK: - Error Case Tests
    
    func testPerformanceTrackedOnNonFunction() {
        assertMacroExpansion(
            """
            @PerformanceTracked
            class ServiceClass {
                var name: String = "service"
            }
            """,
            expandedSource: """
            class ServiceClass {
                var name: String = "service"
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PerformanceTracked can only be applied to functions and methods", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
    
    func testPerformanceTrackedOnProperty() {
        assertMacroExpansion(
            """
            class ServiceClass {
                @PerformanceTracked
                var computedValue: Int {
                    return 42
                }
            }
            """,
            expandedSource: """
            class ServiceClass {
                var computedValue: Int {
                    return 42
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@PerformanceTracked can only be applied to functions and methods", line: 2, column: 5)
            ],
            macros: testMacros
        )
    }
    
    // MARK: - Complex Configuration Tests
    
    func testPerformanceTrackedWithAllOptions() {
        assertMacroExpansion(
            """
            @PerformanceTracked(
                threshold: 250,
                sampleRate: 0.5,
                memoryTracking: true,
                includeStackTrace: true,
                includeParameters: true,
                category: "ComplexOperations"
            )
            func complexMethod(param1: String, param2: Int, param3: Bool = true) async throws -> ComplexResult {
                return try await performComplexWork(param1, param2, param3)
            }
            """,
            expandedSource: """
            func complexMethod(param1: String, param2: Int, param3: Bool = true) async throws -> ComplexResult {
                return try await performComplexWork(param1, param2, param3)
            }
            
            public func complexMethodPerformanceTracked(param1: String, param2: Int, param3: Bool = true) async throws -> ComplexResult {
                // Sample rate check - only track 50.0% of calls
                guard Double.random(in: 0...1) <= 0.5 else {
                    // Execute without performance tracking
                    return try await complexMethod(param1: param1, param2: param2, param3: param3)
                }
                
                // Performance tracking setup
                let startTime = CFAbsoluteTimeGetCurrent()
                let threadInfo = ThreadInfo()
                let initialMemory = MemoryMonitor.getCurrentMemoryUsage()
                var peakMemory = initialMemory
                
                let methodName = "complexMethod"
                let typeName = String(describing: type(of: self))
                let category = "ComplexOperations"
                
                do {
                    // Execute original method with memory tracking
                    let memoryResult = MemoryMonitor.trackMemoryUsage {
                        try await complexMethod(param1: param1, param2: param2, param3: param3)
                    }
                    let result = memoryResult.result
                    let memoryUsed = memoryResult.memoryUsed
                    let finalPeakMemory = memoryResult.peakMemory
                    
                    // Calculate performance metrics
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000 // Convert to milliseconds
                    
                    // Generate stack trace if needed for slow calls
                    let stackTrace: [String]? = if executionTime > 250.0 {
                        Thread.callStackSymbols
                    } else {
                        nil
                    }
                    
                    // Collect parameters if enabled
                    let parameters: [String: Any] = ["param1": param1, "param2": param2, "param3": param3]
                    
                    // Create performance metrics
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: stackTrace
                    )
                    
                    // Record performance data
                    PerformanceMonitor.record(metrics)
                    
                    // Log slow methods
                    if executionTime > 250.0 {
                        print("⚠️ SLOW METHOD: \\(typeName).\\(methodName) took \\(String(format: "%.2f", executionTime))ms (threshold: 250.0ms)")
                    }
                    
                    return result
                } catch {
                    // Record performance data even for failed calls
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let executionTime = (endTime - startTime) * 1000
                    
                    let metrics = PerformanceMetrics(
                        methodName: methodName,
                        typeName: typeName,
                        category: category,
                        executionTime: executionTime,
                        memoryAllocated: memoryUsed,
                        peakMemoryUsage: finalPeakMemory,
                        timestamp: Date(),
                        threadInfo: threadInfo,
                        parameters: parameters,
                        stackTrace: nil
                    )
                    
                    PerformanceMonitor.record(metrics)
                    
                    print("❌ METHOD FAILED: \\(typeName).\\(methodName) failed after \\(String(format: "%.2f", executionTime))ms with error: \\(error)")
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
}

// MARK: - Test Import Statements

// Required import statements for macro testing
#if canImport(SwinJectMacrosImplementation)
import SwinJectMacrosImplementation
#endif