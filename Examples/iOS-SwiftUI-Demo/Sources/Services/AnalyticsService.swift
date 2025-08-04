// AnalyticsService.swift - Analytics service demonstrating @Injectable and @CircuitBreaker
// Copyright © 2025 SwinJectMacros Demo. All rights reserved.

import Foundation
import Swinject
import SwinjectUtilityMacros

// MARK: - Analytics Protocol

protocol AnalyticsServiceProtocol {
    func trackEvent(_ event: AnalyticsEvent) async
    func trackUserAction(_ action: UserAction, userId: String) async
    func trackScreenView(_ screenName: String, userId: String?) async
    func trackError(_ error: Error, context: [String: Any]?) async
    func trackPerformanceMetric(_ metric: PerformanceMetric) async
    func setUserProperties(_ properties: [String: Any], userId: String) async
    func flush() async throws
    func getAnalyticsReport(timeRange: TimeRange) async throws -> AnalyticsReport
}

// MARK: - Analytics Service Implementation

@Injectable
@CircuitBreaker(
    failureThreshold: 5,
    timeoutInterval: 10.0,
    recoveryTimeout: 30.0,
    monitoringEnabled: true
)
@PerformanceTracked(
    trackExecutionTime: true,
    trackMemoryUsage: false,
    logSlowOperations: true,
    slowOperationThreshold: 3.0
)
class AnalyticsService: AnalyticsServiceProtocol {

    // Dependencies
    private let network: NetworkServiceProtocol
    private let database: DatabaseServiceProtocol
    private let logger: LoggerServiceProtocol

    // Event queuing and batching
    private var eventQueue: [AnalyticsEvent] = []
    private let queueQueue = DispatchQueue(label: "analytics.queue", attributes: .concurrent)
    private let maxQueueSize = 1000
    private let batchSize = 50
    private let flushInterval: TimeInterval = 60.0 // 1 minute

    // Circuit breaker state tracking
    private var isServiceHealthy = true
    private var lastHealthCheck = Date()

    init(
        network: NetworkServiceProtocol,
        database: DatabaseServiceProtocol,
        logger: LoggerServiceProtocol
    ) {
        self.network = network
        self.database = database
        self.logger = logger

        logger.info("📊 AnalyticsService initialized with circuit breaker protection")
        setupPeriodicFlush()
        loadQueuedEvents()
    }

    // MARK: - AnalyticsServiceProtocol Implementation

    func trackEvent(_ event: AnalyticsEvent) async {
        logger.info("📈 Tracking event: \(event.name)")

        let enrichedEvent = enrichEvent(event)

        await queueQueue.sync(flags: .barrier) {
            self.eventQueue.append(enrichedEvent)

            // Prevent memory issues with large queues
            if self.eventQueue.count > self.maxQueueSize {
                let eventsToRemove = self.eventQueue.count - self.maxQueueSize + self.batchSize
                self.eventQueue.removeFirst(eventsToRemove)
                self.logger.warning("⚠️ Event queue size exceeded, removed \(eventsToRemove) oldest events")
            }
        }

        // Persist to local storage for reliability
        do {
            _ = try await database.save(enrichedEvent, to: "analytics_events")
        } catch {
            logger.warning("⚠️ Failed to persist event locally: \(error)")
        }

        // Auto-flush if queue is getting full
        let queueSize = await queueQueue.sync { self.eventQueue.count }
        if queueSize >= batchSize {
            Task {
                try? await self.flush()
            }
        }
    }

    func trackUserAction(_ action: UserAction, userId: String) async {
        let event = AnalyticsEvent(
            name: "user_action",
            properties: [
                "action": action.rawValue,
                "user_id": userId,
                "screen": action.screen ?? "unknown",
                "element": action.element ?? "unknown"
            ],
            userId: userId
        )

        await trackEvent(event)
    }

    func trackScreenView(_ screenName: String, userId: String?) async {
        let event = AnalyticsEvent(
            name: "screen_view",
            properties: [
                "screen_name": screenName,
                "user_id": userId ?? "anonymous"
            ],
            userId: userId
        )

        await trackEvent(event)
    }

