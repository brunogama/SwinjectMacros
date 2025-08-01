// Cache.swift - Cache macro declarations and support types
// Copyright © 2025 SwinJectMacros. All rights reserved.

import Foundation

// MARK: - @Cache Macro

/// Automatically adds caching logic to methods with configurable cache strategies and expiration policies.
///
/// This macro provides comprehensive caching capabilities including TTL-based expiration, LRU eviction,
/// cache key generation, and detailed cache metrics.
///
/// ## Basic Usage
///
/// ```swift
/// @Cache(ttl: 300) // Cache for 5 minutes
/// func fetchUserProfile(userId: String) async throws -> UserProfile {
///     // Your business logic - caching is automatic
///     return try await userService.getProfile(userId)
/// }
/// ```
///
/// ## Advanced Usage with Custom Cache Strategy
///
/// ```swift
/// @Cache(
///     ttl: 600,                          // 10 minute TTL
///     maxEntries: 1000,                  // Maximum 1000 cache entries
///     evictionPolicy: .lru,              // Least Recently Used eviction
///     cacheKey: { userId in "user:\(userId)" }, // Custom key generation
///     shouldCache: { result in result.isValid }  // Conditional caching
/// )
/// func getUserData(userId: String) async throws -> UserData {
///     return try await apiClient.fetchUser(userId)
/// }
/// ```
///
/// ## What it generates:
///
/// 1. **Cache Storage**: Thread-safe cache storage with configurable backends
/// 2. **Key Generation**: Automatic or custom cache key generation
/// 3. **TTL Management**: Time-to-live expiration with automatic cleanup
/// 4. **Eviction Policies**: LRU, LFU, FIFO cache eviction strategies
/// 5. **Cache Metrics**: Hit rates, miss rates, and performance tracking
/// 6. **Async Support**: Full support for async/await methods
///
/// ## Cache Strategies
///
/// The macro supports multiple eviction policies:
///
/// ```swift
/// // Least Recently Used (default)
/// @Cache(evictionPolicy: .lru)
///
/// // Least Frequently Used
/// @Cache(evictionPolicy: .lfu)
///
/// // First In, First Out
/// @Cache(evictionPolicy: .fifo)
///
/// // Time-based only (no size limit)
/// @Cache(evictionPolicy: .timeOnly)
/// ```
///
/// ## Cache Key Generation
///
/// Control how cache keys are generated:
///
/// ```swift
/// // Automatic key generation based on parameters
/// @Cache() // Default: uses method name + parameter values
///
/// // Custom key generation
/// @Cache(cacheKey: { userId, timestamp in
///     return "user:\(userId):v\(timestamp)"
/// })
///
/// // Include specific parameters only
/// @Cache(keyParameters: ["userId", "version"])
/// ```
///
/// ## Integration with Metrics
///
/// ```swift
/// // Get cache statistics
/// let stats = CacheMetrics.getStats(for: "fetchUserProfile")
/// print("Hit rate: \(stats.hitRate)")
/// print("Cache size: \(stats.currentSize)")
/// print("Average response time: \(stats.averageHitTime)ms")
///
/// // Clear cache
/// CacheRegistry.clear(for: "fetchUserProfile")
///
/// // Get global cache statistics
/// CacheMetrics.printCacheReport()
/// ```
///
/// ## Parameters:
/// - `ttl`: Time-to-live in seconds for cache entries (default: 300)
/// - `maxEntries`: Maximum number of cache entries (default: 1000)
/// - `evictionPolicy`: Cache eviction strategy (default: .lru)
/// - `cacheKey`: Custom cache key generation function
/// - `keyParameters`: Specific parameters to include in automatic key generation
/// - `shouldCache`: Predicate to determine if result should be cached
/// - `refreshInBackground`: Whether to refresh expired entries in background
/// - `serializationStrategy`: How to serialize/deserialize cached values
///
/// ## Requirements:
/// - Can be applied to instance methods, static methods, and functions
/// - Method can be sync or async, throwing or non-throwing
/// - Return type must be cacheable (conform to Codable for persistent caches)
/// - Thread-safe cache operations
///
/// ## Generated Behavior:
/// 1. **Cache Check**: Checks for existing valid cache entry
/// 2. **Cache Hit**: Returns cached result, updates access metrics
/// 3. **Cache Miss**: Executes original method, caches result
/// 4. **TTL Management**: Automatically expires old entries
/// 5. **Eviction**: Removes entries when cache size limits are exceeded
/// 6. **Metrics Collection**: Records hit/miss rates and timing information
///
/// ## Performance Impact:
/// - **Cache Hit**: Extremely fast, O(1) lookup
/// - **Cache Miss**: Original method performance + caching overhead
/// - **Memory Efficient**: Configurable size limits and automatic cleanup
/// - **Thread Safe**: Lock-free reads, atomic writes
///
/// ## Real-World Examples:
///
/// ```swift
/// class DataService {
///     @Cache(
///         ttl: 1800,  // 30 minutes
///         maxEntries: 500,
///         evictionPolicy: .lru,
///         shouldCache: { result in !result.isEmpty }
///     )
///     func searchProducts(query: String, filters: [String]) async throws -> [Product] {
///         return try await productAPI.search(query: query, filters: filters)
///     }
///     
///     @Cache(
///         ttl: 86400,  // 24 hours
///         maxEntries: 10000,
///         refreshInBackground: true,
///         cacheKey: { configId in "config:\(configId)" }
///     )
///     func getConfiguration(configId: String) async throws -> Configuration {
///         return try await configService.fetch(configId)
///     }
///     
///     @Cache(
///         ttl: 300,    // 5 minutes
///         evictionPolicy: .lfu,
///         keyParameters: ["userId"], // Ignore timestamp parameter
///         shouldCache: { profile in profile.isActive }
///     )
///     func getUserProfile(userId: String, timestamp: Date = Date()) async throws -> UserProfile {
///         return try await userAPI.getProfile(userId, at: timestamp)
///     }
/// }
/// 
/// // Monitor cache performance
/// CacheMetrics.printCacheReport()
/// // Output:
/// // 📦 Cache Report
/// // ========================================
/// // Method           Hit%   Size   AvgHit   AvgMiss
/// // searchProducts   85.3%   245    2.1ms    150.2ms
/// // getConfiguration 92.7%  1543    1.8ms    89.5ms
/// // getUserProfile   78.9%   892    1.9ms    201.3ms
/// ```
@attached(peer, names: suffixed(Cached))
public macro Cache(
    ttl: TimeInterval = 300.0,
    maxEntries: Int = 1000,
    evictionPolicy: CacheEvictionPolicy = .lru,
    cacheKey: ((Any...) -> String)? = nil,
    keyParameters: [String] = [],
    shouldCache: ((Any) -> Bool)? = nil,
    refreshInBackground: Bool = false,
    serializationStrategy: CacheSerializationStrategy = .memory
) = #externalMacro(module: "SwinJectMacrosImplementation", type: "CacheMacro")

