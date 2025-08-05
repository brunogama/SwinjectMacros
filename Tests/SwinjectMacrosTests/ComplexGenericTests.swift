// ComplexGenericTests.swift - Complex generic type scenario tests

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwinjectMacrosImplementation

final class ComplexGenericTests: XCTestCase {

    // MARK: - @Injectable with Complex Generics

    func testInjectableWithComplexGenericConstraints() {
        assertMacroExpansion("""
        @Injectable
        class GenericRepository<T: Codable & Hashable, U: Collection> where U.Element == T {
            init(database: Database<T>, cache: Cache<U>) {
                self.database = database
                self.cache = cache
            }

            let database: Database<T>
            let cache: Cache<U>
        }
        """, expandedSource: """
        class GenericRepository<T: Codable & Hashable, U: Collection> where U.Element == T {
            init(database: Database<T>, cache: Cache<U>) {
                self.database = database
                self.cache = cache
            }

            let database: Database<T>
            let cache: Cache<U>

            static func register(in container: Container) {
                container.register(GenericRepository.self) { resolver in
                    GenericRepository(
                        database: resolver.synchronizedResolve(Database<T>.self)!,
                        cache: resolver.synchronizedResolve(Cache<U>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension GenericRepository: Injectable {
        }
        """, macros: testMacros)
    }

    func testInjectableWithNestedGenerics() {
        assertMacroExpansion("""
        @Injectable
        class DataProcessor<T> {
            init(
                resultProcessor: ResultProcessor<Result<T, ProcessingError>>,
                eventPublisher: EventPublisher<DataProcessingEvent<T>>
            ) {
                self.resultProcessor = resultProcessor
                self.eventPublisher = eventPublisher
            }

            let resultProcessor: ResultProcessor<Result<T, ProcessingError>>
            let eventPublisher: EventPublisher<DataProcessingEvent<T>>
        }
        """, expandedSource: """
        class DataProcessor<T> {
            init(
                resultProcessor: ResultProcessor<Result<T, ProcessingError>>,
                eventPublisher: EventPublisher<DataProcessingEvent<T>>
            ) {
                self.resultProcessor = resultProcessor
                self.eventPublisher = eventPublisher
            }

            let resultProcessor: ResultProcessor<Result<T, ProcessingError>>
            let eventPublisher: EventPublisher<DataProcessingEvent<T>>

            static func register(in container: Container) {
                container.register(DataProcessor.self) { resolver in
                    DataProcessor(
                        resultProcessor: resolver.synchronizedResolve(ResultProcessor<Result<T, ProcessingError>>.self)!,
                        eventPublisher: resolver.synchronizedResolve(EventPublisher<DataProcessingEvent<T>>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension DataProcessor: Injectable {
        }
        """, macros: testMacros)
    }

    func testInjectableWithAssociatedTypes() {
        assertMacroExpansion("""
        @Injectable
        class ProtocolBasedService<P: DataProviderProtocol> where P.DataType: Codable {
            init(provider: P, serializer: Serializer<P.DataType>) {
                self.provider = provider
                self.serializer = serializer
            }

            let provider: P
            let serializer: Serializer<P.DataType>
        }
        """, expandedSource: """
        class ProtocolBasedService<P: DataProviderProtocol> where P.DataType: Codable {
            init(provider: P, serializer: Serializer<P.DataType>) {
                self.provider = provider
                self.serializer = serializer
            }

            let provider: P
            let serializer: Serializer<P.DataType>

            static func register(in container: Container) {
                container.register(ProtocolBasedService.self) { resolver in
                    ProtocolBasedService(
                        provider: resolver.synchronizedResolve(P.self)!,
                        serializer: resolver.synchronizedResolve(Serializer<P.DataType>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension ProtocolBasedService: Injectable {
        }
        """, macros: testMacros)
    }

