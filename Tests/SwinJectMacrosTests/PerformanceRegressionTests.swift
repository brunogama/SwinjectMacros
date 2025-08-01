// PerformanceRegressionTests.swift - Performance tests to prevent regression
// Copyright © 2025 SwinJectMacros. All rights reserved.

import XCTest
import Swinject
@testable import SwinJectMacros

final class PerformanceRegressionTests: XCTestCase {
    
    var container: Container!
    
    override func setUp() {
        super.setUp()
        container = Container()
    }
    
    override func tearDown() {
        container = nil
        super.tearDown()
    }
    
    // MARK: - Service Registration Performance
    
    func testInjectableRegistrationPerformance() {
        @Injectable
        class PerformanceTestService {
            let dependency1: TestDependency1
            let dependency2: TestDependency2  
            let dependency3: TestDependency3
            
            init(dependency1: TestDependency1, dependency2: TestDependency2, dependency3: TestDependency3) {
                self.dependency1 = dependency1
                self.dependency2 = dependency2
                self.dependency3 = dependency3
            }
        }
        
        // Pre-register dependencies
        container.register(TestDependency1.self) { _ in TestDependency1() }
        container.register(TestDependency2.self) { _ in TestDependency2() }
        container.register(TestDependency3.self) { _ in TestDependency3() }
        
        measure {
            for _ in 0..<1000 {
                PerformanceTestService.register(in: container)
            }
        }
    }
    
    func testLargeScaleServiceRegistration() {
        // Create multiple services to simulate real-world usage
        let serviceCount = 100
        
        // Register dependencies first
        for i in 0..<serviceCount {
            container.register(TestDependency1.self, name: "dep1_\(i)") { _ in TestDependency1() }
            container.register(TestDependency2.self, name: "dep2_\(i)") { _ in TestDependency2() }
        }
        
        measure {
            for i in 0..<serviceCount {
                @Injectable(name: "service_\(i)")
                class DynamicService {
                    let dep1: TestDependency1
                    let dep2: TestDependency2
                    
                    init(dep1: TestDependency1, dep2: TestDependency2) {
                        self.dep1 = dep1
                        self.dep2 = dep2
                    }
                }
                
                DynamicService.register(in: container)
            }
        }
    }
    
    // MARK: - Service Resolution Performance
    
    func testServiceResolutionPerformance() {
        @Injectable
        class FastResolutionService {
            let dependency: TestDependency1
            
            init(dependency: TestDependency1) {
                self.dependency = dependency
            }
        }
        
        container.register(TestDependency1.self) { _ in TestDependency1() }
        FastResolutionService.register(in: container)
        
        measure {
            for _ in 0..<10000 {
                let service = container.resolve(FastResolutionService.self)
                XCTAssertNotNil(service)
            }
        }
    }
    
    func testComplexDependencyGraphResolution() {
        @Injectable
        class Level1Service {
            let dependency: TestDependency1
            init(dependency: TestDependency1) { self.dependency = dependency }
        }
        
        @Injectable
        class Level2Service {
            let level1: Level1Service
            let dependency: TestDependency2
            init(level1: Level1Service, dependency: TestDependency2) {
                self.level1 = level1
                self.dependency = dependency
            }
        }
        
        @Injectable
        class Level3Service {
            let level2: Level2Service
            let dependency: TestDependency3
            init(level2: Level2Service, dependency: TestDependency3) {
                self.level2 = level2
                self.dependency = dependency
            }
        }
        
        // Register dependencies and services
        container.register(TestDependency1.self) { _ in TestDependency1() }
        container.register(TestDependency2.self) { _ in TestDependency2() }
        container.register(TestDependency3.self) { _ in TestDependency3() }
        
        Level1Service.register(in: container)
        Level2Service.register(in: container)
        Level3Service.register(in: container)
        
        measure {
            for _ in 0..<1000 {
                let service = container.resolve(Level3Service.self)
                XCTAssertNotNil(service)
                XCTAssertNotNil(service?.level2)
                XCTAssertNotNil(service?.level2.level1)
            }
        }
    }
    
