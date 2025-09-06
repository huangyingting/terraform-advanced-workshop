#!/bin/bash

# Azure OIDC Setup Script for GitHub Actions
# This script configures Azure OpenID Connect authentication for GitHub Actions

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required environment variables are set
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI. Please run 'az login' first"
        exit 1
    fi
    
    if [[ -z "${GITHUB_REPO}" ]]; then
        print_error "GITHUB_REPO environment variable is not set"
        print_status "Please set it like: export GITHUB_REPO='your-org/repo-name'"
        exit 1
    fi
    
    if [[ -z "${APP_NAME}" ]]; then
        export APP_NAME="github-terraform-cicd"
        print_warning "APP_NAME not set, using default: ${APP_NAME}"
    fi
    
    print_success "Prerequisites check completed"
}

# Create App Registration
create_app_registration() {
    print_status "Creating App Registration: ${APP_NAME}"
    
    # Check if app already exists
    EXISTING_APP=$(az ad app list --display-name "${APP_NAME}" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    
    if [[ -n "${EXISTING_APP}" && "${EXISTING_APP}" != "null" ]]; then
        print_warning "App Registration '${APP_NAME}' already exists with ID: ${EXISTING_APP}"
        export APP_ID="${EXISTING_APP}"
    else
        export APP_ID=$(az ad app create \
            --display-name "${APP_NAME}" \
            --query appId \
            --output tsv)
        
        print_success "Created App Registration with ID: ${APP_ID}"
    fi
    
    # Create service principal if it doesn't exist
    SP_EXISTS=$(az ad sp show --id "${APP_ID}" --query "appId" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "${SP_EXISTS}" || "${SP_EXISTS}" == "null" ]]; then
        az ad sp create --id "${APP_ID}" > /dev/null
        print_success "Created Service Principal"
    else
        print_warning "Service Principal already exists"
    fi
}

# Configure Federated Identity Credentials
configure_federated_credentials() {
    print_status "Configuring Federated Identity Credentials..."
    
    # Check and create main branch credential
    MAIN_CRED_EXISTS=$(az ad app federated-credential list --id "${APP_ID}" \
        --query "[?name=='github-main-branch'].name | [0]" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "${MAIN_CRED_EXISTS}" || "${MAIN_CRED_EXISTS}" == "null" ]]; then
        az ad app federated-credential create \
            --id "${APP_ID}" \
            --parameters '{
                "name": "github-main-branch",
                "issuer": "https://token.actions.githubusercontent.com",
                "subject": "repo:'"${GITHUB_REPO}"':ref:refs/heads/main",
                "description": "GitHub Actions main branch deployment",
                "audiences": ["api://AzureADTokenExchange"]
            }' > /dev/null
        
        print_success "Created federated credential for main branch"
    else
        print_warning "Federated credential for main branch already exists"
    fi
    
    # Check and create pull request credential
    PR_CRED_EXISTS=$(az ad app federated-credential list --id "${APP_ID}" \
        --query "[?name=='github-pull-requests'].name | [0]" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "${PR_CRED_EXISTS}" || "${PR_CRED_EXISTS}" == "null" ]]; then
        az ad app federated-credential create \
            --id "${APP_ID}" \
            --parameters '{
                "name": "github-pull-requests",
                "issuer": "https://token.actions.githubusercontent.com",
                "subject": "repo:'"${GITHUB_REPO}"':pull_request",
                "description": "GitHub Actions pull request validation",
                "audiences": ["api://AzureADTokenExchange"]
            }' > /dev/null
        
        print_success "Created federated credential for pull requests"
    else
        print_warning "Federated credential for pull requests already exists"
    fi
}

# Assign Azure RBAC permissions
assign_permissions() {
    print_status "Assigning Azure RBAC permissions..."
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    
    # Check if role assignment already exists
    EXISTING_ASSIGNMENT=$(az role assignment list \
        --assignee "${APP_ID}" \
        --role "Contributor" \
        --scope "/subscriptions/${SUBSCRIPTION_ID}" \
        --query "[0].principalId" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "${EXISTING_ASSIGNMENT}" || "${EXISTING_ASSIGNMENT}" == "null" ]]; then
        az role assignment create \
            --assignee "${APP_ID}" \
            --role "Contributor" \
            --scope "/subscriptions/${SUBSCRIPTION_ID}" > /dev/null
        
        print_success "Assigned Contributor role to Service Principal"
    else
        print_warning "Service Principal already has Contributor role"
    fi
}