    func testInjectableWithExistentialTypes() {
        assertMacroExpansion("""
        @Injectable
        class ServiceContainer {
            init(
                anyProcessor: any DataProcessor,
                someValidator: some Validator,
                erasedService: AnyService<String>
            ) {
                self.anyProcessor = anyProcessor
                self.someValidator = someValidator
                self.erasedService = erasedService
            }

            let anyProcessor: any DataProcessor
            let someValidator: some Validator
            let erasedService: AnyService<String>
        }
        """, expandedSource: """
        class ServiceContainer {
            init(
                anyProcessor: any DataProcessor,
                someValidator: some Validator,
                erasedService: AnyService<String>
            ) {
                self.anyProcessor = anyProcessor
                self.someValidator = someValidator
                self.erasedService = erasedService
            }

            let anyProcessor: any DataProcessor
            let someValidator: some Validator
            let erasedService: AnyService<String>

            static func register(in container: Container) {
                container.register(ServiceContainer.self) { resolver in
                    ServiceContainer(
                        anyProcessor: resolver.synchronizedResolve((any DataProcessor).self)!,
                        someValidator: resolver.synchronizedResolve((some Validator).self)!,
                        erasedService: resolver.synchronizedResolve(AnyService<String>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension ServiceContainer: Injectable {
        }
        """, macros: testMacros)
    }

    func testInjectableWithMultipleGenericParameters() {
        assertMacroExpansion("""
        @Injectable
        class MultiGenericService<T, U, V, W> where T: Equatable, U: Hashable, V: Codable, W: CustomStringConvertible {
            init(
                tProcessor: Processor<T>,
                uCache: Cache<U>,
                vSerializer: Serializer<V>,
                wFormatter: Formatter<W>
            ) {
                self.tProcessor = tProcessor
                self.uCache = uCache
                self.vSerializer = vSerializer
                self.wFormatter = wFormatter
            }

            let tProcessor: Processor<T>
            let uCache: Cache<U>
            let vSerializer: Serializer<V>
            let wFormatter: Formatter<W>
        }
        """, expandedSource: """
        class MultiGenericService<T, U, V, W> where T: Equatable, U: Hashable, V: Codable, W: CustomStringConvertible {
            init(
                tProcessor: Processor<T>,
                uCache: Cache<U>,
                vSerializer: Serializer<V>,
                wFormatter: Formatter<W>
            ) {
                self.tProcessor = tProcessor
                self.uCache = uCache
                self.vSerializer = vSerializer
                self.wFormatter = wFormatter
            }

            let tProcessor: Processor<T>
            let uCache: Cache<U>
            let vSerializer: Serializer<V>
            let wFormatter: Formatter<W>

            static func register(in container: Container) {
                container.register(MultiGenericService.self) { resolver in
                    MultiGenericService(
                        tProcessor: resolver.synchronizedResolve(Processor<T>.self)!,
                        uCache: resolver.synchronizedResolve(Cache<U>.self)!,
                        vSerializer: resolver.synchronizedResolve(Serializer<V>.self)!,
                        wFormatter: resolver.synchronizedResolve(Formatter<W>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension MultiGenericService: Injectable {
        }
        """, macros: testMacros)
    }

    // MARK: - @LazyInject with Complex Generics