// MARK: - Cache Support Types

/// Cache eviction policies
public enum CacheEvictionPolicy: String, CaseIterable {
    case lru = "LRU"           // Least Recently Used
    case lfu = "LFU"           // Least Frequently Used
    case fifo = "FIFO"         // First In, First Out
    case timeOnly = "TIME_ONLY" // Time-based expiration only
    
    public var description: String {
        return rawValue
    }
}

/// Cache serialization strategies
public enum CacheSerializationStrategy: String, CaseIterable {
    case memory = "MEMORY"           // In-memory only
    case disk = "DISK"               // Persistent disk storage
    case hybrid = "HYBRID"           // Memory + disk backup
    
    public var description: String {
        return rawValue
    }
}

/// Cache entry metadata
public struct CacheEntry<T> {
    /// The cached value
    public let value: T
    
    /// When this entry was created
    public let createdAt: Date
    
    /// When this entry was last accessed
    public var lastAccessed: Date
    
    /// How many times this entry has been accessed
    public var accessCount: Int
    
    /// When this entry expires
    public let expiresAt: Date
    
    /// Size of this entry in bytes (estimated)
    public let sizeBytes: Int
    
    public init(value: T, ttl: TimeInterval, sizeBytes: Int = 0) {
        self.value = value
        self.createdAt = Date()
        self.lastAccessed = Date()
        self.accessCount = 1
        self.expiresAt = Date().addingTimeInterval(ttl)
        self.sizeBytes = sizeBytes
    }
    
    /// Whether this entry is still valid
    public var isValid: Bool {
        return Date() < expiresAt
    }
    
    /// Age of this entry in seconds
    public var age: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
    
    /// Record an access to this entry
    public mutating func recordAccess() {
        lastAccessed = Date()
        accessCount += 1
    }
}

/// Detailed cache statistics and metrics
public struct CacheStats {
    /// Cache name/identifier
    public let cacheName: String
    
    /// Current number of entries in cache
    public let currentSize: Int
    
    /// Maximum allowed entries
    public let maxSize: Int
    