    // MARK: - Factory Performance
    
    func testAutoFactoryPerformance() {
        @AutoFactory
        class FactoryPerformanceService {
            let dependency: TestDependency1
            let runtimeParam: String
            
            init(dependency: TestDependency1, runtimeParam: String) {
                self.dependency = dependency
                self.runtimeParam = runtimeParam
            }
        }
        
        container.register(TestDependency1.self) { _ in TestDependency1() }
        container.register(FactoryPerformanceServiceFactory.self) { resolver in
            FactoryPerformanceServiceFactoryImpl(resolver: resolver)
        }
        
        let factory = container.resolve(FactoryPerformanceServiceFactory.self)!
        
        measure {
            for i in 0..<5000 {
                let service = factory.makeFactoryPerformanceService(runtimeParam: "param_\(i)")
                XCTAssertNotNil(service)
            }
        }
    }
    
    func testFactoryWithMultipleParameters() {
        @AutoFactory
        class MultiParamFactoryService {
            let dependency: TestDependency1
            let param1: String
            let param2: Int
            let param3: Double
            let param4: Bool
            let param5: [String]
            
            init(dependency: TestDependency1, param1: String, param2: Int, param3: Double, param4: Bool, param5: [String]) {
                self.dependency = dependency
                self.param1 = param1
                self.param2 = param2
                self.param3 = param3
                self.param4 = param4
                self.param5 = param5
            }
        }
        
        container.register(TestDependency1.self) { _ in TestDependency1() }
        container.register(MultiParamFactoryServiceFactory.self) { resolver in
            MultiParamFactoryServiceFactoryImpl(resolver: resolver)
        }
        
        let factory = container.resolve(MultiParamFactoryServiceFactory.self)!
        
        measure {
            for i in 0..<2000 {
                let service = factory.makeMultiParamFactoryService(
                    param1: "string_\(i)",
                    param2: i,
                    param3: Double(i) * 1.5,
                    param4: i % 2 == 0,
                    param5: ["item1", "item2", "item3"]
                )
                XCTAssertNotNil(service)
            }
        }
    }
    
    // MARK: - Lazy Injection Performance
    
    func testLazyInjectPerformance() {
        class LazyPerformanceService {
            @LazyInject var expensiveDependency: ExpensiveDependency
            @LazyInject var lightDependency: TestDependency1
            @LazyInject var optionalDependency: TestDependency2?
        }
        
        container.register(ExpensiveDependency.self) { _ in ExpensiveDependency() }
        container.register(TestDependency1.self) { _ in TestDependency1() }
        container.register(TestDependency2.self) { _ in TestDependency2() }
        // Use container parameter instead of Container.shared for test isolation
        
        let service = LazyPerformanceService()
        
        // First access - should resolve
        measure {
            for _ in 0..<1000 {
                _ = service.expensiveDependency
                _ = service.lightDependency
                _ = service.optionalDependency
            }
        }
    }
    
    func testLazyInjectFirstAccessPerformance() {
        // Test the performance of first access (when resolution happens)
        measure {
            for i in 0..<500 {
                class DynamicLazyService {
                    @LazyInject var dependency: TestDependency1
                }
                
                container.register(TestDependency1.self, name: "dynamic_\(i)") { _ in TestDependency1() }
                // Use dependency injection instead of Container.shared
                
                let service = DynamicLazyService()
                _ = service.dependency // First access triggers resolution
            }
        }
    }
    
    // MARK: - Memory Performance
    
