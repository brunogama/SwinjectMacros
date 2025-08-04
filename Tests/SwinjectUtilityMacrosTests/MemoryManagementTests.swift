// MemoryManagementTests.swift - Memory management and lifecycle edge case tests

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import SwinjectUtilityMacrosImplementation

final class MemoryManagementTests: XCTestCase {

    // MARK: - Memory Cycle Detection Tests

    func testWeakInjectWithPotentialCycle() {
        assertMacroExpansion("""
        class MemoryParent {
            @WeakInject var child: MemoryChild?
        }

        class MemoryChild {
            @LazyInject var parent: MemoryParent
        }
        """, expandedSource: """
        class MemoryParent {
            @WeakInject var child: MemoryChild?
            private weak var _childWeakBacking: MemoryChild?
            private var _childOnceToken: Bool = false
            private let _childOnceTokenLock = NSLock()

            private func _childWeakAccessor() -> MemoryChild? {
                func resolveWeakReference() {
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = WeakPropertyInfo(
                        propertyName: "child",
                        propertyType: "MemoryChild",
                        containerName: "default",
                        serviceName: nil,
                        autoResolve: true,
                        state: .pending,
                        initialResolutionTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    WeakInjectionMetrics.recordAccess(pendingInfo)

                    do {
                        // Resolve dependency as weak reference
                        if let resolved = Container.shared.synchronizedResolve(MemoryChild.self) {
                            _childWeakBacking = resolved

                            // Record successful resolution
                            let resolvedInfo = WeakPropertyInfo(
                                propertyName: "child",
                                propertyType: "MemoryChild",
                                containerName: "default",
                                serviceName: nil,
                                autoResolve: true,
                                state: .resolved,
                                initialResolutionTime: Date(),
                                lastAccessTime: Date(),
                                resolutionCount: 1,
                                threadInfo: ThreadInfo()
                            )
                            WeakInjectionMetrics.recordAccess(resolvedInfo)
                        } else {
                            // Service not found - record failure
                            let error = WeakInjectionError.serviceNotRegistered(serviceName: nil, type: "MemoryChild")

                            let failedInfo = WeakPropertyInfo(
                                propertyName: "child",
                                propertyType: "MemoryChild",
                                containerName: "default",
                                serviceName: nil,
                                autoResolve: true,
                                state: .failed,
                                initialResolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            WeakInjectionMetrics.recordAccess(failedInfo)
                        }
                    } catch {
                        // Record failed resolution
                        let failedInfo = WeakPropertyInfo(
                            propertyName: "child",
                            propertyType: "MemoryChild",
                            containerName: "default",
                            serviceName: nil,
                            autoResolve: true,
                            state: .failed,
                            initialResolutionTime: Date(),
                            resolutionError: error,
                            threadInfo: ThreadInfo()
                        )
                        WeakInjectionMetrics.recordAccess(failedInfo)
                    }
                }

                // Auto-resolve if reference is nil and auto-resolve is enabled
                if _childWeakBacking == nil {
                    _childOnceTokenLock.lock()
                    if !_childOnceToken {
                        _childOnceToken = true
                        _childOnceTokenLock.unlock()
                        resolveWeakReference()
                    } else {
                        _childOnceTokenLock.unlock()
                    }
                }

                // Check if reference was deallocated and record deallocation
                if _childWeakBacking == nil {
                    let deallocatedInfo = WeakPropertyInfo(
                        propertyName: "child",
                        propertyType: "MemoryChild",
                        containerName: "default",
                        serviceName: nil,
                        autoResolve: true,
                        state: .deallocated,
                        lastAccessTime: Date(),
                        deallocationTime: Date(),
                        threadInfo: ThreadInfo()
                    )
                    WeakInjectionMetrics.recordAccess(deallocatedInfo)
                }

                return _childWeakBacking
            }
        }

        class MemoryChild {
            @LazyInject var parent: MemoryParent
            private var _parentBacking: MemoryParent?
            private var _parentOnceToken: Bool = false
            private let _parentOnceTokenLock = NSLock()

            private func _parentLazyAccessor() -> MemoryParent {
                // Thread-safe lazy initialization
                _parentOnceTokenLock.lock()
                defer { _parentOnceTokenLock.unlock() }

                if !_parentOnceToken {
                    _parentOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "parent",
                        propertyType: "MemoryParent",
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
                        guard let resolved = Container.shared.synchronizedResolve(MemoryParent.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "MemoryParent")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "parent",
                                propertyType: "MemoryParent",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'parent' of type 'MemoryParent' could not be resolved: \\(error.localizedDescription)")
                        }

                        _parentBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "parent",
                            propertyType: "MemoryParent",
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
                            propertyName: "parent",
                            propertyType: "MemoryParent",
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
                            fatalError("Failed to resolve required lazy property 'parent': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _parentBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "parent", type: "MemoryParent")
                    fatalError("Lazy property 'parent' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
        }
        """, macros: testMacros)
    }