    /// Total number of cache lookups
    public let totalLookups: Int
    
    /// Number of cache hits
    public let hits: Int
    
    /// Number of cache misses
    public let misses: Int
    
    /// Cache hit rate (0.0 to 1.0)
    public let hitRate: Double
    
    /// Number of entries evicted due to size limits
    public let evictions: Int
    
    /// Number of entries expired due to TTL
    public let expirations: Int
    
    /// Average time for cache hits (milliseconds)
    public let averageHitTime: TimeInterval
    
    /// Average time for cache misses (milliseconds)
    public let averageMissTime: TimeInterval
    
    /// Total memory usage in bytes
    public let memoryUsage: Int
    
    /// Eviction policy being used
    public let evictionPolicy: CacheEvictionPolicy
    
    /// TTL setting in seconds
    public let ttl: TimeInterval
    
    /// When statistics were last updated
    public let lastUpdated: Date
    
    public init(
        cacheName: String,
        currentSize: Int,
        maxSize: Int,
        totalLookups: Int,
        hits: Int,
        misses: Int,
        hitRate: Double,
        evictions: Int,
        expirations: Int,
        averageHitTime: TimeInterval,
        averageMissTime: TimeInterval,
        memoryUsage: Int,
        evictionPolicy: CacheEvictionPolicy,
        ttl: TimeInterval,
        lastUpdated: Date = Date()
    ) {
        self.cacheName = cacheName
        self.currentSize = currentSize
        self.maxSize = maxSize
        self.totalLookups = totalLookups
        self.hits = hits
        self.misses = misses
        self.hitRate = hitRate
        self.evictions = evictions
        self.expirations = expirations
        self.averageHitTime = averageHitTime
        self.averageMissTime = averageMissTime
        self.memoryUsage = memoryUsage
        self.evictionPolicy = evictionPolicy
        self.ttl = ttl
        self.lastUpdated = lastUpdated
    }
}

/// Individual cache operation record
public struct CacheOperation {
    /// Timestamp of the operation
    public let timestamp: Date
    
    /// Whether this was a cache hit
    public let wasHit: Bool
    
    /// Cache key used
    public let key: String
    
    /// Time taken for the operation (milliseconds)
    public let responseTime: TimeInterval
    
    /// Size of the cached value (bytes)
    public let valueSize: Int
    
    /// Thread information
    public let threadInfo: ThreadInfo
    
    public init(
        timestamp: Date = Date(),
        wasHit: Bool,
        key: String,
        responseTime: TimeInterval,
        valueSize: Int = 0,
        threadInfo: ThreadInfo = ThreadInfo()
    ) {
        self.timestamp = timestamp
        self.wasHit = wasHit
        self.key = key
        self.responseTime = responseTime
        self.valueSize = valueSize
        self.threadInfo = threadInfo
    }
}

// MARK: - Cache Registry

/// Thread-safe cache management and metrics collection
public class CacheRegistry {
    private static var caches: [String: CacheInstance] = [:]
    private static var operationHistory: [String: [CacheOperation]] = [:]
    private static let registryQueue = DispatchQueue(label: "cache.registry", attributes: .concurrent)
    private static let maxHistoryPerCache = 1000 // Circular buffer size
    
    /// Gets or creates a cache instance for the given key
    public static func getCache(
        for key: String,
        ttl: TimeInterval,
        maxEntries: Int,
        evictionPolicy: CacheEvictionPolicy
    ) -> CacheInstance {
        return registryQueue.sync {
            if let existing = caches[key] {
                return existing
            }
            
            let cache = CacheInstance(
                name: key,
                ttl: ttl,
                maxEntries: maxEntries,
                evictionPolicy: evictionPolicy
            )
            
            caches[key] = cache
            return cache
        }
    }
    
    /// Records a cache operation
    public static func recordOperation(_ operation: CacheOperation, for key: String) {
        registryQueue.async(flags: .barrier) {
            operationHistory[key, default: []].append(operation)
            
            // Maintain circular buffer
            if operationHistory[key]!.count > maxHistoryPerCache {
                operationHistory[key]!.removeFirst()
            }
        }
    }
    
    /// Gets statistics for a specific cache
    public static func getStats(for key: String) -> CacheStats? {
        return registryQueue.sync {
            guard let cache = caches[key],
                  let operations = operationHistory[key] else {
                return nil
            }
            
            return calculateStats(from: operations, cache: cache)
        }
    }
    
