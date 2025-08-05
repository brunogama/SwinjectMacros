# Quick Start Guide

Get up and running with SwinjectMacros in minutes.

## Overview

This guide will walk you through setting up SwinjectMacros in your project and creating your first injectable services. You'll learn the basics of the three main macros and see them work together in a real example.

## Installation

### Swift Package Manager

Add SwinjectMacros to your project via Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/brunogama/SwinjectMacros.git", from: "1.0.2")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["SwinjectMacros"]
    )
]
```

### Requirements

- **Swift 5.9+** (Required for macro support)
- **iOS 15.0+** / **macOS 12.0+** / **watchOS 8.0+** / **tvOS 15.0+**
- **Xcode 15.0+**

## Your First Injectable Service

Let's create a simple user service with automatic dependency injection:

### 1. Define Your Services

```swift
import SwinjectMacros
import Swinject

// A simple API client
@Injectable(scope: .container)
class APIClient {
    let baseURL: String

    init() {
        self.baseURL = "https://api.example.com"
    }

    func fetchUser(id: String) async throws -> UserData {
        // Simulate API call
        return UserData(id: id, name: "John Doe", email: "john@example.com")
    }
}

// A database service
@Injectable(scope: .container)
class DatabaseService {
    init() {
        print("Database connection established")
    }

    func save(_ userData: UserData) async throws {
        print("Saving user: \(userData.name)")
    }
}

// Your business logic service
@Injectable
class UserService {
    private let apiClient: APIClient
    private let database: DatabaseService

    init(apiClient: APIClient, database: DatabaseService) {
        self.apiClient = apiClient
        self.database = database
    }

    func getUser(id: String) async throws -> User {
        let userData = try await apiClient.fetchUser(id: id)
        try await database.save(userData)
        return User(from: userData)
    }
}

// Supporting types
struct UserData {
    let id: String
    let name: String
    let email: String
}

struct User {
    let id: String
    let name: String
    let email: String

    init(from userData: UserData) {
        self.id = userData.id
        self.name = userData.name
        self.email = userData.email
    }
}
```

### 2. Set Up Your Container

```swift
import Swinject

class AppAssembly: Assembly {
    func assemble(container: Container) {
        // Register all @Injectable services
        APIClient.register(in: container)
        DatabaseService.register(in: container)
        UserService.register(in: container)
    }
}

// In your app setup (AppDelegate, SceneDelegate, or App struct)
class AppSetup {
    static let shared = AppSetup()
    let container = Container()

    private init() {
        let assembler = Assembler([AppAssembly()], container: container)
    }
}
```

### 3. Use Your Services

```swift
// Get your service from the container
let userService = AppSetup.shared.container.resolve(UserService.self)!

// Use your service
Task {
    do {
        let user = try await userService.getUser(id: "123")
        print("Retrieved user: \(user.name)")
    } catch {
        print("Error: \(error)")
    }
}
```

## Services with Runtime Parameters

Some services need both injected dependencies AND runtime parameters. Use `@AutoFactory` for these cases:

### 1. Define a Factory Service

```swift
@AutoFactory
class ReportGenerator {
    private let database: DatabaseService  // Injected dependency
    private let apiClient: APIClient       // Injected dependency
    private let reportType: ReportType     // Runtime parameter
    private let dateRange: DateRange       // Runtime parameter

    init(database: DatabaseService, apiClient: APIClient,
         reportType: ReportType, dateRange: DateRange) {
        self.database = database
        self.apiClient = apiClient
        self.reportType = reportType
        self.dateRange = dateRange
    }

    func generateReport() async throws -> Report {
        // Use injected services and runtime parameters
        print("Generating \(reportType) report for \(dateRange)")
        return Report(type: reportType, data: "Sample data")
    }
}

// Supporting types
enum ReportType {
    case daily, weekly, monthly
}

struct DateRange {
    let start: Date
    let end: Date
}

struct Report {
    let type: ReportType
    let data: String
}
```

### 2. Register the Factory

```swift
class AppAssembly: Assembly {
    func assemble(container: Container) {
        // Register dependencies
        APIClient.register(in: container)
        DatabaseService.register(in: container)
        UserService.register(in: container)

        // Register the factory (automatically generated)
        container.registerFactory(ReportGeneratorFactory.self)
    }
}
```

### 3. Use the Factory

```swift
// Get the factory from the container
let reportFactory = AppSetup.shared.container.resolve(ReportGeneratorFactory.self)!

// Create reports with runtime parameters
let generator = reportFactory.makeReportGenerator(
    reportType: .monthly,
    dateRange: DateRange(start: Date(), end: Date())
)

Task {
    let report = try await generator.generateReport()
    print("Generated report: \(report)")
}
```

## Testing with Mocks

SwinjectMacros makes testing easy with automatic mock generation:

### 1. Set Up Your Test Class

```swift
import XCTest
@testable import YourApp

@TestContainer
class UserServiceTests: XCTestCase {
    var container: Container!

    // These properties are automatically detected as services needing mocks
    var apiClient: APIClient!
    var database: DatabaseService!

    var userService: UserService!

    override func setUp() {
        super.setUp()

        // Generated method creates container with mocks
        container = setupTestContainer()

        // Resolve the mocked dependencies
        apiClient = container.resolve(APIClient.self)!
        database = container.resolve(DatabaseService.self)!

        // Register and resolve your service under test
        UserService.register(in: container)
        userService = container.resolve(UserService.self)!
    }

