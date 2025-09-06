#!/bin/bash

# Lab1 Terraform Backend Preparation Script
# Creates Azure Storage Account for Terraform remote state with random name
# Updates Terraform files to use the storage account
# Supports reverting to original placeholder settings

set -e

# Default values
DEFAULT_RESOURCE_GROUP="lab1tf-rg"
DEFAULT_LOCATION="southeastasia"
DEFAULT_CONTAINER="tfstate"

# Environment variable overrides
RESOURCE_GROUP=${RESOURCE_GROUP:-$DEFAULT_RESOURCE_GROUP}
LOCATION=${LOCATION:-$DEFAULT_LOCATION}
CONTAINER_NAME=${CONTAINER_NAME:-$DEFAULT_CONTAINER}

# Generate random storage account name: lab1 + 6 random alphanumeric characters
generate_storage_name() {
    local random_suffix=$(openssl rand -hex 3 | tr '[:upper:]' '[:lower:]')
    echo "lab1${random_suffix}"
}

# Function to show usage
usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup     Create storage account and update Terraform files (default)"
    echo "  revert    Revert Terraform files to original placeholder settings"
    echo "  help      Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  RESOURCE_GROUP    Resource group name (default: $DEFAULT_RESOURCE_GROUP)"
    echo "  LOCATION          Azure region (default: $DEFAULT_LOCATION)"
    echo "  CONTAINER_NAME    Storage container name (default: $DEFAULT_CONTAINER)"
    echo ""
    echo "Examples:"
    echo "  ./prepare.sh setup"
    echo "  ./prepare.sh revert"
    echo "  RESOURCE_GROUP=my-rg LOCATION=westus2 ./prepare.sh setup"
}

# Function to create Azure resources
create_storage() {
    echo "Creating Azure storage resources..."
    
    # Generate storage account name
    STORAGE_ACCOUNT=$(generate_storage_name)
    
    # Check if Azure CLI is installed and user is logged in
    if ! command -v az &> /dev/null; then
        echo "Error: Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if user is logged in
    if ! az account show &> /dev/null; then
        echo "Error: Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    echo "Using Resource Group: $RESOURCE_GROUP"
    echo "Using Location: $LOCATION"
    echo "Using Storage Account: $STORAGE_ACCOUNT"
    echo "Using Container: $CONTAINER_NAME"
    
    # Create resource group (idempotent)
    echo "Creating resource group..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
    
    # Create storage account (idempotent)
    echo "Creating storage account..."
    az storage account create \
        --name "$STORAGE_ACCOUNT" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --access-tier Hot \
        --output table
    
    # Get current user's object ID for role assignment
    echo "Getting current user information..."
    CURRENT_USER_ID=$(az ad signed-in-user show --query id --output tsv)
    
    # Assign Storage Blob Data Contributor role to current user
    echo "Assigning Storage Blob Data Contributor role..."
    az role assignment create \
        --role "Storage Blob Data Contributor" \
        --assignee "$CURRENT_USER_ID" \
        --scope "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT" \
        --output table || echo "Role assignment may already exist, continuing..."
    
    # Create blob container using Azure AD authentication (idempotent)
    echo "Creating blob container..."
    az storage container create \
        --name "$CONTAINER_NAME" \
        --account-name "$STORAGE_ACCOUNT" \
        --auth-mode login \
        --output table
    
    echo ""
    echo "Storage resources created successfully!"
    echo ""
    
    # Store configuration for revert functionality
    cat > .backend_config << EOF
RESOURCE_GROUP=$RESOURCE_GROUP
STORAGE_ACCOUNT=$STORAGE_ACCOUNT
CONTAINER_NAME=$CONTAINER_NAME
EOF
    
    return 0
}

