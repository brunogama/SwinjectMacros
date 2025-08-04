# Swift Code Style Guide for Claude

This project follows Apple's Swift-NIO code style conventions. When writing Swift code, adhere to these rules:

## Core Formatting Rules

### Indentation and Spacing

- Use 4 spaces for indentation (never tabs)
- Maximum line length: 120 characters
- Maximum 1 blank line between code sections
- No spaces around range operators (`...`, `..<`)
- Line break before each argument in multi-line function calls
- Line break before each generic requirement

### Braces and Structure

- Opening braces on the same line as the declaration
- No semicolons at the end of lines
- One case per line in switch statements
- One variable declaration per line
- No empty trailing closure parentheses

### Imports and Organization

- Order imports alphabetically
- Group imports by type (system, third-party, local)
- Use shorthand type names where possible

### Documentation

- Use triple-slash `///` for documentation comments
- No block comments `/* */`
- Documentation not required for all public declarations (pragmatic approach)

### Swift Best Practices

- Return `Void` instead of empty tuple `()`
- Use shorthand type names
- Omit explicit returns in single-expression functions
- No labels in case patterns
- No parentheses around conditions
- Replace `forEach` with `for-in` loops where appropriate

### Allowed Practices (Not Enforced)

- Force unwrapping is allowed when appropriate
- Force try is allowed when appropriate
- Implicitly unwrapped optionals are allowed when necessary
- Leading underscores are allowed for private properties
- Early exits are not mandatory

## Example Code Style

```swift
import Foundation
import Swinject

/// A service that manages user authentication
public final class AuthenticationService {
    private let _apiClient: APIClient
    private let _tokenStorage: TokenStorage

    public init(
        apiClient: APIClient,
        tokenStorage: TokenStorage
    ) {
        self._apiClient = apiClient
        self._tokenStorage = tokenStorage
    }

    public func authenticate(
        username: String,
        password: String
    ) async throws -> AuthToken {
        let credentials = Credentials(
            username: username,
            password: password
        )

        let token = try await _apiClient.authenticate(credentials)
        try await _tokenStorage.store(token)

        return token
    }
}
```

## File Structure

- Place access modifiers consistently
- Use `private` for file-scoped declarations by default
- No access level on extension declarations
- Group related functionality using `// MARK: -` comments

## Error Handling

- Use proper error types and throwing functions
- Document error conditions when not obvious
- Force unwrapping/try is acceptable for programmer errors

This style is enforced by SwiftFormat and checked by SwiftLint with Apple Swift-NIO compatible settings.