    func testDeinitWithLazyInject() {
        assertMacroExpansion("""
        class ServiceWithDeinit {
            @LazyInject var dependency: DependencyService

            deinit {
                print("ServiceWithDeinit is being deallocated")
                // Note: Accessing lazy property during deinit could be problematic
            }
        }
        """, expandedSource: """
        class ServiceWithDeinit {
            @LazyInject var dependency: DependencyService

            deinit {
                print("ServiceWithDeinit is being deallocated")
                // Note: Accessing lazy property during deinit could be problematic
            }
            private var _dependencyBacking: DependencyService?
            private var _dependencyOnceToken: Bool = false
            private let _dependencyOnceTokenLock = NSLock()

            private func _dependencyLazyAccessor() -> DependencyService {
                // Thread-safe lazy initialization
                _dependencyOnceTokenLock.lock()
                defer { _dependencyOnceTokenLock.unlock() }

                if !_dependencyOnceToken {
                    _dependencyOnceToken = true
                    let startTime = CFAbsoluteTimeGetCurrent()

                    // Register property for metrics tracking
                    let pendingInfo = LazyPropertyInfo(
                        propertyName: "dependency",
                        propertyType: "DependencyService",
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
                        guard let resolved = Container.shared.synchronizedResolve(DependencyService.self) else {
                            let error = LazyInjectionError.serviceNotRegistered(serviceName: nil, type: "DependencyService")

                            // Record failed resolution
                            let failedInfo = LazyPropertyInfo(
                                propertyName: "dependency",
                                propertyType: "DependencyService",
                                containerName: "default",
                                serviceName: nil,
                                isRequired: true,
                                state: .failed,
                                resolutionTime: Date(),
                                resolutionError: error,
                                threadInfo: ThreadInfo()
                            )
                            LazyInjectionMetrics.recordResolution(failedInfo)

                            fatalError("Required lazy property 'dependency' of type 'DependencyService' could not be resolved: \\(error.localizedDescription)")
                        }

                        _dependencyBacking = resolved

                        // Record successful resolution
                        let endTime = CFAbsoluteTimeGetCurrent()
                        let resolutionDuration = endTime - startTime

                        let resolvedInfo = LazyPropertyInfo(
                            propertyName: "dependency",
                            propertyType: "DependencyService",
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
                            propertyName: "dependency",
                            propertyType: "DependencyService",
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
                            fatalError("Failed to resolve required lazy property 'dependency': \\(error.localizedDescription)")
                        }
                    }
                }

                guard let resolvedValue = _dependencyBacking else {
                    let error = LazyInjectionError.requiredServiceUnavailable(propertyName: "dependency", type: "DependencyService")
                    fatalError("Lazy property 'dependency' could not be resolved: \\(error.localizedDescription)")
                }
                return resolvedValue
            }
        }
        """, macros: testMacros)
    }

    // MARK: - Test Utilities

    private let testMacros: [String: Macro.Type] = [
        "LazyInject": LazyInjectMacro.self,
        "WeakInject": WeakInjectMacro.self
    ]
}

// MARK: - Supporting Memory Test Types

class MemoryParent {
    init() {}
}

class MemoryChild {
    init() {}
}

class DependencyService {
    init() {}
}