    func testGetUser() async throws {
        // Setup mock behavior
        let mockAPI = apiClient as! MockAPIClient
        mockAPI.fetchUserResult = UserData(id: "123", name: "Test User", email: "test@example.com")

        // Test your service
        let user = try await userService.getUser(id: "123")

        // Verify results
        XCTAssertEqual(user.name, "Test User")
        XCTAssertTrue(mockAPI.fetchUserCalled)
    }
}
```

### 2. Create Mock Classes

```swift
// Mock implementations (you can also use a mocking framework)
class MockAPIClient: APIClient {
    var fetchUserCalled = false
    var fetchUserResult: UserData?

    override func fetchUser(id: String) async throws -> UserData {
        fetchUserCalled = true
        guard let result = fetchUserResult else {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        return result
    }
}

class MockDatabaseService: DatabaseService {
    var saveCalled = false
    var savedUserData: UserData?

    override func save(_ userData: UserData) async throws {
        saveCalled = true
        savedUserData = userData
    }
}
```

## Complete SwiftUI Example

Here's a complete example showing SwinjectMacros in a SwiftUI app:

### 1. Services and Models

```swift
import SwiftUI
import SwinjectMacros
import Swinject

// MARK: - Models
struct Todo: Identifiable {
    let id = UUID()
    let title: String
    let isCompleted: Bool
}

// MARK: - Services
@Injectable(scope: .container)
class TodoRepository {
    private var todos: [Todo] = [
        Todo(title: "Learn SwiftUI", isCompleted: true),
        Todo(title: "Try SwinjectMacros", isCompleted: false),
        Todo(title: "Build awesome apps", isCompleted: false)
    ]

    init() {
        print("TodoRepository initialized")
    }

    func getAllTodos() -> [Todo] {
        return todos
    }

    func toggleTodo(id: UUID) {
        // Implementation
    }
}

@Injectable
class TodoService {
    private let repository: TodoRepository

    init(repository: TodoRepository) {
        self.repository = repository
    }

    func getTodos() -> [Todo] {
        return repository.getAllTodos()
    }

    func toggleCompletion(for todoId: UUID) {
        repository.toggleTodo(id: todoId)
    }
}
```

### 2. SwiftUI Views

```swift
// MARK: - Views
struct ContentView: View {
    @StateObject private var viewModel: TodoViewModel

    init() {
        let todoService = AppSetup.shared.container.resolve(TodoService.self)!
        self._viewModel = StateObject(wrappedValue: TodoViewModel(todoService: todoService))
    }

    var body: some View {
        NavigationView {
            List(viewModel.todos) { todo in
                HStack {
                    Text(todo.title)
                    Spacer()
                    if todo.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Todos")
            .onAppear {
                viewModel.loadTodos()
            }
        }
    }
}

// MARK: - View Model
class TodoViewModel: ObservableObject {
    @Published var todos: [Todo] = []

    private let todoService: TodoService

    init(todoService: TodoService) {
        self.todoService = todoService
    }

    func loadTodos() {
        todos = todoService.getTodos()
    }
}
```

### 3. App Setup

```swift
@main
struct MyTodoApp: App {
    init() {
        // Initialize dependency injection
        _ = AppSetup.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Dependency Injection Setup
class AppSetup {
    static let shared = AppSetup()
    let container = Container()

    private init() {
        let assembler = Assembler([AppAssembly()], container: container)
    }
}

class AppAssembly: Assembly {
    func assemble(container: Container) {
        TodoRepository.register(in: container)
        TodoService.register(in: container)
    }
}
```

## What Just Happened?

1. **`@Injectable`** automatically generated registration code for your services
1. **`@AutoFactory`** created a factory for services needing runtime parameters
1. **`@TestContainer`** set up your test environment with mocks
1. **All at compile-time** with zero runtime overhead!

## Next Steps

Now that you've seen the basics, explore these advanced features:

- **Module System**: Organize services into modules with lifecycle management
- **Performance Optimization**: Use built-in caching and optimization strategies
- **Hot-Swap Modules**: Replace modules at runtime without stopping your app
- **AOP Features**: Add logging, retry logic, and circuit breakers with `@Interceptor`
- **Advanced Testing**: Use spies, stubs, and advanced mocking features

## Common Patterns

### Repository Pattern

```swift
@Injectable(scope: .container)
class DatabaseService {
    init() { }
}

@Injectable
class UserRepository {
    init(database: DatabaseService) { }
}

@Injectable
class UserService {
    init(repository: UserRepository) { }
}
```

### Service Layer Pattern

```swift
// Data Layer
@Injectable
class NetworkClient { init() { } }
@Injectable
class LocalStorage { init() { } }

// Service Layer
@Injectable
class DataSyncService {
    init(network: NetworkClient, storage: LocalStorage) { }
}

// Presentation Layer
@Injectable
class UserViewModel {
    init(syncService: DataSyncService) { }
}
```

### Factory Pattern for Runtime Dependencies

```swift
// Services without runtime params
@Injectable
class EmailService { init(smtp: SMTPClient) { } }

// Services with runtime params
@AutoFactory
class EmailComposer {
    init(emailService: EmailService, recipient: String, subject: String) { }
}
```

You're now ready to use SwinjectMacros in your projects! The macro system will grow with you as your application becomes more complex.

## See Also

- <doc:Injectable>
- <doc:AutoFactory>
- <doc:TestContainer>
- <doc:Module-System>
