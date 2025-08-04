# Security Policy

## Supported Versions

We actively support the following versions of SwinjectUtilityMacros with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| 0.9.x   | :white_check_mark: |
| < 0.9   | :x:                |

## Reporting a Vulnerability

The SwinjectUtilityMacros team takes security vulnerabilities seriously. We appreciate your efforts to responsibly disclose your findings.

### How to Report

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please send an email to: **security@swinjectmacros.dev**

Include the following information in your report:

- **Type of issue** (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
- **Full paths of source file(s)** related to the manifestation of the issue
- **The location of the affected source code** (tag/branch/commit or direct URL)
- **Any special configuration required** to reproduce the issue
- **Step-by-step instructions to reproduce the issue**
- **Proof-of-concept or exploit code** (if possible)
- **Impact of the issue**, including how an attacker might exploit the issue

This information will help us triage your report more quickly.

### Response Timeline

- **Initial Response**: We will acknowledge receipt of your vulnerability report within **48 hours**.
- **Assessment**: We will provide a detailed response within **72 hours** indicating the next steps in handling your report.
- **Resolution**: After the initial reply, we will keep you informed of the progress towards a fix and full announcement.

### Disclosure Policy

- We ask that you give us a reasonable amount of time to fix the issue before any disclosure to the public or a third party.
- We will credit you for your discovery in our security advisory (unless you prefer to remain anonymous).
- We will coordinate with you on the timing of the public disclosure.

## Security Considerations for SwinjectUtilityMacros

### Macro Security

SwinjectUtilityMacros generates code at compile time. While this provides performance benefits, it's important to understand the security implications:

1. **Code Generation**: Macros generate Swift code that becomes part of your application. Always review generated code in critical applications.

1. **Dependency Injection**: Be cautious about what dependencies you inject, especially when dealing with sensitive data or external resources.

1. **Build-Time Security**: Ensure your build environment is secure, as macros execute during compilation.

### Best Practices

#### For Library Users

1. **Pin Versions**: Use specific versions rather than ranges to ensure consistent behavior:

   ```swift
   .package(url: "https://github.com/user/SwinjectUtilityMacros.git", exact: "1.0.0")
   ```

1. **Review Dependencies**: Regularly audit your dependencies using tools like `swift package audit`.

1. **Secure Configuration**: When using macros with configuration, validate input parameters:

   ```swift
   @LazyInject(timeout: 30) // Use reasonable timeouts
   var service: ServiceProtocol = ServiceImpl()
   ```

1. **Testing**: Always test macro-generated code thoroughly, especially in security-critical applications.

#### For Contributors

1. **Input Validation**: Validate all macro parameters and provide clear error messages for invalid input.

1. **Safe Code Generation**: Generate code that follows security best practices:

   - Use appropriate access controls
   - Validate dependencies before injection
   - Handle errors gracefully

1. **Documentation**: Document security considerations for each macro.

### Common Security Scenarios

#### Thread Safety

SwinjectUtilityMacros implements thread-safe dependency injection. However, be aware that:

- The injected dependencies themselves must be thread-safe
- Lazy initialization is protected, but subsequent access depends on the dependency's implementation

#### Memory Management

- Use `@WeakInject` for dependencies that might create retain cycles
- Be cautious with `@AsyncInject` to avoid memory leaks in long-running async operations

#### SwiftUI Integration

- Environment-based injection is secure by default
- Be cautious when injecting sensitive services into SwiftUI views

## Security Updates

Security updates will be released as patch versions and announced through:

1. **GitHub Security Advisories**
1. **Release Notes**
1. **Email notifications** (if you're subscribed to security updates)

## Acknowledgments

We would like to thank the following individuals for their responsible disclosure of security vulnerabilities:

<!-- This section will be updated as we receive and address security reports -->

*No security vulnerabilities have been reported yet.*

______________________________________________________________________

## Contact

For questions about this security policy, please contact us at **security@swinjectmacros.dev**.

For general questions about SwinjectUtilityMacros, please use the public GitHub issues or discussions.
