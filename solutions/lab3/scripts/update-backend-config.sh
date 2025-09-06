#!/bin/bash

# Update Backend Configuration Script
# This script updates the backend configuration files with actual storage account names

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to update backend configuration
update_backend_config() {
    local environment=$1
    local storage_account=$2
    local backend_file="environments/${environment}/backend.tf"
    
    if [[ ! -f "$backend_file" ]]; then
        print_error "Backend file not found: $backend_file"
        return 1
    fi
    
    # Create backup
    cp "$backend_file" "${backend_file}.backup"
    
    # Update storage account name
    sed -i "s/sttfstatelab3${environment}/${storage_account}/g" "$backend_file"
    
    print_success "Updated $environment backend configuration"
    print_status "Storage account: $storage_account"
}

# Main function
main() {
    print_status "Updating backend configurations..."
    
    # Check if running from correct directory
    if [[ ! -d "environments" ]]; then
        print_error "Please run this script from the lab3 root directory"
        exit 1
    fi
    
    # Get current subscription ID for unique naming
    SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$SUBSCRIPTION_ID" ]]; then
        print_error "Not logged in to Azure CLI or unable to get subscription ID"
        print_status "Please run 'az login' first"
        exit 1
    fi
    
    # Generate unique storage account names
    SUBSCRIPTION_SUFFIX=$(echo "$SUBSCRIPTION_ID" | tr -d '-' | head -c 8)
    STAGING_SA="sttfstatelab3staging${SUBSCRIPTION_SUFFIX}"
    PRODUCTION_SA="sttfstatelab3prod${SUBSCRIPTION_SUFFIX}"
    
    print_status "Detected subscription: $SUBSCRIPTION_ID"
    print_status "Generated storage account names:"
    echo "  Staging: $STAGING_SA"
    echo "  Production: $PRODUCTION_SA"
    echo ""
    
    # Update staging backend
    if update_backend_config "staging" "$STAGING_SA"; then
        print_success "Staging backend configuration updated"
    else
        print_error "Failed to update staging backend"
        exit 1
    fi
    
    # Update production backend
    if update_backend_config "production" "$PRODUCTION_SA"; then
        print_success "Production backend configuration updated"
    else
        print_error "Failed to update production backend"
        exit 1
    fi
    
    echo ""
    print_success "Backend configurations updated successfully!"
    print_status "Next steps:"
    echo "1. Verify the changes in environments/staging/backend.tf and environments/production/backend.tf"
    echo "2. Ensure the storage accounts exist (run setup-azure-auth.sh if needed)"
    echo "3. Test the pipeline with a pull request"
}

# Show usage if help requested
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0"
    echo ""
    echo "This script updates the backend configuration files with actual Azure storage account names"
    echo "based on your current Azure subscription."
    echo ""
    echo "Prerequisites:"
    echo "- Azure CLI logged in"
    echo "- Run from lab3 root directory"
    echo ""
    echo "The script will:"
    echo "- Generate unique storage account names based on your subscription ID"
    echo "- Update environments/staging/backend.tf"
    echo "- Update environments/production/backend.tf"
    echo "- Create backup files (.backup)"
    exit 0
fi

# Run main function
main "$@"