    func testLazyInjectWithGenericTypes() {
        assertMacroExpansion("""
        class GenericConsumer<T: Codable> {
            @LazyInject var repository: Repository<T>
            @LazyInject var cache: Cache<[T]>
            @LazyInject var processor: DataProcessor<T, String>
        }
        """, expandedSource: """
        class GenericConsumer<T: Codable> {
            @LazyInject var repository: Repository<T>
            @LazyInject var cache: Cache<[T]>
            @LazyInject var processor: DataProcessor<T, String>
            private var _repositoryBacking: Repository<T>?
            private var _repositoryOnceToken: Bool = false
            private let _repositoryOnceTokenLock = NSLock()

            private func _repositoryLazyAccessor() -> Repository<T> {
                // Thread-safe lazy initialization
                _repositoryOnceTokenLock.lock()
                defer { _repositoryOnceTokenLock.unlock() }

                if !_repositoryOnceToken {
                    _repositoryOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "repository",
                        propertyType: "Repository<T>",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(Repository<T>.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "Repository<T>")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "repository",
                                propertyType: "Repository<T>",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'repository' of type 'Repository<T>' could not be resolved: \\(error.localizedDescription)")
                        }

                        _repositoryBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "repository",
                            propertyType: "Repository<T>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "repository",
                            propertyType: "Repository<T>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        if true {
                            fatalError("Failed to resolve required lazy property 'repository': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _repositoryBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "repository", type: "Repository<T>")
                    fatalError("Lazy property 'repository' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
            private var _cacheBacking: Cache<[T]>?
            private var _cacheOnceToken: Bool = false
            private let _cacheOnceTokenLock = NSLock()

            private func _cacheLazyAccessor() -> Cache<[T]> {
                // Thread-safe lazy initialization
                _cacheOnceTokenLock.lock()
                defer { _cacheOnceTokenLock.unlock() }

                if !_cacheOnceToken {
                    _cacheOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "cache",
                        propertyType: "Cache<[T]>",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(Cache<[T]>.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "Cache<[T]>")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "cache",
                                propertyType: "Cache<[T]>",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'cache' of type 'Cache<[T]>' could not be resolved: \\(error.localizedDescription)")
                        }

                        _cacheBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "cache",
                            propertyType: "Cache<[T]>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "cache",
                            propertyType: "Cache<[T]>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        if true {
                            fatalError("Failed to resolve required lazy property 'cache': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _cacheBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "cache", type: "Cache<[T]>")
                    fatalError("Lazy property 'cache' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
            private var _processorBacking: DataProcessor<T, String>?
            private var _processorOnceToken: Bool = false
            private let _processorOnceTokenLock = NSLock()

            private func _processorLazyAccessor() -> DataProcessor<T, String> {
                // Thread-safe lazy initialization
                _processorOnceTokenLock.lock()
                defer { _processorOnceTokenLock.unlock() }

                if !_processorOnceToken {
                    _processorOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "processor",
                        propertyType: "DataProcessor<T, String>",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: true,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        guard let resolved = Container.shared.synchronizedResolve(DataProcessor<T, String>.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "DataProcessor<T, String>")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "processor",
                                propertyType: "DataProcessor<T, String>",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'processor' of type 'DataProcessor<T, String>' could not be resolved: \\(error.localizedDescription)")
                        }

                        _processorBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "processor",
                            propertyType: "DataProcessor<T, String>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .resolved,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "processor",
                            propertyType: "DataProcessor<T, String>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: true,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)

                        if true {
                            fatalError("Failed to resolve required lazy property 'processor': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _processorBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "processor", type: "DataProcessor<T, String>")
                    fatalError("Lazy property 'processor' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
        }
        """, macros: testMacros)
    }

