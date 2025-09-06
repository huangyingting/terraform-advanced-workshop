# Lab 5: Terraform Module Quality Gate & Release Automation

## Overview
This lab demonstrates how to implement enterprise-grade quality gates and release automation for Terraform modules. You'll learn advanced DevSecOps practices including automated testing with Terratest, static code analysis with TFLint, security scanning with Checkov, and semantic versioning with automated releases through GitHub Actions.

## Prerequisites

### Required Permissions
- **Azure Subscription**: Contributor or Owner role for deploying test resources
- **GitHub Repository**: Admin access for configuring Actions and secrets

### Required Tools
- Azure CLI v2.50+ authenticated and configured
- Terraform v1.7+ installed
- Go v1.21+ for Terratest integration tests
- Node.js v18+ for semantic-release
- Git for version control
- Make (optional, for convenience commands)

### GitHub Secrets Configuration
Configure the following secrets in your GitHub repository for CI/CD:
```bash
# Azure Service Principal for GitHub Actions
ARM_CLIENT_ID="your-service-principal-client-id"
ARM_CLIENT_SECRET="your-service-principal-client-secret"
ARM_SUBSCRIPTION_ID="your-azure-subscription-id"
ARM_TENANT_ID="your-azure-tenant-id"
GITHUB_TOKEN="your-github-personal-access-token"
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Terraform Module Structure                  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┤
│  │                   Module Source                             │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │  modules/web_app/                                       │
│  │  │  ├── main.tf         (Module logic)                     │
│  │  │  ├── variables.tf    (Input variables)                  │
│  │  │  ├── outputs.tf      (Output values)                    │
│  │  │  └── versions.tf     (Provider requirements)            │
│  │  └─────────────────────────────────────────────────────────┘
│  │                                                             │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │                  Examples                               │
│  │  │  ┌─────────────────────────────────────────────────────┤
│  │  │  │  examples/basic/                                    │
│  │  │  │  └── main.tf     (Usage example)                    │
│  │  │  └─────────────────────────────────────────────────────┘
│  │  └─────────────────────────────────────────────────────────┘
│  │                                                             │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │                   Tests                                 │
│  │  │  ┌─────────────────────────────────────────────────────┤
│  │  │  │  tests/                                             │
│  │  │  │  ├── web_app_test.go (Integration tests)            │
│  │  │  │  └── go.mod         (Go dependencies)               │
│  │  │  └─────────────────────────────────────────────────────┘
│  │  └─────────────────────────────────────────────────────────┘
│  └─────────────────────────────────────────────────────────────┘
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┤
│  │               Quality Gate Pipeline                         │
│  │                                                             │
│  │  📝 Code Format     → terraform fmt                        │
│  │  🔍 Static Analysis → tflint                               │
│  │  🔒 Security Scan   → checkov                              │
│  │  ✅ Unit Tests      → terratest (plan-only)                │
│  │  🧪 Integration     → terratest (apply/destroy)            │
│  │  📦 Semantic Release → automated versioning                │
│  └─────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
```

## Step-by-Step Instructions

### Step 1: Environment Setup

1. **Set up your development environment:**
   ```bash
   # Clone the repository
   git clone <your-repo-url>
   cd terraform-advanced-workshop/solutions/lab5
   
   # Set environment variables
   export TF_VAR_location="southeastasia"
   export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
   ```

2. **Install required tools:**
   ```bash
   # Install TFLint
   curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
   
   # Install Checkov
   pip install checkov
   
   # Install Go (if not already installed)
   # Download from https://golang.org/dl/
   
   # Verify installations
   terraform version
   tflint --version
   checkov --version
   go version
   ```

### Step 2: Module Development and Testing

1. **Examine the module structure:**
   ```bash
   # Review the module files
   tree modules/web_app/
   
   # Check the example usage
   cat examples/basic/main.tf
   ```

2. **Run local quality checks:**
   ```bash
   # Format code
   terraform fmt -recursive .
   
   # Initialize TFLint
   tflint --init
   
   # Run static analysis
   tflint --format compact modules/web_app/
   tflint --format compact examples/basic/
   
   # Run security scan
   checkov --config-file .checkov.yml --directory . --output cli
   ```

