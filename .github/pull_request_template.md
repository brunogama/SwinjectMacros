# Pull Request

## Description

<!-- Provide a brief description of the changes in this PR -->

## Type of Change

<!-- Please delete options that are not relevant -->

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🧹 Code cleanup/refactoring
- [ ] ⚡ Performance improvement
- [ ] 🔧 Build system/tooling changes
- [ ] 🧪 Test improvements

## Related Issues

<!-- Link to any related issues -->

Fixes #(issue number)
Closes #(issue number)
Related to #(issue number)

## Changes Made

<!-- Provide a detailed list of changes -->

### Core Changes

- [ ] Added/modified macro: `@MacroName`
- [ ] Updated implementation in: `path/to/file.swift`
- [ ] Added new functionality: brief description

### Documentation Changes

- [ ] Updated README.md
- [ ] Added/updated inline documentation
- [ ] Updated API documentation
- [ ] Added usage examples

### Test Changes

- [ ] Added unit tests
- [ ] Added integration tests
- [ ] Updated existing tests
- [ ] Added performance benchmarks

## Code Examples

<!-- Show how the changes work with code examples -->

### Before

```swift
// Old implementation or usage
```

### After

```swift
// New implementation or usage
```

## Testing

<!-- Describe how you tested your changes -->

### Test Environment

- [ ] macOS version:
- [ ] Xcode version:
- [ ] Swift version:
- [ ] Target platforms tested: macOS / iOS / watchOS / tvOS

### Test Coverage

- [ ] All new code is covered by tests
- [ ] Existing tests pass
- [ ] Performance tests pass (if applicable)
- [ ] Integration tests pass

### Manual Testing

<!-- Describe any manual testing performed -->

- [ ] Tested with sample project
- [ ] Verified macro expansion works correctly
- [ ] Checked error handling and edge cases
- [ ] Validated SwiftUI integration (if applicable)

## Performance Impact

<!-- Describe any performance implications -->

- [ ] No performance impact
- [ ] Improves performance (describe how)
- [ ] May impact performance (describe impact and mitigation)
- [ ] Performance impact unknown (needs benchmarking)

### Benchmarks

<!-- Include benchmark results if applicable -->

```
Before: X.Xs (±Y.Y%)
After:  X.Xs (±Y.Y%)
Change: ±Z% improvement/regression
```

## Breaking Changes

<!-- If this introduces breaking changes, describe them and the migration path -->

### API Changes

- [ ] No breaking changes
- [ ] Method signature changes
- [ ] Parameter changes
- [ ] Removed public APIs
- [ ] Changed behavior

### Migration Guide

<!-- Provide migration instructions for breaking changes -->

```swift
// Old way
// Code example of how users currently do something

// New way
// Code example of how users should do it now
```

## Compatibility

<!-- Check compatibility with supported versions -->

- [ ] Swift 5.9+
- [ ] Swift 5.10+
- [ ] Xcode 15.0+
- [ ] macOS 12.0+
- [ ] iOS 15.0+
- [ ] watchOS 8.0+
- [ ] tvOS 15.0+

## Documentation

<!-- Ensure documentation is updated -->

- [ ] Public APIs are documented
- [ ] Usage examples are provided
- [ ] Error conditions are documented
- [ ] Migration guide updated (if breaking changes)
- [ ] CHANGELOG.md updated

## Security

<!-- Consider security implications -->

- [ ] No security implications
- [ ] Changes follow security best practices
- [ ] No sensitive data exposed
- [ ] Input validation implemented where needed

## Checklist

<!-- Complete this checklist before submitting -->

### Development

- [ ] Code follows the project's style guidelines
- [ ] Self-review of the code has been performed
- [ ] Code is commented, particularly in hard-to-understand areas
- [ ] No debug/console logs left in production code
- [ ] Error handling is appropriate

### Testing

- [ ] Tests have been added that prove the fix is effective or that the feature works
- [ ] New and existing unit tests pass locally
- [ ] Integration tests pass
- [ ] Performance tests pass (if applicable)

### Documentation

- [ ] Changes are documented in code comments
- [ ] Public APIs have appropriate documentation
- [ ] Usage examples are provided
- [ ] Breaking changes are documented

### Process

- [ ] PR title follows conventional commit format
- [ ] PR description clearly explains the changes
- [ ] Related issues are linked
- [ ] Ready for review

## Review Notes

<!-- Any specific areas you'd like reviewers to focus on -->

Please pay special attention to:

- [ ] Macro expansion logic
- [ ] Thread safety implementation
- [ ] Error handling and edge cases
- [ ] Performance implications
- [ ] API design and usability

## Screenshots/Videos

<!-- If applicable, add screenshots or videos demonstrating the changes -->

## Additional Context

<!-- Add any other context about the pull request here -->

______________________________________________________________________

**Reviewer Guidelines:**

- Test the changes locally if possible
- Check that all CI checks pass
- Verify documentation is adequate
- Consider backward compatibility
- Review performance implications
