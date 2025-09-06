# Contributing to Lab 5: Terraform Module Quality Gate

Thank you for your interest in contributing! This document provides guidelines for contributing to this Terraform module.

## Development Workflow

### 1. Setup Development Environment

```bash
# Clone the repository
git clone <repository-url>
cd terraform-advanced-workshop/solutions/lab5

# Install dependencies
make help  # Review available commands
```

### 2. Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the coding standards below

3. Test your changes locally:
   ```bash
   make quality-gate  # Run all quality checks
   make test-unit     # Run unit tests
   ```

### 3. Commit Guidelines

We use [Conventional Commits](https://www.conventionalcommits.org/) for semantic versioning:

- `feat:` New features (minor version bump)
- `fix:` Bug fixes (patch version bump)
- `feat!:` Breaking changes (major version bump)
- `docs:` Documentation changes (no version bump)
- `test:` Test changes (no version bump)
- `ci:` CI/CD changes (no version bump)

Examples:
```bash
git commit -m "feat: add connection strings support"
git commit -m "fix: correct output variable description"
git commit -m "feat!: rename variable for consistency"
git commit -m "docs: update module usage examples"
```

## Coding Standards

### Terraform Code Style

1. **Formatting**: Use `terraform fmt` for consistent formatting
2. **Naming**: Use snake_case for all resources, variables, and outputs
3. **Documentation**: All variables and outputs must have descriptions
4. **Validation**: Add validation rules for complex variables
5. **Tags**: Support tags on all applicable resources

### Module Structure

```
modules/web_app/
├── main.tf          # Main resources
├── variables.tf     # Input variables with validation
├── outputs.tf       # Output values with descriptions
└── versions.tf      # Provider requirements
```

### Example Code Quality

```hcl
# Good: Well-documented variable with validation
variable "sku" {
  description = "The SKU for the App Service Plan. Valid options include B1, B2, B3, S1, S2, S3, P1v2, P2v2, P3v2, P1v3, P2v3, P3v3."
  type        = string
  default     = "B1"
  
  validation {
    condition = contains([
      "B1", "B2", "B3",
      "S1", "S2", "S3",
      "P1v2", "P2v2", "P3v2",
      "P1v3", "P2v3", "P3v3"
    ], var.sku)
    error_message = "SKU must be a valid App Service Plan SKU."
  }
}

# Good: Descriptive output
output "web_app_url" {
  description = "The URL of the Azure Linux Web App"
  value       = "https://${azurerm_linux_web_app.this.default_hostname}"
}
```

## Testing Guidelines

### Unit Tests
- Must not create real resources
- Should validate configuration correctness
- Use `terraform plan` for validation

### Integration Tests
- Create and validate real resources
- Include cleanup in test functions
- Test all major functionality paths
- Use meaningful assertions

### Test Example
```go
func TestWebAppModule(t *testing.T) {
    t.Parallel()
    
    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/basic",
        Vars: map[string]interface{}{
            "environment": "test",
        },
    }
    
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)
    
    // Test outputs
    webAppURL := terraform.Output(t, terraformOptions, "web_app_url")
    assert.NotEmpty(t, webAppURL)
    assert.Contains(t, webAppURL, "https://")
}
```

## Quality Gates

All contributions must pass these quality gates:

1. **Formatting**: `terraform fmt -check -recursive`
2. **Validation**: `terraform validate`
3. **Linting**: `tflint`
4. **Security**: `checkov`
5. **Testing**: Unit and integration tests
6. **Documentation**: Updated README and inline docs

### Running Quality Checks Locally

```bash
# Run all quality checks
make quality-gate

# Individual checks
make fmt        # Format code
make lint       # Run TFLint
make validate   # Validate configurations
make security   # Run security scan
make test-unit  # Run unit tests
```

## Pull Request Process

1. **Create a Pull Request** with a clear title and description
2. **Reference any related issues** in the PR description
3. **Ensure all checks pass** - the GitHub Actions pipeline must be green
4. **Request review** from module maintainers
5. **Address feedback** and update as needed

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No new warnings introduced
```

## Security Considerations

### Sensitive Information
- Never commit secrets, passwords, or API keys
- Use variables for sensitive configuration
- Follow Azure security best practices

### Security Scanning
- All code is scanned with Checkov
- Address HIGH and MEDIUM severity findings
- Document any accepted risks

## Documentation Standards

### README Requirements
- Clear overview and architecture
- Step-by-step instructions
- Prerequisites and requirements
- Usage examples
- Troubleshooting section

### Code Documentation
- All variables must have descriptions
- All outputs must have descriptions
- Complex logic should include inline comments
- Examples should be realistic and tested

## Release Process

Releases are automated through semantic-release:

1. **Merge to main** triggers the release pipeline
2. **Semantic versioning** determines version based on commits
3. **Release notes** are auto-generated from conventional commits
4. **Git tags** are created automatically

### Version Bumping
- `fix:` commits → patch version (1.0.1)
- `feat:` commits → minor version (1.1.0)
- `feat!:` or `BREAKING CHANGE:` → major version (2.0.0)

## Getting Help

- Review existing issues and PRs
- Check the main workshop documentation
- Reach out to maintainers for questions

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Follow professional communication standards

Thank you for contributing to make this module better! 🚀