3. **Validate Terraform configurations:**
   ```bash
   # Validate module
   cd modules/web_app
   terraform init
   terraform validate
   cd ../..
   
   # Validate example
   cd examples/basic
   terraform init
   terraform validate
   terraform plan
   cd ../..
   ```

### Step 3: Automated Testing with Terratest

1. **Review the test structure:**
   ```bash
   # Examine test files
   cat tests/web_app_test.go
   cat tests/go.mod
   ```

2. **Run unit tests (plan-only, fast):**
   ```bash
   cd tests
   go test -v -short -timeout 5m
   cd ..
   ```

3. **Run integration tests (creates real resources):**
   ```bash
   cd tests
   go test -v -timeout 30m
   cd ..
   ```

### Step 4: GitHub Actions CI/CD Pipeline

1. **Review the CI/CD configuration:**
   ```bash
   # Examine the GitHub Actions workflow
   cat .github/workflows/ci.yml
   
   # Review semantic release configuration
   cat .releaserc.js
   ```

2. **Configure GitHub repository secrets:**
   ```bash
   # Create a service principal for GitHub Actions
   az ad sp create-for-rbac --name "sp-github-actions-lab5" \
     --role Contributor \
     --scopes /subscriptions/$ARM_SUBSCRIPTION_ID \
     --sdk-auth
   
   # Note the output and configure GitHub secrets:
   # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID
   ```

3. **Test the pipeline locally (optional):**
   ```bash
   # Use the Makefile for convenient testing
   make help
   make quality-gate    # Run format, lint, validate, security
   make test-unit      # Run unit tests
   make test-integration # Run integration tests (creates resources)
   ```

### Step 5: Semantic Versioning and Release Automation

1. **Understand semantic versioning:**
   ```bash
   # Review conventional commit format examples:
   # feat: add new app_settings variable (minor version bump)
   # fix: correct output description (patch version bump)  
   # feat!: change variable name (major version bump)
   # docs: update README examples (no version bump)
   ```

2. **Make changes and commit using conventional commits:**
   ```bash
   # Example: Add a new feature
   git add .
   git commit -m "feat: add support for connection strings configuration"
   git push origin main
   
   # This will trigger the CI pipeline and semantic release
   ```

3. **Monitor the automated release:**
   ```bash
   # Check GitHub Actions for pipeline execution
   # Check GitHub Releases for automated version tags
   # Review CHANGELOG.md for auto-generated release notes
   ```

## Key Learning Outcomes

### Quality Gates Implementation
- **Code Formatting**: Automated enforcement of Terraform code style with `terraform fmt`
- **Static Analysis**: Detection of potential issues and best practices with TFLint
- **Security Scanning**: Identification of security vulnerabilities with Checkov
- **Configuration Validation**: Syntax and logic validation across all configurations

### Testing Strategy
- **Unit Testing**: Fast validation with plan-only tests
- **Integration Testing**: Real resource deployment and validation with Terratest
- **Parallel Execution**: Efficient test execution with Go's parallel testing features
- **Test Coverage**: Comprehensive validation of module functionality and outputs

### CI/CD Automation
- **Pull Request Validation**: Automated quality checks on every PR
- **Branch Protection**: Enforced quality gates before code merge
- **Artifact Management**: Automated upload of scan results and reports
- **Environment Isolation**: Separate test environments for different branches

### Release Automation
- **Semantic Versioning**: Automated version determination from commit messages
- **Release Notes**: Auto-generated changelogs from conventional commits
- **Git Tagging**: Automated creation of version tags and releases
- **Artifact Publishing**: Automated publication of module versions

## Testing Scenarios

### Scenario 1: Basic Module Deployment
```bash
# Deploy the basic example
cd examples/basic
terraform init
terraform plan
terraform apply -auto-approve

# Test the deployed web app
curl -I https://$(terraform output -raw web_app_hostname)

# Clean up
terraform destroy -auto-approve
```

