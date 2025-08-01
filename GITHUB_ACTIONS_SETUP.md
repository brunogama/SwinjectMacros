# GitHub Actions Setup Guide

This document describes the comprehensive GitHub Actions CI/CD pipeline implemented for SwinJectMacros.

## 🔄 Workflows Overview

### 1. **CI Pipeline** (`.github/workflows/ci.yml`)
**Triggers:** Push to `main`/`develop`, PRs to `main`/`develop`

**Jobs:**
- **Test Matrix**: Tests across Swift 5.9/5.10 with multiple Xcode versions
- **Lint**: SwiftLint code quality checks
- **Documentation**: Generates and validates API documentation  
- **Integration Tests**: Runs integration and performance benchmarks
- **Platform Compatibility**: Tests on macOS 12/13/14
- **Example Validation**: Creates and tests example projects

**Key Features:**
- Parallel test execution for faster CI
- Code coverage reporting with Codecov
- Caching for Swift Package Manager
- Automatic example project validation

### 2. **Release Pipeline** (`.github/workflows/release.yml`)
**Triggers:** Git tags matching `v*` pattern

**Jobs:**
- **Validation**: Ensures tag format and version consistency
- **Platform Testing**: Tests all supported platforms (macOS/iOS/watchOS/tvOS)
- **Documentation Building**: Generates release documentation
- **Release Creation**: Creates GitHub releases with changelogs
- **Documentation Publishing**: Deploys docs to GitHub Pages
- **Notifications**: Success/failure notifications

**Key Features:**
- Automatic changelog generation from git history
- Multi-platform testing before release
- Documentation archive attached to releases
- Semantic version validation
- Pre-release support with `-beta` tags

### 3. **Documentation Pipeline** (`.github/workflows/docs.yml`)
**Triggers:** Push to `main`, PR changes to docs, manual dispatch

**Jobs:**
- **Build Documentation**: Generates Swift DocC documentation
- **Deploy to GitHub Pages**: Publishes docs (main branch only)
- **Link Validation**: Checks for broken links
- **Accessibility Check**: Basic accessibility validation
- **Performance Analysis**: Monitors documentation size and performance

**Key Features:**
- Automatic GitHub Pages deployment
- Custom documentation homepage
- Link validation and accessibility checks
- Performance monitoring for large docs

### 4. **Security Pipeline** (`.github/workflows/security.yml`)
**Triggers:** Push, PRs, weekly schedule, manual dispatch

**Jobs:**
- **Dependency Security**: Scans for vulnerable dependencies
- **Code Security**: Static analysis with Semgrep
- **Secrets Detection**: Scans git history for leaked secrets
- **License Compliance**: Validates license headers and dependencies
- **Privacy Assessment**: Checks for privacy-sensitive APIs
- **Security Policy**: Validates security documentation

**Key Features:**
- Automated vulnerability scanning
- Secrets detection in git history
- License compliance monitoring
- Privacy impact assessment
- Weekly scheduled security audits

### 5. **Performance Pipeline** (`.github/workflows/performance.yml`)
**Triggers:** Push, PRs, daily schedule, manual dispatch

**Jobs:**
- **Compile-Time Performance**: Measures build and macro expansion times
- **Runtime Benchmarks**: Tests dependency resolution performance
- **Memory Analysis**: Monitors memory usage patterns
- **Macro Expansion Benchmarks**: Tests different macro types
- **Performance Regression**: Compares PR performance vs base branch

**Key Features:**
- Build time monitoring with thresholds
- Runtime performance benchmarking
- Memory usage analysis
- Performance regression detection
- Daily performance tracking

### 6. **Compatibility Pipeline** (`.github/workflows/compatibility.yml`)
**Triggers:** Push, PRs, weekly schedule, manual dispatch

**Jobs:**
- **Swift Version Matrix**: Tests Swift 5.9, 5.10 compatibility
- **Platform Support**: Tests macOS/iOS/watchOS/tvOS
- **Package Manager**: Tests SwiftPM and Xcode integration
- **Dependency Versions**: Tests multiple Swinject versions
- **Backward Compatibility**: Detects API breaking changes
- **Migration Validation**: Tests upgrade scenarios