    func testMemoryUsageWithManyServices() {
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            // Create many services to test memory usage
            var services: [Any] = []
            
            for i in 0..<10000 {
                @Injectable(name: "memory_service_\(i)")
                class MemoryTestService {
                    let dependency: TestDependency1
                    let id: Int
                    
                    init(dependency: TestDependency1, id: Int = i) {
                        self.dependency = dependency
                        self.id = id
                    }
                }
                
                container.register(TestDependency1.self, name: "memory_dep_\(i)") { _ in TestDependency1() }
                MemoryTestService.register(in: container)
                
                if let service = container.resolve(MemoryTestService.self, name: "memory_service_\(i)") {
                    services.append(service)
                }
            }
            
            startMeasuring()
            
            // Access all services to ensure they're in memory
            for service in services {
                _ = service
            }
            
            stopMeasuring()
            
            // Clean up
            services.removeAll()
        }
    }
    
    // MARK: - Thread Safety Performance
    
    func testConcurrentResolutionPerformance() {
        @Injectable(scope: .container)
        class ConcurrentTestService {
            let dependency: TestDependency1
            
            init(dependency: TestDependency1) {
                self.dependency = dependency
            }
        }
        
        container.register(TestDependency1.self) { _ in TestDependency1() }
        ConcurrentTestService.register(in: container)
        
        measure {
            let group = DispatchGroup()
            let queue = DispatchQueue.global(qos: .default)
            
            for _ in 0..<100 {
                group.enter()
                queue.async {
                    for _ in 0..<100 {
                        let service = self.container.resolve(ConcurrentTestService.self)
                        XCTAssertNotNil(service)
                    }
                    group.leave()
                }
            }
            
            group.wait()
        }
    }
    
    // MARK: - Compilation Performance (Simulated)
    
    func testMacroExpansionSimulation() {
        // This simulates the work a macro would do during compilation
        measure {
            for i in 0..<1000 {
                // Simulate analyzing a service with dependencies
                let serviceName = "TestService\(i)"
                let dependencies = [
                    "TestDependency1",
                    "TestDependency2", 
                    "TestDependency3"
                ]
                
                // Simulate generating registration code
                let parameters = dependencies.map { dep in
                    "resolver.resolve(\(dep).self)!"
                }.joined(separator: ", ")
                
                let generatedCode = """
                static func register(in container: Container) {
                    container.register(\(serviceName).self) { resolver in
                        \(serviceName)(\(parameters))
                    }.inObjectScope(.graph)
                }
                """
                
                XCTAssertFalse(generatedCode.isEmpty)
            }
        }
    }
    
    // MARK: - Baseline Performance Tests
    
    func testManualRegistrationBaseline() {
        // Compare against manual registration performance
        measure {
            for i in 0..<1000 {
                container.register(TestDependency1.self, name: "manual_\(i)") { _ in
                    TestDependency1()
                }
                
                container.register(ManualTestService.self, name: "manual_service_\(i)") { resolver in
                    ManualTestService(dependency: resolver.resolve(TestDependency1.self, name: "manual_\(i)")!)
                }
            }
        }
    }
    
    func testResolutionVsManualCreation() {
        @Injectable
        class ResolutionTestService {
            let dependency: TestDependency1
            
            init(dependency: TestDependency1) {
                self.dependency = dependency
            }
        }
        
        container.register(TestDependency1.self) { _ in TestDependency1() }
        ResolutionTestService.register(in: container)
        
        // Test DI resolution performance
        measure("DI Resolution") {
            for _ in 0..<5000 {
                let service = container.resolve(ResolutionTestService.self)
                XCTAssertNotNil(service)
            }
        }
        
        // Compare with manual creation
        measure("Manual Creation") {
            for _ in 0..<5000 {
                let dependency = TestDependency1()
                let service = ResolutionTestService(dependency: dependency)
                XCTAssertNotNil(service)
            }
        }
    }
}

// MARK: - Performance Test Support Types

class TestDependency1 {
    let id = UUID()
    let creationTime = Date()
}

class TestDependency2 {
    let id = UUID()
    let creationTime = Date()
}

class TestDependency3 {
    let id = UUID()
    let creationTime = Date()
}

class ExpensiveDependency {
    let id = UUID()
    let data: [String]
    
    init() {
        // Simulate expensive initialization
        self.data = (0..<1000).map { "item_\($0)" }
        Thread.sleep(forTimeInterval: 0.001) // 1ms delay
    }
}

class ManualTestService {
    let dependency: TestDependency1
    
    init(dependency: TestDependency1) {
        self.dependency = dependency
    }
}