# Create backend storage accounts
create_backend_storage() {
    print_status "Creating backend storage accounts..."
    
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    LOCATION="southeastasia"  # Default location
    
    # Create staging backend
    STAGING_RG="rg-terraform-state-staging"
    STAGING_SA="sttfstatelab3staging$(echo $SUBSCRIPTION_ID | tr -d '-' | head -c 8)"
    
    # Create resource group for staging
    if ! az group show --name "${STAGING_RG}" &>/dev/null; then
        az group create --name "${STAGING_RG}" --location "${LOCATION}" > /dev/null
        print_success "Created staging resource group: ${STAGING_RG}"
    else
        print_warning "Staging resource group already exists: ${STAGING_RG}"
    fi
    
    # Create storage account for staging
    if ! az storage account show --name "${STAGING_SA}" --resource-group "${STAGING_RG}" &>/dev/null; then
        az storage account create \
            --name "${STAGING_SA}" \
            --resource-group "${STAGING_RG}" \
            --location "${LOCATION}" \
            --sku Standard_LRS \
            --kind StorageV2 \
            --allow-blob-public-access false \
            --min-tls-version TLS1_2 > /dev/null
        print_success "Created staging storage account: ${STAGING_SA}"
    else
        print_warning "Staging storage account already exists: ${STAGING_SA}"
    fi
    
    # Create container for staging
    az storage container create \
        --name tfstate \
        --account-name "${STAGING_SA}" \
        --auth-mode login &>/dev/null || true
    
    # Create production backend
    PRODUCTION_RG="rg-terraform-state-production"
    PRODUCTION_SA="sttfstatelab3prod$(echo $SUBSCRIPTION_ID | tr -d '-' | head -c 8)"
    
    # Create resource group for production
    if ! az group show --name "${PRODUCTION_RG}" &>/dev/null; then
        az group create --name "${PRODUCTION_RG}" --location "${LOCATION}" > /dev/null
        print_success "Created production resource group: ${PRODUCTION_RG}"
    else
        print_warning "Production resource group already exists: ${PRODUCTION_RG}"
    fi
    
    # Create storage account for production
    if ! az storage account show --name "${PRODUCTION_SA}" --resource-group "${PRODUCTION_RG}" &>/dev/null; then
        az storage account create \
            --name "${PRODUCTION_SA}" \
            --resource-group "${PRODUCTION_RG}" \
            --location "${LOCATION}" \
            --sku Standard_GRS \
            --kind StorageV2 \
            --allow-blob-public-access false \
            --min-tls-version TLS1_2 > /dev/null
        print_success "Created production storage account: ${PRODUCTION_SA}"
    else
        print_warning "Production storage account already exists: ${PRODUCTION_SA}"
    fi
    
    # Create container for production
    az storage container create \
        --name tfstate \
        --account-name "${PRODUCTION_SA}" \
        --auth-mode login &>/dev/null || true
    
    # Export storage account names for later use
    export STAGING_STORAGE_ACCOUNT="${STAGING_SA}"
    export PRODUCTION_STORAGE_ACCOUNT="${PRODUCTION_SA}"
}

# Display final configuration
display_configuration() {
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    TENANT_ID=$(az account show --query tenantId -o tsv)
    
    print_success "Azure OIDC configuration completed!"
    echo ""
    print_status "=== GitHub Repository Secrets ==="
    echo "Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):"
    echo ""
    echo "AZURE_CLIENT_ID: ${APP_ID}"
    echo "AZURE_TENANT_ID: ${TENANT_ID}"
    echo "AZURE_SUBSCRIPTION_ID: ${SUBSCRIPTION_ID}"
    echo ""
    print_status "=== Backend Configuration ==="
    echo "Staging backend storage account: ${STAGING_STORAGE_ACCOUNT:-Not created}"
    echo "Production backend storage account: ${PRODUCTION_STORAGE_ACCOUNT:-Not created}"
    echo ""
    print_status "=== Next Steps ==="
    echo "1. Add the secrets above to your GitHub repository"
    echo "2. Create 'staging' and 'production' environments in GitHub"
    echo "3. Configure protection rules for the production environment"
    echo "4. Update backend configurations with the actual storage account names"
    echo "5. Test the pipeline by creating a pull request"
    echo ""
}

# Main execution
main() {
    print_status "Starting Azure OIDC setup for GitHub Actions..."
    echo ""
    
    check_prerequisites
    create_app_registration
    configure_federated_credentials
    assign_permissions
    create_backend_storage
    display_configuration
    
    print_success "Setup completed successfully!"
}

# Run main function
main "$@"
