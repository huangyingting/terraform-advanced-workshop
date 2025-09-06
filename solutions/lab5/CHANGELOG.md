# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial web app module with comprehensive configuration options
- Terratest integration tests for module validation
- GitHub Actions CI/CD pipeline with quality gates
- Semantic release automation with conventional commits
- Security scanning with Checkov
- Static code analysis with TFLint
- Comprehensive documentation and examples

### Security
- HTTPS-only enforcement by default
- Disabled FTP and FTPS for enhanced security
- Minimum TLS version 1.2 requirement
- System-assigned managed identity support

### Testing
- Unit tests for plan validation
- Integration tests with real Azure resource deployment
- HTTP accessibility testing with retry logic
- Parallel test execution support