    func trackError(_ error: Error, context: [String: Any]?) async {
        var properties: [String: Any] = [
            "error_description": error.localizedDescription,
            "error_type": String(describing: type(of: error))
        ]

        if let context = context {
            properties.merge(context) { _, new in new }
        }

        let event = AnalyticsEvent(
            name: "error",
            properties: properties,
            userId: nil
        )

        await trackEvent(event)
        logger.error("📊 Error tracked in analytics: \(error)")
    }

    func trackPerformanceMetric(_ metric: PerformanceMetric) async {
        let event = AnalyticsEvent(
            name: "performance_metric",
            properties: [
                "metric_name": metric.name,
                "value": metric.value,
                "unit": metric.unit,
                "tags": metric.tags
            ],
            userId: nil
        )

        await trackEvent(event)
    }

    func setUserProperties(_ properties: [String: Any], userId: String) async {
        logger.info("👤 Setting user properties for user: \(userId)")

        let event = AnalyticsEvent(
            name: "user_properties_update",
            properties: properties,
            userId: userId
        )

        await trackEvent(event)

        // Also store user properties separately for profile enrichment
        do {
            let userProfile = UserProfile(userId: userId, properties: properties)
            _ = try await database.save(userProfile, to: "user_profiles")
        } catch {
            logger.warning("⚠️ Failed to store user profile: \(error)")
        }
    }

    func flush() async throws {
        logger.info("🚀 Flushing analytics events to server")

        let eventsToFlush = await queueQueue.sync(flags: .barrier) {
            let events = Array(eventQueue.prefix(self.batchSize))
            if !events.isEmpty {
                self.eventQueue.removeFirst(min(self.batchSize, self.eventQueue.count))
            }
            return events
        }

        guard !eventsToFlush.isEmpty else {
            logger.info("📭 No events to flush")
            return
        }

        do {
            // Send batch to analytics service (with circuit breaker protection)
            let batch = AnalyticsBatch(events: eventsToFlush)
            let success = try await network.postData(batch, to: "analytics/batch")

            if success {
                logger.info("✅ Successfully flushed \(eventsToFlush.count) events")
                isServiceHealthy = true

                // Remove successfully sent events from local storage
                for event in eventsToFlush {
                    try? await database.delete(from: "analytics_events", id: event.id)
                }
            } else {
                // Re-queue events on failure
                await requeueEvents(eventsToFlush)
                throw AnalyticsError.flushFailed("Server returned failure response")
            }

        } catch {
            logger.error("❌ Failed to flush events: \(error)")
            isServiceHealthy = false

            // Re-queue events for retry
            await requeueEvents(eventsToFlush)
            throw AnalyticsError.flushFailed(error.localizedDescription)
        }
    }

    func getAnalyticsReport(timeRange: TimeRange) async throws -> AnalyticsReport {
        logger.info("📋 Generating analytics report for: \(timeRange)")

        do {
            // Fetch report from server (with circuit breaker protection)
            let report: AnalyticsReport = try await network.fetchData(
                from: "analytics/report?start=\(timeRange.startDate.timeIntervalSince1970)&end=\(timeRange.endDate.timeIntervalSince1970)",
                type: AnalyticsReport.self
            )

            logger.info("✅ Analytics report generated successfully")
            return report

        } catch {
            logger.error("❌ Failed to generate analytics report: \(error)")

            // Try to generate local report from cached data
            let localReport = try await generateLocalReport(timeRange: timeRange)
            logger.info("📱 Generated local analytics report as fallback")
            return localReport
        }
    }

    // MARK: - Helper Methods

