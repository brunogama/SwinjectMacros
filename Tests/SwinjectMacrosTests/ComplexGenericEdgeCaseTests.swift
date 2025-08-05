// ComplexGenericEdgeCaseTests.swift - Tests for complex generic scenarios and edge cases
// Copyright © 2025 SwinJectMacros. All rights reserved.

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import SwinjectMacrosImplementation
import XCTest

final class ComplexGenericEdgeCaseTests: XCTestCase {

    let testMacros: [String: Macro.Type] = [
        "Injectable": InjectableMacro.self,
        "AutoFactory": AutoFactoryMacro.self,
        "LazyInject": LazyInjectMacro.self,
        "WeakInject": WeakInjectMacro.self
    ]

    // MARK: - Nested Generic Types

    func testInjectableWithNestedGenerics() {
        assertMacroExpansion("""
        @Injectable
        class NestedGenericService<T, U> where T: Codable, U: Hashable {
            let processor: DataProcessor<Result<T, Error>, [U]>
            let validator: Validator<Optional<T>>
            let repository: Repository<[T: U]>

            init(processor: DataProcessor<Result<T, Error>, [U]>,
                 validator: Validator<Optional<T>>,
                 repository: Repository<[T: U]>) {
                self.processor = processor
                self.validator = validator
                self.repository = repository
            }
        }
        """, expandedSource: """
        class NestedGenericService<T, U> where T: Codable, U: Hashable {
            let processor: DataProcessor<Result<T, Error>, [U]>
            let validator: Validator<Optional<T>>
            let repository: Repository<[T: U]>

            init(processor: DataProcessor<Result<T, Error>, [U]>,
                 validator: Validator<Optional<T>>,
                 repository: Repository<[T: U]>) {
                self.processor = processor
                self.validator = validator
                self.repository = repository
            }

            static func register(in container: Container) {
                container.register(NestedGenericService.self) { resolver in
                    NestedGenericService(
                        processor: resolver.resolve(DataProcessor<Result<T, Error>, [U]>.self)!,
                        validator: resolver.resolve(Validator<Optional<T>>.self)!,
                        repository: resolver.resolve(Repository<[T: U]>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension NestedGenericService: Injectable {
        }
        """, macros: testMacros)
    }