    func testLazyInjectWithOptionalGenericTypes() {
        assertMacroExpansion("""
        class OptionalGenericConsumer<T: Equatable> {
            @LazyInject var optionalRepository: Repository<T>?
            @LazyInject var optionalCache: Cache<T?>?
        }
        """, expandedSource: """
        class OptionalGenericConsumer<T: Equatable> {
            @LazyInject var optionalRepository: Repository<T>?
            @LazyInject var optionalCache: Cache<T?>?
            private var _optionalRepositoryBacking: Repository<T>?
            private var _optionalRepositoryOnceToken: Bool = false
            private let _optionalRepositoryOnceTokenLock = NSLock()

            private func _optionalRepositoryLazyAccessor() -> Repository<T>? {
                // Thread-safe lazy initialization
                _optionalRepositoryOnceTokenLock.lock()
                defer { _optionalRepositoryOnceTokenLock.unlock() }

                if !_optionalRepositoryOnceToken {
                    _optionalRepositoryOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "optionalRepository",
                        propertyType: "Repository<T>",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: false,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        _optionalRepositoryBacking = Container.shared.synchronizedResolve(Repository<T>.self)

                        // Record resolution (successful or not)
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "optionalRepository",
                            propertyType: "Repository<T>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: false,
                            state: _optionalRepositoryBacking != nil ? .resolved : .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "optionalRepository",
                            propertyType: "Repository<T>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: false,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)
                    }
                }

                return _optionalRepositoryBacking
            }
            private var _optionalCacheBacking: Cache<T?>?
            private var _optionalCacheOnceToken: Bool = false
            private let _optionalCacheOnceTokenLock = NSLock()

            private func _optionalCacheLazyAccessor() -> Cache<T?>? {
                // Thread-safe lazy initialization
                _optionalCacheOnceTokenLock.lock()
                defer { _optionalCacheOnceTokenLock.unlock() }

                if !_optionalCacheOnceToken {
                    _optionalCacheOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "optionalCache",
                        propertyType: "Cache<T?>",
                        containerName: "default",
                        serviceName: nil,
                        isRequired: false,
                        state: .resolving,
                        resolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    LazyInjectionMetrics.recordResolution(pendingInfo)

                    do {
                        // Resolve dependency
                        _optionalCacheBacking = Container.shared.synchronizedResolve(Cache<T?>.self)

                        // Record resolution (successful or not)
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "optionalCache",
                            propertyType: "Cache<T?>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: false,
                            state: _optionalCacheBacking != nil ? .resolved : .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(resolvedInfo)

                    } catch {
                        // Record failed resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let failedInfo = LazyPropertyInfo(
                            propertyName: "optionalCache",
                            propertyType: "Cache<T?>",
                            containerName: "default",
                            serviceName: nil,
                            isRequired: false,
                            state: .failed,
                            resolutionTime: Date(),
                            resolutionDuration: resolutionDuration,
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordResolution(failedInfo)
                    }
                }

                return _optionalCacheBacking
            }
        }
        """, macros: testMacros)
    }

    // MARK: - @AutoFactory with Generics