    private func enrichEvent(_ event: AnalyticsEvent) -> AnalyticsEvent {
        var enrichedProperties = event.properties

        // Add common properties
        enrichedProperties["app_version"] = Bundle.main
            .infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        enrichedProperties["platform"] = "iOS"
        enrichedProperties["device_model"] = UIDevice.current.model
        enrichedProperties["os_version"] = UIDevice.current.systemVersion
        enrichedProperties["timestamp"] = event.timestamp.timeIntervalSince1970
        enrichedProperties["session_id"] = getSessionId()

        return AnalyticsEvent(
            id: event.id,
            name: event.name,
            properties: enrichedProperties,
            userId: event.userId,
            timestamp: event.timestamp
        )
    }

    private func setupPeriodicFlush() {
        Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { _ in
            Task {
                try? await self.flush()
            }
        }
    }

    private func loadQueuedEvents() {
        Task {
            do {
                let events: [AnalyticsEvent] = try await database.fetchAll(
                    from: "analytics_events",
                    type: AnalyticsEvent.self
                )

                await self.queueQueue.sync(flags: .barrier) {
                    self.eventQueue.append(contentsOf: events)
                }

                self.logger.info("🔄 Loaded \(events.count) queued analytics events")
            } catch {
                self.logger.warning("⚠️ Failed to load queued events: \(error)")
            }
        }
    }

    private func requeueEvents(_ events: [AnalyticsEvent]) async {
        await queueQueue.sync(flags: .barrier) {
            // Add back to front of queue for retry
            self.eventQueue.insert(contentsOf: events, at: 0)

            // Limit queue size
            if self.eventQueue.count > self.maxQueueSize {
                self.eventQueue = Array(self.eventQueue.prefix(self.maxQueueSize))
            }
        }

        logger.info("🔄 Re-queued \(events.count) events for retry")
    }

    private func generateLocalReport(timeRange: TimeRange) async throws -> AnalyticsReport {
        let events: [AnalyticsEvent] = try await database.fetchAll(
            from: "analytics_events",
            type: AnalyticsEvent.self
        )

        let filteredEvents = events.filter { event in
            event.timestamp >= timeRange.startDate && event.timestamp <= timeRange.endDate
        }

        // Generate basic statistics
        let totalEvents = filteredEvents.count
        let uniqueUsers = Set(filteredEvents.compactMap { $0.userId }).count
        let eventCounts = filteredEvents.reduce(into: [String: Int]()) { counts, event in
            counts[event.name, default: 0] += 1
        }

        return AnalyticsReport(
            timeRange: timeRange,
            totalEvents: totalEvents,
            uniqueUsers: uniqueUsers,
            topEvents: eventCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) },
            generatedAt: Date(),
            isLocalReport: true
        )
    }

    private func getSessionId() -> String {
        // Simple session ID generation for demo
        "session_\(UUID().uuidString.prefix(8))"
    }
}

// MARK: - Analytics Models

struct AnalyticsEvent: Codable, Identifiable {
    let id: String
    let name: String
    let properties: [String: Any]
    let userId: String?
    let timestamp: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        properties: [String: Any] = [:],
        userId: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.properties = properties
        self.userId = userId
        self.timestamp = timestamp
    }

    // Custom coding to handle Any values
    enum CodingKeys: String, CodingKey {
        case id, name, properties, userId, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        // Decode properties as [String: String] for simplicity
        properties = try container.decode([String: String].self, forKey: .properties)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encode(timestamp, forKey: .timestamp)

        // Encode properties as strings
        let stringProperties = properties.mapValues { String(describing: $0) }
        try container.encode(stringProperties, forKey: .properties)
    }
}

enum UserAction: String, CaseIterable {
    case tap = "tap"
    case swipe = "swipe"
    case scroll = "scroll"
    case search = "search"
    case login = "login"
    case logout = "logout"
    case purchase = "purchase"
    case share = "share"
    case like = "like"
    case comment = "comment"

    var screen: String? {
        switch self {
        case .login, .logout: "auth"
        case .purchase: "checkout"
        case .search: "search"
        default: nil
        }
    }

    var element: String? {
        switch self {
        case .tap: "button"
        case .swipe: "card"
        case .scroll: "list"
        default: nil
        }
    }
}

