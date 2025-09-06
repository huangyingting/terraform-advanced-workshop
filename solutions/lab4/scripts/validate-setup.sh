#!/bin/bash

# Validation script for Lab 3 setup
# This script validates that the GitHub Actions CI/CD pipeline is properly configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if Azure CLI is available and user is logged in
check_azure_cli() {
    print_status "Checking Azure CLI..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        return 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI"
        return 1
    fi
    
    SUBSCRIPTION=$(az account show --query name -o tsv)
    print_success "Azure CLI authenticated (Subscription: $SUBSCRIPTION)"
}

# Check if Terraform is available
check_terraform() {
    print_status "Checking Terraform..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        return 1
    fi
    
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1 | cut -d' ' -f2)
    print_success "Terraform available (Version: $TERRAFORM_VERSION)"
    
    # Check version is >= 1.7
    if ! terraform version | grep -E "v1\.[7-9]|v[2-9]" &> /dev/null; then
        print_warning "Terraform version should be >= 1.7"
    fi
}

# Validate Terraform configuration
validate_terraform_config() {
    print_status "Validating Terraform configuration..."
    
    if [[ ! -f "main.tf" ]]; then
        print_error "main.tf not found"
        return 1
    fi
    
    if [[ ! -f "variables.tf" ]]; then
        print_error "variables.tf not found"
        return 1
    fi
    
    if [[ ! -f "outputs.tf" ]]; then
        print_error "outputs.tf not found"
        return 1
    fi
    
    if [[ ! -f "providers.tf" ]]; then
        print_error "providers.tf not found"
        return 1
    fi
    
    print_success "Required Terraform files present"
    
    # Validate Terraform syntax
    if terraform fmt -check &> /dev/null; then
        print_success "Terraform formatting is correct"
    else
        print_warning "Terraform files need formatting (run 'terraform fmt')"
    fi
    
    # Initialize and validate
    if terraform init -backend=false &> /dev/null; then
        print_success "Terraform initialization successful"
    else
        print_error "Terraform initialization failed"
        return 1
    fi
    
    if terraform validate &> /dev/null; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform validation failed"
        terraform validate
        return 1
    fi
}

# Check environment variable files
check_tfvars_files() {
    print_status "Checking environment variable files..."
    
    if [[ ! -f "staging.tfvars" ]]; then
        print_error "staging.tfvars not found"
        return 1
    fi
    
    if [[ ! -f "production.tfvars" ]]; then
        print_error "production.tfvars not found"
        return 1
    fi
    
    print_success "Environment variable files present"
    
    # Check staging.tfvars content
    if grep -q 'environment = "staging"' staging.tfvars; then
        print_success "Staging environment correctly configured"
    else
        print_error "Staging environment not properly configured in staging.tfvars"
        return 1
    fi
    
    # Check production.tfvars content
    if grep -q 'environment = "production"' production.tfvars; then
        print_success "Production environment correctly configured"
    else
        print_error "Production environment not properly configured in production.tfvars"
        return 1
    fi
}

# Check GitHub Actions workflow files
check_github_workflows() {
    print_status "Checking GitHub Actions workflows..."
    
    if [[ ! -d ".github/workflows" ]]; then
        print_error ".github/workflows directory not found"
        return 1
    fi
    
    if [[ ! -f ".github/workflows/plan.yml" ]]; then
        print_error "plan.yml workflow not found"
        return 1
    fi
    
    if [[ ! -f ".github/workflows/apply.yml" ]]; then
        print_error "apply.yml workflow not found"
        return 1
    fi
    
    print_success "GitHub Actions workflow files present"
    
    # Check workflow content
    if grep -q "pull_request" .github/workflows/plan.yml; then
        print_success "Plan workflow has pull request trigger"
    else
        print_warning "Plan workflow may not have proper pull request trigger"
    fi
    
    if grep -q "azure/login" .github/workflows/plan.yml; then
        print_success "Plan workflow uses Azure OIDC login"
    else
        print_error "Plan workflow missing Azure OIDC login"
        return 1
    fi
    
    if grep -q "environment: production" .github/workflows/apply.yml; then
        print_success "Apply workflow has production environment protection"
    else
        print_warning "Apply workflow may not have production environment protection"
    fi
}

# Check backend configuration files
check_backend_configs() {
    print_status "Checking backend configurations..."
    
    if [[ ! -d "environments" ]]; then
        print_error "environments directory not found"
        return 1
    fi
    
    if [[ ! -f "environments/staging/backend.tf" ]]; then
        print_error "Staging backend configuration not found"
        return 1
    fi
    
    if [[ ! -f "environments/production/backend.tf" ]]; then
        print_error "Production backend configuration not found"
        return 1
    fi
    
    print_success "Backend configuration files present"
}

# Check for SSH key
check_ssh_key() {
    print_status "Checking SSH key..."
    
    if [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
        print_success "SSH public key found at $HOME/.ssh/id_rsa.pub"
    else
        print_warning "SSH public key not found. You may need to generate one:"
        echo "  ssh-keygen -t rsa -b 4096 -C 'your-email@example.com'"
    fi
}

# Check Azure App Registration (requires environment variables)
check_azure_app_registration() {
    print_status "Checking for Azure App Registration information..."
    
    if [[ -n "$AZURE_CLIENT_ID" ]]; then
        print_success "AZURE_CLIENT_ID environment variable is set"
        
        # Try to get app registration details
        APP_NAME=$(az ad app show --id "$AZURE_CLIENT_ID" --query displayName -o tsv 2>/dev/null || echo "")
        if [[ -n "$APP_NAME" ]]; then
            print_success "App Registration found: $APP_NAME"
        else
            print_warning "App Registration not found or not accessible"
        fi
    else
        print_warning "AZURE_CLIENT_ID environment variable not set"
        print_status "Run the setup script: ./scripts/setup-azure-auth.sh"
    fi
}

# Main validation function
main() {
    print_status "Starting Lab 3 environment validation..."
    echo ""
    
    ERRORS=0
    
    check_azure_cli || ((ERRORS++))
    check_terraform || ((ERRORS++))
    check_terraform_config || ((ERRORS++))
    check_tfvars_files || ((ERRORS++))
    check_github_workflows || ((ERRORS++))
    check_backend_configs || ((ERRORS++))
    check_ssh_key
    check_azure_app_registration
    
    echo ""
    if [[ $ERRORS -eq 0 ]]; then
        print_success "All validation checks passed! 🎉"
        echo ""
        print_status "Next steps:"
        echo "1. Run './scripts/setup-azure-auth.sh' if you haven't configured Azure OIDC"
        echo "2. Add the GitHub repository secrets"
        echo "3. Create GitHub environments (staging and production)"
        echo "4. Test the pipeline by creating a pull request"
    else
        print_error "$ERRORS validation check(s) failed"
        echo ""
        print_status "Please fix the issues above before proceeding"
        exit 1
    fi
}

# Run main function
main "$@"