    /// Gets statistics for all caches
    public static func getAllStats() -> [String: CacheStats] {
        return registryQueue.sync {
            var result: [String: CacheStats] = [:]
            
            for (key, cache) in caches {
                if let operations = operationHistory[key] {
                    result[key] = calculateStats(from: operations, cache: cache)
                }
            }
            
            return result
        }
    }
    
    /// Clears a specific cache
    public static func clear(for key: String) {
        registryQueue.async(flags: .barrier) {
            caches[key]?.clear()
            operationHistory[key] = []
        }
    }
    
    /// Clears all caches
    public static func clearAll() {
        registryQueue.async(flags: .barrier) {
            for cache in caches.values {
                cache.clear()
            }
            operationHistory.removeAll()
        }
    }
    
    /// Performs cache maintenance (cleanup expired entries)
    public static func performMaintenance() {
        registryQueue.async(flags: .barrier) {
            for cache in caches.values {
                cache.performMaintenance()
            }
        }
    }
    
    /// Prints a comprehensive cache report
    public static func printReport() {
        let allStats = getAllStats()
        guard !allStats.isEmpty else {
            print("📦 No cache data available")
            return
        }
        
        print("\n📦 Cache Report")
        print("=" * 80)
        print(String(format: "%-25s %-8s %8s %8s %8s %8s %8s", "Cache", "Hit%", "Size", "MaxSize", "AvgHit", "AvgMiss", "Memory"))
        print("-" * 80)
        
        for (key, stats) in allStats.sorted(by: { $0.value.hitRate > $1.value.hitRate }) {
            let memoryMB = Double(stats.memoryUsage) / (1024 * 1024)
            print(String(format: "%-25s %-8.1f %8d %8d %8.1f %8.1f %8.1f",
                key.suffix(25),
                stats.hitRate * 100,
                stats.currentSize,
                stats.maxSize,
                stats.averageHitTime * 1000, // Convert to ms
                stats.averageMissTime * 1000, // Convert to ms
                memoryMB
            ))
        }
        
        print("-" * 80)
        print("Legend: Hit% = Hit rate, AvgHit/Miss = Average response time (ms), Memory = Memory usage (MB)")
    }
    
    /// Gets caches with low hit rates
    public static func getLowPerformanceCaches(threshold: Double = 0.5) -> [(String, CacheStats)] {
        let allStats = getAllStats()
        return allStats.compactMap { (key, stats) in
            stats.hitRate < threshold ? (key, stats) : nil
        }.sorted { $0.1.hitRate < $1.1.hitRate }
    }
    
    /// Gets memory usage for all caches combined
    public static func getTotalMemoryUsage() -> Int {
        return getAllStats().values.map { $0.memoryUsage }.reduce(0, +)
    }
    
    // MARK: - Private Helper Methods
    
    private static func calculateStats(from operations: [CacheOperation], cache: CacheInstance) -> CacheStats {
        let totalLookups = operations.count
        let hits = operations.filter { $0.wasHit }.count
        let misses = totalLookups - hits
        let hitRate = totalLookups > 0 ? Double(hits) / Double(totalLookups) : 0.0
        
        let hitTimes = operations.filter { $0.wasHit }.map { $0.responseTime }
        let missTimes = operations.filter { !$0.wasHit }.map { $0.responseTime }
        
        let averageHitTime = hitTimes.isEmpty ? 0.0 : hitTimes.reduce(0, +) / Double(hitTimes.count)
        let averageMissTime = missTimes.isEmpty ? 0.0 : missTimes.reduce(0, +) / Double(missTimes.count)
        
        let memoryUsage = operations.map { $0.valueSize }.reduce(0, +)
        
        return CacheStats(
            cacheName: cache.name,
            currentSize: cache.currentSize,
            maxSize: cache.maxEntries,
            totalLookups: totalLookups,
            hits: hits,
            misses: misses,
            hitRate: hitRate,
            evictions: cache.evictionCount,
            expirations: cache.expirationCount,
            averageHitTime: averageHitTime,
            averageMissTime: averageMissTime,
            memoryUsage: memoryUsage,
            evictionPolicy: cache.evictionPolicy,
            ttl: cache.ttl
        )
    }
}

/// Thread-safe cache instance
public class CacheInstance {
    public let name: String
    public let ttl: TimeInterval
    public let maxEntries: Int
    public let evictionPolicy: CacheEvictionPolicy
    
    private let lock = NSLock()
    private var storage: [String: CacheEntry<Any>] = [:]
    private var accessOrder: [String] = [] // For LRU
    private var accessCounts: [String: Int] = [:] // For LFU
    private var insertionOrder: [String] = [] // For FIFO
    