struct PerformanceMetric: Codable {
    let name: String
    let value: Double
    let unit: String
    let tags: [String: String]
    let timestamp: Date

    init(name: String, value: Double, unit: String, tags: [String: String] = [:], timestamp: Date = Date()) {
        self.name = name
        self.value = value
        self.unit = unit
        self.tags = tags
        self.timestamp = timestamp
    }
}

struct UserProfile: Codable {
    let userId: String
    let properties: [String: String] // Simplified for Codable
    let lastUpdated: Date

    init(userId: String, properties: [String: Any], lastUpdated: Date = Date()) {
        self.userId = userId
        self.properties = properties.mapValues { String(describing: $0) }
        self.lastUpdated = lastUpdated
    }
}

struct AnalyticsBatch: Codable {
    let events: [AnalyticsEvent]
    let batchId: String
    let timestamp: Date

    init(events: [AnalyticsEvent], batchId: String = UUID().uuidString, timestamp: Date = Date()) {
        self.events = events
        self.batchId = batchId
        self.timestamp = timestamp
    }
}

struct TimeRange: Codable {
    let startDate: Date
    let endDate: Date

    static func lastHour() -> TimeRange {
        let now = Date()
        return TimeRange(startDate: now.addingTimeInterval(-3600), endDate: now)
    }

    static func lastDay() -> TimeRange {
        let now = Date()
        return TimeRange(startDate: now.addingTimeInterval(-86400), endDate: now)
    }

    static func lastWeek() -> TimeRange {
        let now = Date()
        return TimeRange(startDate: now.addingTimeInterval(-604800), endDate: now)
    }
}

struct AnalyticsReport: Codable {
    let timeRange: TimeRange
    let totalEvents: Int
    let uniqueUsers: Int
    let topEvents: [(String, Int)]
    let generatedAt: Date
    let isLocalReport: Bool

    enum CodingKeys: String, CodingKey {
        case timeRange, totalEvents, uniqueUsers, topEvents, generatedAt, isLocalReport
    }

    init(
        timeRange: TimeRange,
        totalEvents: Int,
        uniqueUsers: Int,
        topEvents: [(String, Int)],
        generatedAt: Date = Date(),
        isLocalReport: Bool = false
    ) {
        self.timeRange = timeRange
        self.totalEvents = totalEvents
        self.uniqueUsers = uniqueUsers
        self.topEvents = topEvents
        self.generatedAt = generatedAt
        self.isLocalReport = isLocalReport
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timeRange = try container.decode(TimeRange.self, forKey: .timeRange)
        totalEvents = try container.decode(Int.self, forKey: .totalEvents)
        uniqueUsers = try container.decode(Int.self, forKey: .uniqueUsers)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        isLocalReport = try container.decodeIfPresent(Bool.self, forKey: .isLocalReport) ?? false

        // Decode top events from array of objects
        let topEventsArray = try container.decode([[String]].self, forKey: .topEvents)
        topEvents = topEventsArray.compactMap { array in
            guard array.count >= 2, let count = Int(array[1]) else { return nil }
            return (array[0], count)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeRange, forKey: .timeRange)
        try container.encode(totalEvents, forKey: .totalEvents)
        try container.encode(uniqueUsers, forKey: .uniqueUsers)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(isLocalReport, forKey: .isLocalReport)

        let topEventsArray = topEvents.map { [$0.0, String($0.1)] }
        try container.encode(topEventsArray, forKey: .topEvents)
    }
}

// MARK: - Analytics Errors

enum AnalyticsError: Error, LocalizedError {
    case flushFailed(String)
    case circuitBreakerOpen
    case invalidEvent
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .flushFailed(let reason):
            "Failed to flush analytics events: \(reason)"
        case .circuitBreakerOpen:
            "Analytics service is temporarily unavailable (circuit breaker open)"
        case .invalidEvent:
            "Invalid analytics event"
        case .serviceUnavailable:
            "Analytics service is currently unavailable"
        }
    }
}