    func testAutoFactoryWithGenericTypes() {
        assertMacroExpansion("""
        @AutoFactory
        class GenericServiceFactory<T: Codable> {
            init(repository: Repository<T>, validator: Validator<T>) {
                self.repository = repository
                self.validator = validator
            }

            let repository: Repository<T>
            let validator: Validator<T>
        }
        """, expandedSource: """
        class GenericServiceFactory<T: Codable> {
            init(repository: Repository<T>, validator: Validator<T>) {
                self.repository = repository
                self.validator = validator
            }

            let repository: Repository<T>
            let validator: Validator<T>

            static func register(in container: Container) {
                container.register(GenericServiceFactoryFactory.self) { resolver in
                    GenericServiceFactoryFactory {
                        GenericServiceFactory(
                            repository: resolver.synchronizedResolve(Repository<T>.self)!,
                            validator: resolver.synchronizedResolve(Validator<T>.self)!
                        )
                    }
                }
            }
        }

        extension GenericServiceFactory: AutoFactory {
        }

        protocol GenericServiceFactoryFactory {
            func create() -> GenericServiceFactory
        }

        struct GenericServiceFactoryFactoryImpl: GenericServiceFactoryFactory {
            private let factory: () -> GenericServiceFactory

            init(factory: @escaping () -> GenericServiceFactory) {
                self.factory = factory
            }

            func create() -> GenericServiceFactory {
                return factory()
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Edge Cases

    func testInjectableWithDeeplyNestedGenerics() {
        assertMacroExpansion("""
        @Injectable
        class DeeplyNestedService {
            init(
                complexProcessor: DataProcessor<Result<Optional<[User]>, NetworkError>, ValidationResult<UserData>>
            ) {
                self.complexProcessor = complexProcessor
            }

            let complexProcessor: DataProcessor<Result<Optional<[User]>, NetworkError>, ValidationResult<UserData>>
        }
        """, expandedSource: """
        class DeeplyNestedService {
            init(
                complexProcessor: DataProcessor<Result<Optional<[User]>, NetworkError>, ValidationResult<UserData>>
            ) {
                self.complexProcessor = complexProcessor
            }

            let complexProcessor: DataProcessor<Result<Optional<[User]>, NetworkError>, ValidationResult<UserData>>

            static func register(in container: Container) {
                container.register(DeeplyNestedService.self) { resolver in
                    DeeplyNestedService(
                        complexProcessor: resolver.synchronizedResolve(DataProcessor<Result<Optional<[User]>, NetworkError>, ValidationResult<UserData>>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension DeeplyNestedService: Injectable {
        }
        """, macros: testMacros)
    }

    func testGenericTypeWithCircularDependency() {
        assertMacroExpansion("""
        @Injectable
        class CircularGenericService<T> {
            init(recursiveService: CircularGenericService<T>) {
                self.recursiveService = recursiveService
            }

            let recursiveService: CircularGenericService<T>
        }
        """, expandedSource: """
        class CircularGenericService<T> {
            init(recursiveService: CircularGenericService<T>) {
                self.recursiveService = recursiveService
            }

            let recursiveService: CircularGenericService<T>

            static func register(in container: Container) {
                container.register(CircularGenericService.self) { resolver in
                    CircularGenericService(
                        recursiveService: resolver.synchronizedResolve(CircularGenericService<T>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension CircularGenericService: Injectable {
        }
        """, diagnostics: [
            DiagnosticSpec(message: """
            Potential circular dependency detected in CircularGenericService.

            ⚠️  Problem: CircularGenericService depends on itself, which can cause infinite recursion.

            💡 Solutions:
            1. Break the cycle by introducing an abstraction/protocol
            2. Use lazy injection: @LazyInject instead of direct dependency
            3. Consider if the dependency is really needed

            Example fix:
            // Before (circular):
            class UserService {
                init(userService: UserService) { ... } // ❌ Self-dependency
            }

            // After (using protocol):
            protocol UserServiceProtocol { ... }
            class UserService: UserServiceProtocol {
                init(validator: UserValidatorProtocol) { ... } // ✅ External dependency
            }
            """, line: 3, column: 5, severity: .warning)
        ], macros: testMacros)
    }

    // MARK: - Test Utilities

    private let testMacros: [String: Macro.Type] = [
        "Injectable": InjectableMacro.self,
        "LazyInject": LazyInjectMacro.self,
        "AutoFactory": AutoFactoryMacro.self
    ]
}

// MARK: - Supporting Generic Test Types

// Generic types for testing
class Database<T> {
    init() {}
}

// Cache and Repository are imported from TestUtilities.swift

class ResultProcessor<T> {
    init() {}
}

class EventPublisher<T> {
    init() {}
}

class Serializer<T> {
    init() {}
}

// Processor is imported from TestUtilities.swift

class Formatter<T> {
    init() {}
}

class ComplexValidator<T> {
    init() {}
}

class AnyService<T> {
    init() {}
}

// Test data types
struct GenericTestUser {
    let id: String
    let name: String
}

struct GenericTestUserData {
    let user: GenericTestUser
    let metadata: [String: Any]
}

struct ProcessingError: Error {
    let message: String
}

struct ComplexNetworkError: Error {
    let code: Int
}

// ValidationResult is imported from TestUtilities.swift

struct DataProcessingEvent<T> {
    let eventType: String
    let data: T
    let timestamp: Date
}

// Protocols for testing
protocol DataProviderProtocolProtocol {
    associatedtype DataType
    func provide() -> DataType
}

protocol ComplexDataProcessor {
    associatedtype Input
    associatedtype Output
    func process(_ input: Input) -> Output
}

protocol ComplexValidatorProtocol {
    associatedtype ValidationType
    func validate(_ item: ValidationType) -> Bool
}