### Scenario 2: Module Customization
```bash
# Create a custom example with advanced features
cat > examples/custom/main.tf << 'EOF'
module "web_app" {
  source = "../../modules/web_app"
  
  name                = "custom-web-app"
  location            = "southeastasia"
  resource_group_name = azurerm_resource_group.custom.name
  
  sku         = "P1v3"
  always_on   = true
  https_only  = true
  
  app_settings = {
    "NODE_ENV"                     = "production"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "CUSTOM_SETTING"              = "value"
  }
  
  connection_strings = [
    {
      name  = "DefaultConnection"
      type  = "SQLAzure"
      value = "Server=tcp:example.database.windows.net;Database=mydb"
    }
  ]
  
  tags = {
    Environment = "production"
    Owner       = "platform-team"
  }
}
EOF
```

### Scenario 3: Security Compliance Testing
```bash
# Run comprehensive security scanning
checkov --config-file .checkov.yml \
        --directory . \
        --output cli \
        --output json \
        --output-file-path reports/security-report.json

# Review security findings
cat reports/security-report.json | jq '.results.failed_checks'
```

## Troubleshooting

### Common Issues

1. **TFLint Configuration Issues**
   ```bash
   # Error: Plugin not found
   tflint --init  # Re-initialize plugins
   
   # Error: Invalid configuration
   tflint --config .tflint.hcl --show-config
   ```

2. **Checkov False Positives**
   ```bash
   # Skip specific checks temporarily
   checkov --skip-check CKV_AZURE_13,CKV_AZURE_17 --directory .
   
   # Create baseline for known issues
   checkov --create-baseline --directory .
   ```

3. **Terratest Timeout Issues**
   ```bash
   # Increase timeout for integration tests
   go test -v -timeout 60m
   
   # Run tests with detailed output
   go test -v -parallel 1
   ```

4. **GitHub Actions Authentication**
   ```bash
   # Verify service principal permissions
   az role assignment list --assignee $ARM_CLIENT_ID
   
   # Test authentication locally
   az login --service-principal \
     --username $ARM_CLIENT_ID \
     --password $ARM_CLIENT_SECRET \
     --tenant $ARM_TENANT_ID
   ```

### Performance Optimization

1. **Test Execution Speed**
   ```bash
   # Run unit tests only (faster)
   go test -v -short
   
   # Use parallel execution
   go test -v -parallel 4
   ```

2. **Resource Management**
   ```bash
   # Use unique resource names to avoid conflicts
   export TF_VAR_environment="test-$(date +%s)"
   
   # Clean up resources after each test
   terraform destroy -auto-approve
   ```

## Success Criteria

- ✅ Module structure follows Terraform best practices with proper documentation
- ✅ All quality gates pass: formatting, linting, validation, and security scanning
- ✅ Unit tests validate module configuration without creating resources
- ✅ Integration tests successfully deploy and verify real Azure resources
- ✅ GitHub Actions pipeline executes all quality checks automatically
- ✅ Semantic versioning generates appropriate version tags from commit messages
- ✅ Security scan identifies and reports potential vulnerabilities
- ✅ Module can be consumed by other projects with proper version pinning

## Advanced Extensions

### Custom Quality Rules
```bash
# Create custom TFLint rules
mkdir -p .tflint.d/rules
cat > .tflint.d/rules/custom.hcl << 'EOF'
rule "terraform_required_tags" {
  enabled = true
  tags = ["Environment", "Owner", "Project"]
}
EOF
```

### Performance Testing
```bash
# Add performance tests to Terratest
func TestWebAppPerformance(t *testing.T) {
    // Test response times, throughput, etc.
}
```

### Multi-Environment Testing
```bash
# Test module against multiple Azure regions
environments := []string{"eastus", "westeurope", "southeastasia"}
```

## Cleanup

When finished with the lab, clean up all resources:

```bash
# Destroy example resources
cd examples/basic
terraform destroy -auto-approve

# Clean up test artifacts
cd ../../tests
rm -rf TestData/

# Remove temporary files
make clean
```

## Next Steps

- Explore advanced Terratest patterns for complex scenarios
- Implement custom security policies with OPA/Conftest
- Set up module registry for organization-wide sharing
- Integrate with Azure DevOps or other CI/CD platforms
- Implement compliance as code with additional scanning tools

For the complete workshop series, return to the [main README](../../README.md).
