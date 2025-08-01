// InterceptorMacroTests.swift - Tests for @Interceptor macro
// Copyright © 2025 SwinJectMacros. All rights reserved.

import XCTest
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

final class InterceptorMacroTests: XCTestCase {
    
    // MARK: - Test Utilities
    
    let testMacros: [String: Macro.Type] = [
        "Interceptor": InterceptorMacro.self
    ]
    
    // MARK: - Basic Functionality Tests
    
    func testBasicInterceptorExpansion() {
        assertMacroExpansion(
            """
            @Interceptor(before: ["LoggingInterceptor"])
            func processPayment(amount: Double, cardToken: String) -> PaymentResult {
                return PaymentProcessor.process(amount: amount, token: cardToken)
            }
            """,
            expandedSource: """
            func processPayment(amount: Double, cardToken: String) -> PaymentResult {
                return PaymentProcessor.process(amount: amount, token: cardToken)
            }
            
            public func processPaymentIntercepted(amount: Double, cardToken: String) -> PaymentResult {
                let startTime = CFAbsoluteTimeGetCurrent()
                let context = InterceptorContext(
                    methodName: "processPayment",
                    typeName: String(describing: type(of: self)),
                    parameters: ["amount": amount, "cardToken": cardToken],
                    parameterTypes: ["amount": Double.self, "cardToken": String.self],
                    isAsync: false,
                    canThrow: false,
                    returnType: PaymentResult.self,
                    startTime: startTime
                )
                
                do {
                    // Execute before interceptors
                    if let interceptor = InterceptorRegistry.get(name: "LoggingInterceptor") {
                        try interceptor.before(context: context)
                    }
                    
                    // Execute original method
                    let result = processPayment(amount: amount, cardToken: cardToken)
                    
                    // No after interceptors
                    
                    return result
                } catch {
                    // No error interceptors - re-throw
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testInterceptorWithBeforeAfterHooks() {
        assertMacroExpansion(
            """
            @Interceptor(
                before: ["ValidationInterceptor", "LoggingInterceptor"],
                after: ["AuditInterceptor", "NotificationInterceptor"]
            )
            func createUser(userData: UserData) throws -> User {
                return try UserService.create(userData)
            }
            """,
            expandedSource: """
            func createUser(userData: UserData) throws -> User {
                return try UserService.create(userData)
            }
            
            public func createUserIntercepted(userData: UserData) throws -> User {
                let startTime = CFAbsoluteTimeGetCurrent()
                let context = InterceptorContext(
                    methodName: "createUser",
                    typeName: String(describing: type(of: self)),
                    parameters: ["userData": userData],
                    parameterTypes: ["userData": UserData.self],
                    isAsync: false,
                    canThrow: true,
                    returnType: User.self,
                    startTime: startTime
                )
                
                do {
                    // Execute before interceptors
                    if let interceptor = InterceptorRegistry.get(name: "ValidationInterceptor") {
                        try interceptor.before(context: context)
                    }
                    if let interceptor = InterceptorRegistry.get(name: "LoggingInterceptor") {
                        try interceptor.before(context: context)
                    }
                    
                    // Execute original method
                    let result = try createUser(userData: userData)
                    
                    // Execute after interceptors
                    if let interceptor = InterceptorRegistry.get(name: "NotificationInterceptor") {
                        try interceptor.after(context: context, result: result)
                    }
                    if let interceptor = InterceptorRegistry.get(name: "AuditInterceptor") {
                        try interceptor.after(context: context, result: result)
                    }
                    
                    return result
                } catch {
                    // No error interceptors - re-throw
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testInterceptorWithErrorHandling() {
        assertMacroExpansion(
            """
            @Interceptor(
                before: ["ValidationInterceptor"],
                onError: ["ErrorHandlingInterceptor", "AlertingInterceptor"]
            )
            func deleteUser(userId: String) throws {
                try UserService.delete(userId)
            }
            """,
            expandedSource: """
            func deleteUser(userId: String) throws {
                try UserService.delete(userId)
            }
            
            public func deleteUserIntercepted(userId: String) throws {
                let startTime = CFAbsoluteTimeGetCurrent()
                let context = InterceptorContext(
                    methodName: "deleteUser",
                    typeName: String(describing: type(of: self)),
                    parameters: ["userId": userId],
                    parameterTypes: ["userId": String.self],
                    isAsync: false,
                    canThrow: true,
                    returnType: Void.self,
                    startTime: startTime
                )
                
                do {
                    // Execute before interceptors
                    if let interceptor = InterceptorRegistry.get(name: "ValidationInterceptor") {
                        try interceptor.before(context: context)
                    }
                    
                    // Execute original method
                    try deleteUser(userId: userId)
                    
                    // No after interceptors
                    
                } catch {
                    // Execute error interceptors
                    if let interceptor = InterceptorRegistry.get(name: "ErrorHandlingInterceptor") {
                        try interceptor.onError(context: context, error: error)
                    }
                    if let interceptor = InterceptorRegistry.get(name: "AlertingInterceptor") {
                        try interceptor.onError(context: context, error: error)
                    }
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testAsyncInterceptor() {
        assertMacroExpansion(
            """
            @Interceptor(before: ["SecurityInterceptor"])
            func fetchUserData(userId: String) async throws -> UserData {
                return try await APIClient.fetchUser(userId)
            }
            """,
            expandedSource: """
            func fetchUserData(userId: String) async throws -> UserData {
                return try await APIClient.fetchUser(userId)
            }
            
            public func fetchUserDataIntercepted(userId: String) async throws -> UserData {
                let startTime = CFAbsoluteTimeGetCurrent()
                let context = InterceptorContext(
                    methodName: "fetchUserData",
                    typeName: String(describing: type(of: self)),
                    parameters: ["userId": userId],
                    parameterTypes: ["userId": String.self],
                    isAsync: true,
                    canThrow: true,
                    returnType: UserData.self,
                    startTime: startTime
                )
                
                do {
                    // Execute before interceptors
                    if let interceptor = InterceptorRegistry.get(name: "SecurityInterceptor") {
                        try interceptor.before(context: context)
                    }
                    
                    // Execute original method
                    let result = try await fetchUserData(userId: userId)
                    
                    // No after interceptors
                    
                    return result
                } catch {
                    // No error interceptors - re-throw
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testVoidReturnTypeInterceptor() {
        assertMacroExpansion(
            """
            @Interceptor(after: ["CleanupInterceptor"])
            func sendNotification(message: String) {
                NotificationService.send(message)
            }
            """,
            expandedSource: """
            func sendNotification(message: String) {
                NotificationService.send(message)
            }
            
            public func sendNotificationIntercepted(message: String) {
                let startTime = CFAbsoluteTimeGetCurrent()
                let context = InterceptorContext(
                    methodName: "sendNotification",
                    typeName: String(describing: type(of: self)),
                    parameters: ["message": message],
                    parameterTypes: ["message": String.self],
                    isAsync: false,
                    canThrow: false,
                    returnType: Void.self,
                    startTime: startTime
                )
                
                do {
                    // No before interceptors
                    
                    // Execute original method
                    sendNotification(message: message)
                    
                    // Execute after interceptors
                    if let interceptor = InterceptorRegistry.get(name: "CleanupInterceptor") {
                        try interceptor.after(context: context, result: nil)
                    }
                    
                } catch {
                    // No error interceptors - re-throw
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testStaticMethodInterceptor() {
        assertMacroExpansion(
            """
            @Interceptor(before: ["LoggingInterceptor"])
            static func validateToken(token: String) -> Bool {
                return TokenValidator.validate(token)
            }
            """,
            expandedSource: """
            static func validateToken(token: String) -> Bool {
                return TokenValidator.validate(token)
            }
            
            public static func validateTokenIntercepted(token: String) -> Bool {
                let startTime = CFAbsoluteTimeGetCurrent()
                let context = InterceptorContext(
                    methodName: "validateToken",
                    typeName: String(describing: type(of: self)),
                    parameters: ["token": token],
                    parameterTypes: ["token": String.self],
                    isAsync: false,
                    canThrow: false,
                    returnType: Bool.self,
                    startTime: startTime
                )
                
                do {
                    // Execute before interceptors
                    if let interceptor = InterceptorRegistry.get(name: "LoggingInterceptor") {
                        try interceptor.before(context: context)
                    }
                    
                    // Execute original method
                    let result = validateToken(token: token)
                    
                    // No after interceptors
                    
                    return result
                } catch {
                    // No error interceptors - re-throw
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testMultipleParametersInterceptor() {
        assertMacroExpansion(
            """
            @Interceptor(before: ["ValidationInterceptor"])
            func updateProfile(userId: String, name: String, email: String, age: Int = 25) -> UserProfile {
                return UserProfile(userId: userId, name: name, email: email, age: age)
            }
            """,
            expandedSource: """
            func updateProfile(userId: String, name: String, email: String, age: Int = 25) -> UserProfile {
                return UserProfile(userId: userId, name: name, email: email, age: age)
            }
            
            public func updateProfileIntercepted(userId: String, name: String, email: String, age: Int = 25) -> UserProfile {
                let startTime = CFAbsoluteTimeGetCurrent()
                let context = InterceptorContext(
                    methodName: "updateProfile",
                    typeName: String(describing: type(of: self)),
                    parameters: ["userId": userId, "name": name, "email": email, "age": age],
                    parameterTypes: ["userId": String.self, "name": String.self, "email": String.self, "age": Int.self],
                    isAsync: false,
                    canThrow: false,
                    returnType: UserProfile.self,
                    startTime: startTime
                )
                
                do {
                    // Execute before interceptors
                    if let interceptor = InterceptorRegistry.get(name: "ValidationInterceptor") {
                        try interceptor.before(context: context)
                    }
                    
                    // Execute original method
                    let result = updateProfile(userId: userId, name: name, email: email, age: age)
                    
                    // No after interceptors
                    
                    return result
                } catch {
                    // No error interceptors - re-throw
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    // MARK: - Error Case Tests
    
    func testInterceptorOnNonFunction() {
        assertMacroExpansion(
            """
            @Interceptor(before: ["LoggingInterceptor"])
            class UserService {
                var name: String = "service"
            }
            """,
            expandedSource: """
            class UserService {
                var name: String = "service"
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Interceptor can only be applied to functions and methods", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
    
    func testInterceptorOnProperty() {
        assertMacroExpansion(
            """
            class UserService {
                @Interceptor(before: ["LoggingInterceptor"])
                var isActive: Bool = true
            }
            """,
            expandedSource: """
            class UserService {
                var isActive: Bool = true
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Interceptor can only be applied to functions and methods", line: 2, column: 5)
            ],
            macros: testMacros
        )
    }
    
    // MARK: - Configuration Tests
    
    func testEmptyInterceptorConfiguration() {
        assertMacroExpansion(
            """
            @Interceptor()
            func simpleMethod() -> String {
                return "hello"
            }
            """,
            expandedSource: """
            func simpleMethod() -> String {
                return "hello"
            }
            
            public func simpleMethodIntercepted() -> String {
                let startTime = CFAbsoluteTimeGetCurrent()
                let context = InterceptorContext(
                    methodName: "simpleMethod",
                    typeName: String(describing: type(of: self)),
                    parameters: [:],
                    parameterTypes: [:],
                    isAsync: false,
                    canThrow: false,
                    returnType: String.self,
                    startTime: startTime
                )
                
                do {
                    // No before interceptors
                    
                    // Execute original method
                    let result = simpleMethod()
                    
                    // No after interceptors
                    
                    return result
                } catch {
                    // No error interceptors - re-throw
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testComplexInterceptorConfiguration() {
        assertMacroExpansion(
            """
            @Interceptor(
                before: ["SecurityInterceptor", "ValidationInterceptor"],
                after: ["AuditInterceptor", "CacheInterceptor"],
                onError: ["ErrorReportingInterceptor"],
                order: 1,
                measureTime: true
            )
            func complexOperation(data: ComplexData) async throws -> Result {
                return try await ProcessingService.process(data)
            }
            """,
            expandedSource: """
            func complexOperation(data: ComplexData) async throws -> Result {
                return try await ProcessingService.process(data)
            }
            
            public func complexOperationIntercepted(data: ComplexData) async throws -> Result {
                let startTime = CFAbsoluteTimeGetCurrent()
                let context = InterceptorContext(
                    methodName: "complexOperation",
                    typeName: String(describing: type(of: self)),
                    parameters: ["data": data],
                    parameterTypes: ["data": ComplexData.self],
                    isAsync: true,
                    canThrow: true,
                    returnType: Result.self,
                    startTime: startTime
                )
                
                do {
                    // Execute before interceptors
                    if let interceptor = InterceptorRegistry.get(name: "SecurityInterceptor") {
                        try interceptor.before(context: context)
                    }
                    if let interceptor = InterceptorRegistry.get(name: "ValidationInterceptor") {
                        try interceptor.before(context: context)
                    }
                    
                    // Execute original method
                    let result = try await complexOperation(data: data)
                    
                    // Execute after interceptors
                    if let interceptor = InterceptorRegistry.get(name: "CacheInterceptor") {
                        try interceptor.after(context: context, result: result)
                    }
                    if let interceptor = InterceptorRegistry.get(name: "AuditInterceptor") {
                        try interceptor.after(context: context, result: result)
                    }
                    
                    return result
                } catch {
                    // Execute error interceptors
                    if let interceptor = InterceptorRegistry.get(name: "ErrorReportingInterceptor") {
                        try interceptor.onError(context: context, error: error)
                    }
                    throw error
                }
            }
            """,
            macros: testMacros
        )
    }
    
    // MARK: - Integration Tests
    
    func testInterceptorRegistryIntegration() {
        // This test ensures the generated code works with InterceptorRegistry
        let testCode = """
        class TestService {
            @Interceptor(before: ["TestInterceptor"])
            func testMethod() -> String {
                return "test"
            }
        }
        """
        
        // Verify that the macro generates code that references InterceptorRegistry.get(name:)
        assertMacroExpansion(
            testCode,
            expandedSource: """
            class TestService {
                func testMethod() -> String {
                    return "test"
                }
                
                public func testMethodIntercepted() -> String {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    let context = InterceptorContext(
                        methodName: "testMethod",
                        typeName: String(describing: type(of: self)),
                        parameters: [:],
                        parameterTypes: [:],
                        isAsync: false,
                        canThrow: false,
                        returnType: String.self,
                        startTime: startTime
                    )
                    
                    do {
                        // Execute before interceptors
                        if let interceptor = InterceptorRegistry.get(name: "TestInterceptor") {
                            try interceptor.before(context: context)
                        }
                        
                        // Execute original method
                        let result = testMethod()
                        
                        // No after interceptors
                        
                        return result
                    } catch {
                        // No error interceptors - re-throw
                        throw error
                    }
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