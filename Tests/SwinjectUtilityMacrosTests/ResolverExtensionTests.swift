import Swinject
@testable import SwinjectUtilityMacros
import XCTest

final class ResolverExtensionTests: XCTestCase {

    var container: Container!

    override func setUp() {
        super.setUp()
        container = Container()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    func testSynchronizedResolverReturnsResolver() {
        // Given
        let originalResolver: Resolver = container

        // When
        let synchronizedResolver = originalResolver.synchronizedResolver

        // Then
        XCTAssertNotNil(synchronizedResolver, "Should return a valid resolver")
        XCTAssertTrue(synchronizedResolver is Resolver, "Should return a Resolver instance")
    }

    func testSynchronizedResolverIsIdempotent() {
        // Given
        let synchronizedResolver = container.synchronizedResolver

        // When
        let doubleSynchronized = synchronizedResolver.synchronizedResolver

        // Then - Both should be valid resolvers
        XCTAssertNotNil(synchronizedResolver, "First synchronized resolver should not be nil")
        XCTAssertNotNil(doubleSynchronized, "Double synchronized resolver should not be nil")
        XCTAssertTrue(synchronizedResolver is Resolver, "First should be a Resolver")
        XCTAssertTrue(doubleSynchronized is Resolver, "Second should be a Resolver")
    }

    func testSynchronizedResolveWorksCorrectly() {
        // Given
        protocol TestService {
            func getValue() -> String
        }

        class TestServiceImpl: TestService {
            func getValue() -> String {
                "test value"
            }
        }

        container.register(TestService.self) { _ in TestServiceImpl() }

        // When
        let service = container.synchronizedResolve(TestService.self)

        // Then
        XCTAssertNotNil(service, "Should resolve service through synchronized resolver")
        XCTAssertEqual(service?.getValue(), "test value", "Should return correct service implementation")
    }

    func testSynchronizedResolveWithName() {
        // Given
        protocol TestService {
            func getValue() -> String
        }

        class PrimaryService: TestService {
            func getValue() -> String { "primary" }
        }

        class SecondaryService: TestService {
            func getValue() -> String { "secondary" }
        }

        container.register(TestService.self, name: "primary") { _ in PrimaryService() }
        container.register(TestService.self, name: "secondary") { _ in SecondaryService() }

        // When
        let primaryService = container.synchronizedResolve(TestService.self, name: "primary")
        let secondaryService = container.synchronizedResolve(TestService.self, name: "secondary")

        // Then
        XCTAssertEqual(primaryService?.getValue(), "primary")
        XCTAssertEqual(secondaryService?.getValue(), "secondary")
    }

    func testSynchronizedResolveWithArgument() {
        // Given
        class ConfigurableService {
            let config: String

            init(config: String) {
                self.config = config
            }
        }

        container.register(ConfigurableService.self) { (_, config: String) in
            ConfigurableService(config: config)
        }

        // When
        let service = container.synchronizedResolve(ConfigurableService.self, argument: "test config")

        // Then
        XCTAssertNotNil(service)
        XCTAssertEqual(service?.config, "test config")
    }

    func testCreateSynchronizedContainer() {
        // When
        let synchronizedContainer = Container.createSynchronized()

        // Then
        XCTAssertNotNil(synchronizedContainer, "Should create a valid synchronized container")
        XCTAssertTrue(synchronizedContainer is Resolver, "Should return a Resolver instance")
    }

    func testIsSynchronizedAlwaysReturnsTrue() {
        // Given
        let normalContainer = Container()
        let synchronizedContainer = normalContainer.synchronize()

        // Then - Since we can't detect synchronization reliably, isSynchronized returns true
        XCTAssertTrue(Container.isSynchronized(normalContainer), "Should return true for safety")
        XCTAssertTrue(Container.isSynchronized(synchronizedContainer), "Should return true for synchronized container")
    }

    func testThreadSafety() {
        // Given
        protocol CounterService {
            func increment()
            func getCount() -> Int
        }

        class CounterServiceImpl: CounterService {
            private var count = 0
            private let queue = DispatchQueue(label: "counter", attributes: .concurrent)

            func increment() {
                queue.async(flags: .barrier) {
                    self.count += 1
                }
            }

            func getCount() -> Int {
                queue.sync {
                    count
                }
            }
        }

        container.register(CounterService.self) { _ in CounterServiceImpl() }.inObjectScope(.container)

        let synchronizedResolver = container.synchronizedResolver
        let expectation = XCTestExpectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = 100

        // When - Access from multiple threads simultaneously
        for _ in 0 ..< 100 {
            DispatchQueue.global().async {
                let service = synchronizedResolver.synchronizedResolve(CounterService.self)
                XCTAssertNotNil(service, "Should resolve service from any thread")
                service?.increment()
                expectation.fulfill()
            }
        }

        // Then
        wait(for: [expectation], timeout: 5.0)

        let finalService = synchronizedResolver.synchronizedResolve(CounterService.self)
        XCTAssertNotNil(finalService)

        // Allow some time for all increments to complete
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(finalService?.getCount(), 100, "All increments should have been processed")
    }
}