    private var _evictionCount: Int = 0
    private var _expirationCount: Int = 0
    
    public var currentSize: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
    
    public var evictionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _evictionCount
    }
    
    public var expirationCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _expirationCount
    }
    
    public init(name: String, ttl: TimeInterval, maxEntries: Int, evictionPolicy: CacheEvictionPolicy) {
        self.name = name
        self.ttl = ttl
        self.maxEntries = maxEntries
        self.evictionPolicy = evictionPolicy
    }
    
    /// Gets a value from the cache
    public func get<T>(key: String, type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        guard var entry = storage[key] else {
            return nil
        }
        
        // Check if entry is expired
        if !entry.isValid {
            storage.removeValue(forKey: key)
            removeFromOrderStructures(key: key)
            _expirationCount += 1
            return nil
        }
        
        // Update access information
        entry.recordAccess()
        storage[key] = entry
        updateAccessOrder(key: key)
        
        return entry.value as? T
    }
    
    /// Stores a value in the cache
    public func set<T>(key: String, value: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let entry = CacheEntry(value: value as Any, ttl: ttl, sizeBytes: estimateSize(of: value))
        
        // Check if we need to evict entries
        if storage.count >= maxEntries && storage[key] == nil {
            evictEntries()
        }
        
        // Store the entry
        let isNewEntry = storage[key] == nil
        storage[key] = entry
        
        if isNewEntry {
            addToOrderStructures(key: key)
        } else {
            updateAccessOrder(key: key)
        }
    }
    
    /// Removes a specific key from the cache
    public func remove(key: String) {
        lock.lock()
        defer { lock.unlock() }
        
        storage.removeValue(forKey: key)
        removeFromOrderStructures(key: key)
    }
    
    /// Clears all cache entries
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        storage.removeAll()
        accessOrder.removeAll()
        accessCounts.removeAll()
        insertionOrder.removeAll()
        _evictionCount = 0
        _expirationCount = 0
    }
    
    /// Performs maintenance (removes expired entries)
    public func performMaintenance() {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let expiredKeys = storage.compactMap { (key, entry) in
            entry.expiresAt < now ? key : nil
        }
        
        for key in expiredKeys {
            storage.removeValue(forKey: key)
            removeFromOrderStructures(key: key)
            _expirationCount += 1
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func evictEntries() {
        guard !storage.isEmpty else { return }
        
        let keyToEvict: String
        
        switch evictionPolicy {
        case .lru:
            keyToEvict = accessOrder.first!
        case .lfu:
            keyToEvict = accessCounts.min { $0.value < $1.value }!.key
        case .fifo:
            keyToEvict = insertionOrder.first!
        case .timeOnly:
            return // No size-based eviction for time-only policy
        }
        
        storage.removeValue(forKey: keyToEvict)
        removeFromOrderStructures(key: keyToEvict)
        _evictionCount += 1
    }
    
    private func addToOrderStructures(key: String) {
        switch evictionPolicy {
        case .lru:
            accessOrder.append(key)
        case .lfu:
            accessCounts[key] = 1
        case .fifo:
            insertionOrder.append(key)
        case .timeOnly:
            break
        }
    }
    
    private func updateAccessOrder(key: String) {
        switch evictionPolicy {
        case .lru:
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
            accessOrder.append(key)
        case .lfu:
            accessCounts[key, default: 0] += 1
        case .fifo, .timeOnly:
            break
        }
    }
    
    private func removeFromOrderStructures(key: String) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessCounts.removeValue(forKey: key)
        if let index = insertionOrder.firstIndex(of: key) {
            insertionOrder.remove(at: index)
        }
    }
    
    private func estimateSize<T>(of value: T) -> Int {
        // Basic size estimation - can be improved with more sophisticated logic
        return MemoryLayout.size(ofValue: value)
    }
}

// MARK: - Cache Errors

/// Errors thrown by cache operations
public enum CacheError: Error, LocalizedError {
    case serializationFailed(reason: String)
    case deserializationFailed(reason: String)
    case keyGenerationFailed(reason: String)
    case cacheUnavailable(cacheName: String)
    
    public var errorDescription: String? {
        switch self {
        case .serializationFailed(let reason):
            return "Cache serialization failed: \(reason)"
        case .deserializationFailed(let reason):
            return "Cache deserialization failed: \(reason)"
        case .keyGenerationFailed(let reason):
            return "Cache key generation failed: \(reason)"
        case .cacheUnavailable(let cacheName):
            return "Cache '\(cacheName)' is unavailable"
        }
    }
}

// MARK: - String Extension for Pretty Printing

private extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}