// DatabaseService.swift - Database service demonstrating @Injectable and @ScopedService
// Copyright © 2025 SwinJectMacros Demo. All rights reserved.

import Foundation
import Swinject
import SwinjectUtilityMacros

// MARK: - Database Protocol

protocol DatabaseServiceProtocol {
    func save(_ entity: some Codable, to collection: String) async throws -> String
    func fetch<T: Codable>(from collection: String, id: String, type: T.Type) async throws -> T?
    func fetchAll<T: Codable>(from collection: String, type: T.Type) async throws -> [T]
    func delete(from collection: String, id: String) async throws -> Bool
    func query<T: Codable>(from collection: String, where predicate: String, type: T.Type) async throws -> [T]
}

// MARK: - Database Service Implementation

@Injectable
@ScopedService(.container)
@PerformanceTracked(
    trackExecutionTime: true,
    trackMemoryUsage: true,
    logSlowOperations: true,
    slowOperationThreshold: 1.0
)
class DatabaseService: DatabaseServiceProtocol {

    // Dependencies
    private let logger: LoggerServiceProtocol
    private let configuration: ConfigurationServiceProtocol

    // In-memory storage for demo purposes
    private var storage: [String: [String: Data]] = [:]
    private let queue = DispatchQueue(label: "database.queue", attributes: .concurrent)

    init(
        logger: LoggerServiceProtocol,
        configuration: ConfigurationServiceProtocol
    ) {
        self.logger = logger
        self.configuration = configuration

        logger.info("🗄️ DatabaseService initialized with container scope")
        initializeDefaultData()
    }

    // MARK: - DatabaseServiceProtocol Implementation

    func save(_ entity: some Codable, to collection: String) async throws -> String {
        logger.info("💾 Saving entity to collection: \(collection)")

        return try await withCheckedThrowingContinuation { continuation in
            self.queue.async(flags: .barrier) {
                do {
                    let id = UUID().uuidString
                    let data = try JSONEncoder().encode(entity)

                    if self.storage[collection] == nil {
                        self.storage[collection] = [:]
                    }
                    self.storage[collection]![id] = data

                    self.logger.info("✅ Entity saved with ID: \(id)")
                    continuation.resume(returning: id)
                } catch {
                    self.logger.error("❌ Failed to save entity: \(error)")
                    continuation.resume(throwing: DatabaseError.saveFailed(error))
                }
            }
        }
    }

    func fetch<T: Codable>(from collection: String, id: String, type: T.Type) async throws -> T? {
        logger.info("🔍 Fetching entity from \(collection) with ID: \(id)")

        return try await withCheckedThrowingContinuation { continuation in
            self.queue.async {
                do {
                    guard let collectionData = self.storage[collection],
                          let entityData = collectionData[id]
                    else {
                        self.logger.info("📭 Entity not found with ID: \(id)")
                        continuation.resume(returning: nil)
                        return
                    }

                    let entity = try JSONDecoder().decode(type, from: entityData)
                    self.logger.info("✅ Entity fetched successfully")
                    continuation.resume(returning: entity)
                } catch {
                    self.logger.error("❌ Failed to fetch entity: \(error)")
                    continuation.resume(throwing: DatabaseError.fetchFailed(error))
                }
            }
        }
    }

    func fetchAll<T: Codable>(from collection: String, type: T.Type) async throws -> [T] {
        logger.info("📊 Fetching all entities from collection: \(collection)")

        return try await withCheckedThrowingContinuation { continuation in
            self.queue.async {
                do {
                    guard let collectionData = self.storage[collection] else {
                        self.logger.info("📭 Collection not found: \(collection)")
                        continuation.resume(returning: [])
                        return
                    }

                    let entities = try collectionData.values.map { data in
                        try JSONDecoder().decode(type, from: data)
                    }

                    self.logger.info("✅ Fetched \(entities.count) entities")
                    continuation.resume(returning: entities)
                } catch {
                    self.logger.error("❌ Failed to fetch all entities: \(error)")
                    continuation.resume(throwing: DatabaseError.fetchFailed(error))
                }
            }
        }
    }

    func delete(from collection: String, id: String) async throws -> Bool {
        logger.info("🗑️ Deleting entity from \(collection) with ID: \(id)")

        return try await withCheckedThrowingContinuation { continuation in
            self.queue.async(flags: .barrier) {
                guard var collectionData = self.storage[collection] else {
                    self.logger.warning("⚠️ Collection not found: \(collection)")
                    continuation.resume(returning: false)
                    return
                }

                let wasDeleted = collectionData.removeValue(forKey: id) != nil
                self.storage[collection] = collectionData

                if wasDeleted {
                    self.logger.info("✅ Entity deleted successfully")
                } else {
                    self.logger.warning("⚠️ Entity not found for deletion")
                }

                continuation.resume(returning: wasDeleted)
            }
        }
    }

    func query<T: Codable>(from collection: String, where predicate: String, type: T.Type) async throws -> [T] {
        logger.info("🔎 Querying collection \(collection) with predicate: \(predicate)")

        return try await withCheckedThrowingContinuation { continuation in
            self.queue.async {
                do {
                    guard let collectionData = self.storage[collection] else {
                        self.logger.info("📭 Collection not found: \(collection)")
                        continuation.resume(returning: [])
                        return
                    }

                    let entities = try collectionData.values.compactMap { data -> T? in
                        try JSONDecoder().decode(type, from: data)
                    }

                    // Simple predicate filtering (demo implementation)
                    let filteredEntities = entities // In real app, apply predicate logic

                    self.logger.info("✅ Query returned \(filteredEntities.count) entities")
                    continuation.resume(returning: filteredEntities)
                } catch {
                    self.logger.error("❌ Query failed: \(error)")
                    continuation.resume(throwing: DatabaseError.queryFailed(error))
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func initializeDefaultData() {
        logger.info("🚀 Initializing default database data")

        // Initialize some demo data
        queue.async(flags: .barrier) {
            self.storage["users"] = [:]
            self.storage["posts"] = [:]
            self.storage["comments"] = [:]

            self.logger.info("✅ Default collections created")
        }
    }
}

// MARK: - Database Errors

enum DatabaseError: Error, LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case queryFailed(Error)
    case collectionNotFound(String)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            "Failed to save entity: \(error.localizedDescription)"
        case .fetchFailed(let error):
            "Failed to fetch entity: \(error.localizedDescription)"
        case .deleteFailed(let error):
            "Failed to delete entity: \(error.localizedDescription)"
        case .queryFailed(let error):
            "Query failed: \(error.localizedDescription)"
        case .collectionNotFound(let collection):
            "Collection not found: \(collection)"
        case .invalidData:
            "Invalid data format"
        }
    }
}

// MARK: - Demo Data Models

struct User: Codable, Identifiable {
    let id: String
    let name: String
    let email: String
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, email: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }
}

struct Post: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let content: String
    let createdAt: Date

    init(id: String = UUID().uuidString, userId: String, title: String, content: String, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }
}