**Key Features:**
- Comprehensive platform coverage
- Dependency version compatibility testing
- Breaking change detection
- Migration path validation
- Weekly compatibility audits

## 🛠️ Setup Requirements

### Repository Secrets
The following GitHub repository secrets should be configured:

```bash
# Required for code coverage
CODECOV_TOKEN=<your-codecov-token>

# Optional: Custom domain for GitHub Pages
CUSTOM_DOMAIN=swinjectmacros.dev
```

### Branch Protection Rules
Configure branch protection for `main`:

- Require PR reviews (2 reviewers recommended)
- Require status checks to pass:
  - `test` (CI pipeline)
  - `lint` (Code quality)
  - `compatibility` (Platform tests)
  - `security` (Security scans)
- Require branches to be up to date
- Restrict pushes to main branch

### Repository Settings

1. **GitHub Pages**:
   - Source: GitHub Actions
   - Custom domain: `swinjectmacros.dev` (optional)

2. **Security**:
   - Enable Dependabot security updates
   - Enable private vulnerability reporting
   - Configure security advisories

3. **General**:
   - Enable issues and projects
   - Enable wiki (optional)
   - Enable discussions (recommended)

## 🚀 Workflow Features

### Caching Strategy
- **Swift Package Manager**: Caches `.build` directories
- **SwiftLint**: Caches SwiftLint installation
- **Documentation**: Caches documentation builds
- **Xcode**: Caches derived data when applicable

### Performance Optimizations
- **Parallel Execution**: Matrix builds run in parallel
- **Selective Triggers**: Workflows only run when relevant files change
- **Early Termination**: Fail-fast strategy for quick feedback
- **Incremental Builds**: Leverages Swift's incremental compilation

### Quality Gates
- **Code Coverage**: Minimum 80% coverage threshold
- **Build Performance**: Build time thresholds (30s clean, 5s incremental)
- **Security**: No critical security issues allowed
- **Compatibility**: All supported platforms must pass
- **Documentation**: All public APIs must be documented

### Notification Strategy
- **Success**: Silent for routine builds, notify for releases
- **Failure**: Immediate notification via GitHub notifications
- **Security**: Email alerts for security vulnerabilities
- **Performance**: Alerts for significant performance regressions

## 📊 Monitoring and Reporting

### Artifacts Generated
- **Test Results**: JUnit XML for test result tracking
- **Code Coverage**: LCOV reports uploaded to Codecov
- **Documentation**: HTML documentation archives
- **Security Reports**: Vulnerability scan results
- **Performance Reports**: Benchmark results and trends

### Dashboard Access
- **GitHub Actions**: Repository Actions tab
- **Codecov**: Code coverage dashboard
- **GitHub Pages**: Live documentation site
- **Security**: Security tab for vulnerability reports
- **Insights**: Repository insights for trends

## 🔧 Customization

### Adding New Workflows
1. Create workflow file in `.github/workflows/`
2. Define appropriate triggers and jobs
3. Add required secrets and permissions
4. Update branch protection rules if needed
5. Test with a draft release or feature branch

### Modifying Existing Workflows
1. Test changes in a feature branch first
2. Consider backward compatibility
3. Update documentation if needed
4. Monitor for any performance impact

### Environment-Specific Configuration
- **Development**: More frequent runs, detailed logging
- **Staging**: Full test suite, security scans
- **Production**: Release pipeline, documentation deployment

## 🔒 Security Considerations

### Workflow Security
- All workflows use pinned action versions
- Secrets are properly scoped and protected
- No sensitive data in logs or artifacts
- Limited permissions for each job

### Supply Chain Security
- Dependency scanning and vulnerability alerts
- Package integrity verification
- Secure build environment isolation
- Audit trail for all changes

## 📈 Performance Metrics

### Build Performance Targets
- **Clean Build**: < 30 seconds
- **Incremental Build**: < 5 seconds
- **Test Suite**: < 2 minutes
- **Documentation**: < 1 minute

### Quality Metrics
- **Code Coverage**: > 80%
- **Documentation Coverage**: > 95% for public APIs
- **Security Score**: No critical vulnerabilities
- **Performance Regression**: < 5% slowdown threshold

This comprehensive CI/CD pipeline ensures code quality, security, performance, and compatibility across all supported platforms and Swift versions.