# Function to update Terraform files with storage account details
update_terraform_files() {
    local resource_group="$1"
    local storage_account="$2"
    local container_name="$3"
    
    echo "Updating Terraform files..."
    
    # Update infrastructure/main.tf
    if [[ -f "infrastructure/main.tf" ]]; then
        echo "Updating infrastructure/main.tf..."
        sed -i.bak \
            -e "s/REPLACE-rg/$resource_group/g" \
            -e "s/REPLACEstorage/$storage_account/g" \
            "infrastructure/main.tf"
        
        # Update container name if it's not the default
        if [[ "$container_name" != "tfstate" ]]; then
            sed -i \
                -e "s/container_name.*=.*\"tfstate\"/container_name       = \"$container_name\"/g" \
                "infrastructure/main.tf"
        fi
        
        # Add use_azuread_auth = true to backend configuration
        sed -i \
            -e '/key.*=.*"networking\.tfstate"/a\    use_azuread_auth     = true' \
            "infrastructure/main.tf"
    fi
    
    # Update application/data.tf
    if [[ -f "application/data.tf" ]]; then
        echo "Updating application/data.tf..."
        sed -i.bak \
            -e "s/REPLACE-rg/$resource_group/g" \
            -e "s/REPLACEstorage/$storage_account/g" \
            "application/data.tf"
        
        # Update container name if it's not the default
        if [[ "$container_name" != "tfstate" ]]; then
            sed -i \
                -e "s/container_name.*=.*\"tfstate\"/container_name       = \"$container_name\"/g" \
                "application/data.tf"
        fi
    fi
    
    echo "Terraform files updated successfully!"
}

# Function to revert Terraform files to original placeholders
revert_terraform_files() {
    echo "Reverting Terraform files to original placeholders..."
    
    # Revert infrastructure/main.tf
    if [[ -f "infrastructure/main.tf.bak" ]]; then
        echo "Reverting infrastructure/main.tf..."
        mv "infrastructure/main.tf.bak" "infrastructure/main.tf"
    else
        if [[ -f "infrastructure/main.tf" ]]; then
            echo "Reverting infrastructure/main.tf (no backup found, using sed)..."
            # Read current values from config if available
            if [[ -f ".backend_config" ]]; then
                source .backend_config
                sed -i \
                    -e "s/$RESOURCE_GROUP/REPLACE-rg/g" \
                    -e "s/$STORAGE_ACCOUNT/REPLACEstorage/g" \
                    -e "s/container_name.*=.*\"$CONTAINER_NAME\"/container_name       = \"tfstate\"/g" \
                    "infrastructure/main.tf"
            else
                echo "Warning: No backup or config found for infrastructure/main.tf"
            fi
        fi
    fi
    
    # Revert application/data.tf
    if [[ -f "application/data.tf.bak" ]]; then
        echo "Reverting application/data.tf..."
        mv "application/data.tf.bak" "application/data.tf"
    else
        if [[ -f "application/data.tf" ]]; then
            echo "Reverting application/data.tf (no backup found, using sed)..."
            # Read current values from config if available
            if [[ -f ".backend_config" ]]; then
                source .backend_config
                sed -i \
                    -e "s/$RESOURCE_GROUP/REPLACE-rg/g" \
                    -e "s/$STORAGE_ACCOUNT/REPLACEstorage/g" \
                    -e "s/container_name.*=.*\"$CONTAINER_NAME\"/container_name       = \"tfstate\"/g" \
                    "application/data.tf"
            else
                echo "Warning: No backup or config found for application/data.tf"
            fi
        fi
    fi
    
    # Clean up config file
    if [[ -f ".backend_config" ]]; then
        rm .backend_config
    fi
    
    echo "Terraform files reverted to original state!"
}

# Function to show backend configuration
show_backend_config() {
    local resource_group="$1"
    local storage_account="$2"
    local container_name="$3"
    
    echo ""
    echo "Backend configuration:"
    echo "====================="
    echo "terraform {"
    echo "  backend \"azurerm\" {"
    echo "    resource_group_name  = \"$resource_group\""
    echo "    storage_account_name = \"$storage_account\""
    echo "    container_name       = \"$container_name\""
    echo "    key                  = \"<your-state-file>.tfstate\""
    echo "  }"
    echo "}"
    echo ""
}

# Main script logic
main() {
    local command="${1:-setup}"
    
    case "$command" in
        "setup"|"")
            echo "Setting up Terraform backend storage..."
            echo ""
            
            create_storage
            update_terraform_files "$RESOURCE_GROUP" "$STORAGE_ACCOUNT" "$CONTAINER_NAME"
            show_backend_config "$RESOURCE_GROUP" "$STORAGE_ACCOUNT" "$CONTAINER_NAME"
            
            echo "Setup completed successfully!"
            echo ""
            echo "Next steps:"
            echo "1. cd infrastructure && terraform init"
            echo "2. cd ../application && terraform init"
            ;;
        "revert")
            echo "Reverting Terraform backend configuration..."
            echo ""
            revert_terraform_files
            echo "Revert completed successfully!"
            ;;
        "help"|"-h"|"--help")
            usage
            ;;
        *)
            echo "Error: Unknown command '$command'"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
