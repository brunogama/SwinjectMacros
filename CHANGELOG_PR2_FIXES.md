# Code Review Fixes for PR #2

## Changes Made

### 1. Test Utilities Error Handling

- **File**: `Sources/SwinjectMacros/Testing/Spy.swift`
- **Change**: Replaced `fatalError()` calls with proper error handling using `TestAssertionError`
- **Impact**: Test verification methods now throw errors instead of crashing
- **Methods Updated**:
  - `verifyCalled(_:times:)` - now throws `TestAssertionError`
  - `verifyNeverCalled(_:)` - now throws `TestAssertionError`
  - `verifyCalledAtLeastOnce(_:)` - now throws `TestAssertionError`
  - `verifyCallOrder(_:before:)` - now throws `TestAssertionError`

### 2. Shell Script Path Extraction

- **File**: `fix_multiline.sh`
- **Change**: Updated grep pattern from `'./[^:]*\.swift'` to `'\./[^:]*\.swift'`
- **Impact**: More robust path matching for Swift files

### 3. Memory Leak Fix

- **File**: `Examples/iOS-SwiftUI-Demo/Sources/Services/AnalyticsService.swift`
- **Change**: Added `[weak self]` capture and guard statement in Timer closure
- **Impact**: Prevents retain cycle and potential memory leak
- **Code**:
  ```swift
  Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
      guard let self else { return }
      Task {
          try? await self.flush()
      }
  }
  ```

### 4. @testable Import Check

- **Status**: Already resolved - no @testable imports found in production code

### 5. Parameter Naming Consistency

- **Status**: Already consistent - uses `resolver` when dependencies are needed, `_` when not

### 6. Test Fixes

- **File**: `Tests/SwinjectMacrosTests/PerformanceRegressionTests.swift`
- **Changes**:
  - Fixed concurrent test to use synchronized resolver
  - Fixed LazyInject tests to properly set Container.shared
- **Impact**: Tests now pass without concurrency errors

## API Changes

### TestAssertionError

New error type added for test assertions:

```swift
public struct TestAssertionError: Error, CustomStringConvertible {
    public let message: String
    public let file: StaticString
    public let line: UInt

    public init(message: String, file: StaticString = #file, line: UInt = #line)
    public var description: String
}
```

### SpyVerification Methods

All verification methods now throw errors:

```swift
public static func verifyCalled(_ calls: [some SpyCall], times: Int) throws
public static func verifyNeverCalled(_ calls: [some SpyCall]) throws
public static func verifyCalledAtLeastOnce(_ calls: [some SpyCall]) throws
public static func verifyCallOrder(_ firstCalls: [some SpyCall], before secondCalls: [some SpyCall]) throws
```

## Breaking Changes

- Test code using `SpyVerification` methods must now handle thrown errors with `try`
- This is a breaking change for any existing test code using these verification methods

## Migration Guide

Update test code from:

```swift
SpyVerification.verifyCalled(spy.methodCalls, times: 2)
```

To:

```swift
try SpyVerification.verifyCalled(spy.methodCalls, times: 2)
```

Or use XCTAssertNoThrow:

```swift
XCTAssertNoThrow(try SpyVerification.verifyCalled(spy.methodCalls, times: 2))
```