    func testAutoFactoryWithGenericConstraints() {
        assertMacroExpansion("""
        @AutoFactory
        class GenericFactoryService<T: Codable & Sendable, U> where U: Collection, U.Element == T {
            let repository: Repository<T>
            let data: U
            let processor: DataProcessor<T, U.Element>

            init(repository: Repository<T>, data: U, processor: DataProcessor<T, U.Element>) {
                self.repository = repository
                self.data = data
                self.processor = processor
            }
        }
        """, expandedSource: """
        class GenericFactoryService<T: Codable & Sendable, U> where U: Collection, U.Element == T {
            let repository: Repository<T>
            let data: U
            let processor: DataProcessor<T, U.Element>

            init(repository: Repository<T>, data: U, processor: DataProcessor<T, U.Element>) {
                self.repository = repository
                self.data = data
                self.processor = processor
            }
        }

        protocol GenericFactoryServiceFactory {
            func makeGenericFactoryService<T: Codable & Sendable, U>(data: U, processor: DataProcessor<T, U.Element>) -> GenericFactoryService<T, U> where U: Collection, U.Element == T
        }

        class GenericFactoryServiceFactoryImpl: GenericFactoryServiceFactory, BaseFactory {
            let resolver: Resolver

            init(resolver: Resolver) {
                self.resolver = resolver
            }

            func makeGenericFactoryService<T: Codable & Sendable, U>(data: U, processor: DataProcessor<T, U.Element>) -> GenericFactoryService<T, U> where U: Collection, U.Element == T {
                GenericFactoryService(
                    repository: resolver.resolve(Repository<T>.self)!,
                    data: data,
                    processor: processor
                )
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Associated Types and Protocols

    func testInjectableWithAssociatedTypes() {
        assertMacroExpansion("""
        @Injectable
        class AssociatedTypeService<P: DataProviderProtocol> {
            let provider: P
            let transformer: DataTransformer<P.InputType, P.OutputType>
            let validator: Validator<P.ValidationContext>

            init(provider: P,
                 transformer: DataTransformer<P.InputType, P.OutputType>,
                 validator: Validator<P.ValidationContext>) {
                self.provider = provider
                self.transformer = transformer
                self.validator = validator
            }
        }
        """, expandedSource: """
        class AssociatedTypeService<P: DataProviderProtocol> {
            let provider: P
            let transformer: DataTransformer<P.InputType, P.OutputType>
            let validator: Validator<P.ValidationContext>

            init(provider: P,
                 transformer: DataTransformer<P.InputType, P.OutputType>,
                 validator: Validator<P.ValidationContext>) {
                self.provider = provider
                self.transformer = transformer
                self.validator = validator
            }

            static func register(in container: Container) {
                container.register(AssociatedTypeService.self) { resolver in
                    AssociatedTypeService(
                        provider: resolver.resolve(P.self)!,
                        transformer: resolver.resolve(DataTransformer<P.InputType, P.OutputType>.self)!,
                        validator: resolver.resolve(Validator<P.ValidationContext>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension AssociatedTypeService: Injectable {
        }
        """, macros: testMacros)
    }

    // MARK: - Higher-Order Generic Types

    func testInjectableWithHigherOrderGenerics() {
        assertMacroExpansion("""
        @Injectable
        class HigherOrderGenericService<Container: ContainerProtocol, Processor: ProcessorProtocol>
        where Container.Element: Codable,
              Processor.Input == Container.Element,
              Processor.Output: Hashable {

            let container: Container
            let processor: Processor
            let cache: Cache<Processor.Input, Set<Processor.Output>>

            init(container: Container,
                 processor: Processor,
                 cache: Cache<Processor.Input, Set<Processor.Output>>) {
                self.container = container
                self.processor = processor
                self.cache = cache
            }
        }
        """, expandedSource: """
        class HigherOrderGenericService<Container: ContainerProtocol, Processor: ProcessorProtocol>
        where Container.Element: Codable,
              Processor.Input == Container.Element,
              Processor.Output: Hashable {

            let container: Container
            let processor: Processor
            let cache: Cache<Processor.Input, Set<Processor.Output>>

            init(container: Container,
                 processor: Processor,
                 cache: Cache<Processor.Input, Set<Processor.Output>>) {
                self.container = container
                self.processor = processor
                self.cache = cache
            }

            static func register(in container: Container) {
                container.register(HigherOrderGenericService.self) { resolver in
                    HigherOrderGenericService(
                        container: resolver.resolve(Container.self)!,
                        processor: resolver.resolve(Processor.self)!,
                        cache: resolver.resolve(Cache<Processor.Input, Set<Processor.Output>>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension HigherOrderGenericService: Injectable {
        }
        """, macros: testMacros)
    }

    // MARK: - Generic Function Types

    func testInjectableWithGenericFunctionTypes() {
        assertMacroExpansion("""
        @Injectable
        class FunctionTypeService<T, U, V> {
            let transformer: (T) -> U
            let validator: (T, U) throws -> Bool
            let asyncProcessor: (T) async throws -> V
            let genericCallback: <W>(W, T) -> (U, W)

            init(transformer: @escaping (T) -> U,
                 validator: @escaping (T, U) throws -> Bool,
                 asyncProcessor: @escaping (T) async throws -> V,
                 genericCallback: @escaping <W>(W, T) -> (U, W)) {
                self.transformer = transformer
                self.validator = validator
                self.asyncProcessor = asyncProcessor
                self.genericCallback = genericCallback
            }
        }
        """, expandedSource: """
        class FunctionTypeService<T, U, V> {
            let transformer: (T) -> U
            let validator: (T, U) throws -> Bool
            let asyncProcessor: (T) async throws -> V
            let genericCallback: <W>(W, T) -> (U, W)

            init(transformer: @escaping (T) -> U,
                 validator: @escaping (T, U) throws -> Bool,
                 asyncProcessor: @escaping (T) async throws -> V,
                 genericCallback: @escaping <W>(W, T) -> (U, W)) {
                self.transformer = transformer
                self.validator = validator
                self.asyncProcessor = asyncProcessor
                self.genericCallback = genericCallback
            }

            static func register(in container: Container) {
                container.register(FunctionTypeService.self) { resolver in
                    FunctionTypeService(
                        transformer: resolver.resolve(((T) -> U).self)!,
                        validator: resolver.resolve(((T, U) throws -> Bool).self)!,
                        asyncProcessor: resolver.resolve(((T) async throws -> V).self)!,
                        genericCallback: resolver.resolve((<W>(W, T) -> (U, W)).self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension FunctionTypeService: Injectable {
        }
        """, macros: testMacros)
    }

    // MARK: - Recursive Generic Types

    func testInjectableWithRecursiveGenerics() {
        assertMacroExpansion("""
        @Injectable
        class RecursiveGenericService<T> {
            let tree: Tree<TreeNode<T>>
            let processor: Processor<RecursiveData<T, RecursiveData<T, T>>>
            let validator: Validator<[T: [T: T]]>

            init(tree: Tree<TreeNode<T>>,
                 processor: Processor<RecursiveData<T, RecursiveData<T, T>>>,
                 validator: Validator<[T: [T: T]]>) where T: Hashable {
                self.tree = tree
                self.processor = processor
                self.validator = validator
            }
        }
        """, expandedSource: """
        class RecursiveGenericService<T> {
            let tree: Tree<TreeNode<T>>
            let processor: Processor<RecursiveData<T, RecursiveData<T, T>>>
            let validator: Validator<[T: [T: T]]>

            init(tree: Tree<TreeNode<T>>,
                 processor: Processor<RecursiveData<T, RecursiveData<T, T>>>,
                 validator: Validator<[T: [T: T]]>) where T: Hashable {
                self.tree = tree
                self.processor = processor
                self.validator = validator
            }

            static func register(in container: Container) {
                container.register(RecursiveGenericService.self) { resolver in
                    RecursiveGenericService(
                        tree: resolver.resolve(Tree<TreeNode<T>>.self)!,
                        processor: resolver.resolve(Processor<RecursiveData<T, RecursiveData<T, T>>>.self)!,
                        validator: resolver.resolve(Validator<[T: [T: T]]>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension RecursiveGenericService: Injectable {
        }
        """, macros: testMacros)
    }

    // MARK: - Existential Types

    func testInjectableWithExistentialTypes() {
        assertMacroExpansion("""
        @Injectable
        class ExistentialTypeService {
            let anyProcessor: any ProcessorProtocol
            let someValidator: some ValidatorProtocol
            let arrayOfAny: [any DataProviderProtocol]
            let optionalSome: (some CacheProtocol)?

            init(anyProcessor: any ProcessorProtocol,
                 someValidator: some ValidatorProtocol,
                 arrayOfAny: [any DataProviderProtocol],
                 optionalSome: (some CacheProtocol)?) {
                self.anyProcessor = anyProcessor
                self.someValidator = someValidator
                self.arrayOfAny = arrayOfAny
                self.optionalSome = optionalSome
            }
        }
        """, expandedSource: """
        class ExistentialTypeService {
            let anyProcessor: any ProcessorProtocol
            let someValidator: some ValidatorProtocol
            let arrayOfAny: [any DataProviderProtocol]
            let optionalSome: (some CacheProtocol)?

            init(anyProcessor: any ProcessorProtocol,
                 someValidator: some ValidatorProtocol,
                 arrayOfAny: [any DataProviderProtocol],
                 optionalSome: (some CacheProtocol)?) {
                self.anyProcessor = anyProcessor
                self.someValidator = someValidator
                self.arrayOfAny = arrayOfAny
                self.optionalSome = optionalSome
            }

            static func register(in container: Container) {
                container.register(ExistentialTypeService.self) { resolver in
                    ExistentialTypeService(
                        anyProcessor: resolver.resolve((any ProcessorProtocol).self)!,
                        someValidator: resolver.resolve((some ValidatorProtocol).self)!,
                        arrayOfAny: resolver.resolve([any DataProviderProtocol].self)!,
                        optionalSome: resolver.resolve(((some CacheProtocol)?).self)
                    )
                }.inObjectScope(.graph)
            }
        }

        extension ExistentialTypeService: Injectable {
        }
        """, macros: testMacros)
    }

    // MARK: - LazyInject with Complex Generics

    func testLazyInjectWithComplexGenerics() {
        assertMacroExpansion("""
        class ComplexGenericLazyService<T: Codable & Sendable> {
            @LazyInject var processor: DataProcessor<Result<T, NetworkError>, [ValidationResult<T>]>
            @LazyInject var cache: Cache<CacheKey<T>, CachedValue<Result<T, Error>>>?
            @LazyInject("custom") var customProvider: DataProvider<T, [T: ValidationContext<T>]>
        }
        """, expandedSource: """
        class ComplexGenericLazyService<T: Codable & Sendable> {
            @LazyInject var processor: DataProcessor<Result<T, NetworkError>, [ValidationResult<T>]>
            @LazyInject var cache: Cache<CacheKey<T>, CachedValue<Result<T, Error>>>?
            @LazyInject("custom") var customProvider: DataProvider<T, [T: ValidationContext<T>]>

            private var _processorBacking: DataProcessor<Result<T, NetworkError>, [ValidationResult<T>]>?
            private var _processorOnceToken: Bool = false
            private let _processorOnceTokenLock = NSLock()

            var processor: DataProcessor<Result<T, NetworkError>, [ValidationResult<T>]> {
                get {
                    _processorOnceTokenLock.lock()
                    if !_processorOnceToken {
                        _processorOnceToken = true
                        _processorOnceTokenLock.unlock()

                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "processor",
                            propertyType: "DataProcessor<Result<T, NetworkError>, [ValidationResult<T>]>",
                            containerName: "default",
                            serviceName: nil,
                            isOptional: false,
                            state: .pending,
                            initialResolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordAccess(pendingInfo)

                        do {
                            _processorBacking = Container.shared.resolve(DataProcessor<Result<T, NetworkError>, [ValidationResult<T>]>.self)

                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "processor",
                                propertyType: "DataProcessor<Result<T, NetworkError>, [ValidationResult<T>]>",
                                containerName: "default",
                                serviceName: nil,
                                isOptional: false,
                                state: _processorBacking != nil ? .resolved : .failed,
                                initialResolutionTime: Date(),
                                lastAccessTime: Date(),
                                resolutionCount: 1,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(resolvedInfo)
                        } catch {
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "processor",
                                propertyType: "DataProcessor<Result<T, NetworkError>, [ValidationResult<T>]>",
                                containerName: "default",
                                serviceName: nil,
                                isOptional: false,
                                state: .failed,
                                initialResolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(failedInfo)
                        }
                    } else {
                        _processorOnceTokenLock.unlock()
                    }

                    return _processorBacking!
                }
                set {
                    _processorOnceTokenLock.lock()
                    _processorBacking = newValue
                    _processorOnceToken = true
                    _processorOnceTokenLock.unlock()
                }
            }

            private var _cacheBacking: Cache<CacheKey<T>, CachedValue<Result<T, Error>>>?
            private var _cacheOnceToken: Bool = false
            private let _cacheOnceTokenLock = NSLock()

            var cache: Cache<CacheKey<T>, CachedValue<Result<T, Error>>>? {
                get {
                    _cacheOnceTokenLock.lock()
                    if !_cacheOnceToken {
                        _cacheOnceToken = true
                        _cacheOnceTokenLock.unlock()

                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "cache",
                            propertyType: "Cache<CacheKey<T>, CachedValue<Result<T, Error>>>",
                            containerName: "default",
                            serviceName: nil,
                            isOptional: true,
                            state: .pending,
                            initialResolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordAccess(pendingInfo)

                        do {
                            _cacheBacking = Container.shared.resolve(Cache<CacheKey<T>, CachedValue<Result<T, Error>>>.self)

                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "cache",
                                propertyType: "Cache<CacheKey<T>, CachedValue<Result<T, Error>>>",
                                containerName: "default",
                                serviceName: nil,
                                isOptional: true,
                                state: _cacheBacking != nil ? .resolved : .failed,
                                initialResolutionTime: Date(),
                                lastAccessTime: Date(),
                                resolutionCount: 1,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(resolvedInfo)
                        } catch {
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "cache",
                                propertyType: "Cache<CacheKey<T>, CachedValue<Result<T, Error>>>",
                                containerName: "default",
                                serviceName: nil,
                                isOptional: true,
                                state: .failed,
                                initialResolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(failedInfo)
                        }
                    } else {
                        _cacheOnceTokenLock.unlock()
                    }

                    return _cacheBacking
                }
                set {
                    _cacheOnceTokenLock.lock()
                    _cacheBacking = newValue
                    _cacheOnceToken = true
                    _cacheOnceTokenLock.unlock()
                }
            }

            private var _customProviderBacking: DataProvider<T, [T: ValidationContext<T>]>?
            private var _customProviderOnceToken: Bool = false
            private let _customProviderOnceTokenLock = NSLock()

            var customProvider: DataProvider<T, [T: ValidationContext<T>]> {
                get {
                    _customProviderOnceTokenLock.lock()
                    if !_customProviderOnceToken {
                        _customProviderOnceToken = true
                        _customProviderOnceTokenLock.unlock()

                        let pendingInfo = LazyPropertyInfo(
                            propertyName: "customProvider",
                            propertyType: "DataProvider<T, [T: ValidationContext<T>]>",
                            containerName: "default",
                            serviceName: "custom",
                            isOptional: false,
                            state: .pending,
                            initialResolutionTime: Date(),
                            threadInfo: ThreadInfo()
                        )
                        LazyInjectionMetrics.recordAccess(pendingInfo)

                        do {
                            _customProviderBacking = Container.shared.resolve(DataProvider<T, [T: ValidationContext<T>]>.self, name: "custom")

                            let resolvedInfo = LazyPropertyInfo(
                                propertyName: "customProvider",
                                propertyType: "DataProvider<T, [T: ValidationContext<T>]>",
                                containerName: "default",
                                serviceName: "custom",
                                isOptional: false,
                                state: _customProviderBacking != nil ? .resolved : .failed,
                                initialResolutionTime: Date(),
                                lastAccessTime: Date(),
                                resolutionCount: 1,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(resolvedInfo)
                        } catch {
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "customProvider",
                                propertyType: "DataProvider<T, [T: ValidationContext<T>]>",
                                containerName: "default",
                                serviceName: "custom",
                                isOptional: false,
                                state: .failed,
                                initialResolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordAccess(failedInfo)
                        }
                    } else {
                        _customProviderOnceTokenLock.unlock()
                    }

                    return _customProviderBacking!
                }
                set {
                    _customProviderOnceTokenLock.lock()
                    _customProviderBacking = newValue
                    _customProviderOnceToken = true
                    _customProviderOnceTokenLock.unlock()
                }
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Edge Cases with Generic Constraints

    func testGenericWithSelfRequirement() {
        assertMacroExpansion("""
        @Injectable
        class SelfRequirementService<T> where T: SelfProtocol, T.AssociatedType == T {
            let processor: Processor<T, T.AssociatedType>
            let validator: Validator<T> where T.AssociatedType: Codable

            init(processor: Processor<T, T.AssociatedType>, validator: Validator<T>) {
                self.processor = processor
                self.validator = validator
            }
        }
        """, expandedSource: """
        class SelfRequirementService<T> where T: SelfProtocol, T.AssociatedType == T {
            let processor: Processor<T, T.AssociatedType>
            let validator: Validator<T> where T.AssociatedType: Codable

            init(processor: Processor<T, T.AssociatedType>, validator: Validator<T>) {
                self.processor = processor
                self.validator = validator
            }

            static func register(in container: Container) {
                container.register(SelfRequirementService.self) { resolver in
                    SelfRequirementService(
                        processor: resolver.resolve(Processor<T, T.AssociatedType>.self)!,
                        validator: resolver.resolve(Validator<T>.self)!
                    )
                }.inObjectScope(.graph)
            }
        }

        extension SelfRequirementService: Injectable {
        }
        """, macros: testMacros)
    }
}

// MARK: - Test Support Generic Types

protocol DataProviderProtocol {
    associatedtype InputType
    associatedtype OutputType
    associatedtype ValidationContext
}

protocol ProcessorProtocol {
    associatedtype Input
    associatedtype Output
}

protocol ValidatorProtocol {
    associatedtype ValidationTarget
}

protocol CacheProtocol {
    associatedtype Key
    associatedtype Value
}

protocol ContainerProtocol {
    associatedtype Element
}

protocol SelfProtocol {
    associatedtype AssociatedType
}

// All mock types are now imported from TestUtilities.swift
