# Lab 4: Production-Grade GitHub Actions CI/CD Pipeline

## Overview
This lab demonstrates how to implement a production-ready CI/CD pipeline for Terraform using GitHub Actions with OpenID Connect (OIDC) authentication, automated planning on pull requests, multi-environment deployments with approval gates, and secure state management. You'll learn enterprise-grade Infrastructure as Code (IaC) practices without storing long-lived secrets in your repository.

## Prerequisites

### Required Azure Permissions
- **Subscription Level**: Contributor or Owner role
- **Microsoft Entra ID**: Application Developer role (to create App Registrations)
- **Resource Groups**: Ability to create and manage resource groups
- **Storage Accounts**: Ability to create storage accounts for Terraform backends

### Required Tools and Accounts
- **GitHub Account**: Personal or organization account with repository access
- **Azure CLI**: v2.50+ installed and authenticated
- **Terraform**: v1.7+ installed locally for testing
- **Git**: For version control and repository management
- **VS Code**: With GitHub Copilot and Terraform extensions (recommended)

### Environment Setup
```bash
# Verify Azure CLI authentication
az account show

# Set environment variables for consistency
export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export GITHUB_REPO="your-org/terraform-advanced-workshop"
export APP_NAME="github-terraform-cicd"

# Set default region
export LOCATION="southeastasia"
```

## Directory Structure
```
lab4/
├── README.md                    # This documentation
├── .github/                     # GitHub Actions workflows
│   └── workflows/
│       ├── plan.yml            # PR planning workflow
│       └── apply.yml           # Main branch deployment workflow
├── main.tf                     # Main Terraform configuration
├── variables.tf                # Variable definitions
├── outputs.tf                  # Output definitions
├── providers.tf                # Provider configurations
├── staging.tfvars             # Staging environment variables
├── production.tfvars           # Production environment variables
├── scripts/                    # Setup and utility scripts
│   ├── setup-azure-auth.sh     # Azure OIDC configuration script
│   └── validate-setup.sh       # Environment validation script
└── environments/               # Environment-specific configurations
    ├── staging/
    │   └── backend.tf          # Staging backend configuration
    └── production/
        └── backend.tf          # Production backend configuration
```

## Step-by-Step Instructions

### Step 1: Configure Azure Authentication (OIDC)

Azure OpenID Connect allows GitHub Actions to authenticate to Azure without storing long-lived secrets.

1. **Create an App Registration:**
   ```bash
   # Create the application registration
   APP_ID=$(az ad app create \
     --display-name "$APP_NAME" \
     --query appId --output tsv)
   
   echo "Application ID: $APP_ID"
   
   # Create a service principal
   az ad sp create --id $APP_ID
   
   # Get the Object ID for the service principal
   SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id --output tsv)
   echo "Service Principal Object ID: $SP_OBJECT_ID"
   ```

2. **Configure Federated Identity Credentials:**
   ```bash
   # For main branch deployments
   az ad app federated-credential create \
     --id $APP_ID \
     --parameters '{
       "name": "github-main-branch",
       "issuer": "https://token.actions.githubusercontent.com",
       "subject": "repo:'$GITHUB_REPO':ref:refs/heads/main",
       "description": "GitHub Actions main branch",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   
   # For pull request planning
   az ad app federated-credential create \
     --id $APP_ID \
     --parameters '{
       "name": "github-pull-requests",
       "issuer": "https://token.actions.githubusercontent.com",
       "subject": "repo:'$GITHUB_REPO':pull_request",
       "description": "GitHub Actions pull requests",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   ```

3. **Assign Azure Permissions:**
   ```bash
   # Assign Contributor role at subscription level
   az role assignment create \
     --assignee $APP_ID \
     --role "Contributor" \
     --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"
   
   # Verify role assignment
   az role assignment list \
     --assignee $APP_ID \
     --output table
   ```

4. **Get Required Values for GitHub Secrets:**
   ```bash
   # Display values needed for GitHub repository secrets
   echo "GitHub Repository Secrets Required:"
   echo "AZURE_CLIENT_ID: $APP_ID"
   echo "AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
   echo "AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"
   ```

   **Alternative: Use the automated setup script:**
   ```bash
   # Set required environment variables
   export GITHUB_REPO="your-org/terraform-advanced-workshop"
   export APP_NAME="github-terraform-cicd"
   
   # Run the automated setup script
   ./scripts/setup-azure-auth.sh
   ```

### Step 2: Configure GitHub Repository

1. **Set up GitHub Secrets:**
   Navigate to your repository → Settings → Secrets and variables → Actions

   Add the following repository secrets:
   - `AZURE_CLIENT_ID`: The Application ID from Step 1
   - `AZURE_TENANT_ID`: Your Azure tenant ID
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID

2. **Create GitHub Environments:**
   Navigate to Settings → Environments and create:
   
   **Staging Environment:**
   - Name: `staging`
   - Deployment branches: Selected branches → `main`
   - No protection rules (automatic deployment)

   **Production Environment:**
   - Name: `production`
   - Deployment branches: Selected branches → `main`
   - Protection rules:
     - ✅ Required reviewers (add yourself or team members)
     - ✅ Wait timer: 5 minutes (optional)
     - ✅ Prevent administrators from bypassing protection rules

### Step 3: Create Terraform Infrastructure Configuration

The Terraform configuration has already been created with the following components:

1. **Review the configuration files:**
   ```bash
   ls -la
   # main.tf          - Main infrastructure resources
   # variables.tf     - Variable definitions with validation
   # outputs.tf       - Output definitions
   # providers.tf     - Provider configuration
   # staging.tfvars   - Staging environment variables
   # production.tfvars - Production environment variables
   ```

2. **Key Infrastructure Components:**
   - **Resource Groups**: Separate RGs for each environment
   - **Virtual Networks**: Environment-specific address spaces
   - **Virtual Machines**: Ubuntu 22.04 LTS with nginx
   - **Storage Accounts**: App storage with appropriate replication
   - **Network Security Groups**: SSH and HTTP/HTTPS access rules
   - **Log Analytics**: Optional monitoring (enabled in production)

### Step 4: Configure Backend Storage

1. **Create backend storage accounts:**
   ```bash
   # Automated approach using the script
   ./scripts/setup-azure-auth.sh
   
   # Or manual approach
   # Create staging backend
   az group create \
     --name rg-terraform-state-staging \
     --location southeastasia
   
   STAGING_SA="sttfstatelab4staging$(date +%s)"
   az storage account create \
     --name "$STAGING_SA" \
     --resource-group rg-terraform-state-staging \
     --location southeastasia \
     --sku Standard_LRS \
     --kind StorageV2
   
   # Create production backend (repeat with different names)
   ```

2. **Update backend configurations:**
   ```bash
   # Update staging backend configuration
   sed -i "s/sttfstatelab4staging/$STAGING_SA/g" environments/staging/backend.tf
   
   # Update production backend configuration  
   sed -i "s/sttfstatelab4production/$PRODUCTION_SA/g" environments/production/backend.tf
   ```

### Step 5: Test the CI/CD Pipeline

1. **Validate the setup:**
   ```bash
   # Run the validation script
   ./scripts/validate-setup.sh
   ```

2. **Test local deployment (optional):**
   ```bash
   # Test staging locally
   cp environments/staging/backend.tf .
   terraform init
   terraform plan -var-file=staging.tfvars
   
   # Clean up local state
   rm backend.tf
   rm -rf .terraform
   ```

3. **Create a test pull request:**
   ```bash
   # Create a feature branch
   git checkout -b test-cicd-pipeline
   
   # Make a small change (e.g., update a tag)
   sed -i 's/Lab          = "lab4-cicd"/Lab          = "lab4-cicd-test"/' staging.tfvars
   
   # Commit and push
   git add staging.tfvars
   git commit -m "test: update staging environment tag"
   git push origin test-cicd-pipeline
   
   # Create PR via GitHub UI or CLI
   # gh pr create --title "Test CI/CD Pipeline" --body "Testing the Terraform CI/CD pipeline"
   ```

4. **Verify pull request workflow:**
   - Check that the plan workflow runs automatically
   - Verify plan results are commented on the PR
   - Ensure both staging and production plans are generated

5. **Test deployment workflow:**
   ```bash
   # Merge the PR (via GitHub UI)
   # This should trigger the apply workflow
   
   # Monitor the deployment
   # 1. Staging should deploy automatically
   # 2. Production should wait for manual approval
   # 3. Approve production deployment in GitHub UI
   ```

## Key Terraform Patterns Demonstrated

### 1. Environment-Specific Backend Configuration
```hcl
# environments/staging/backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-staging"
    storage_account_name = "sttfstatelab4staging"
    container_name       = "tfstate"
    key                  = "staging.tfstate"
  }
}
```

### 2. Variable Validation and Defaults
```hcl
variable "environment" {
  description = "Environment name (staging, production)"
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}
```

### 3. Conditional Resource Creation
```hcl
resource "azurerm_log_analytics_workspace" "main" {
  count = var.enable_monitoring ? 1 : 0
  # Resource configuration...
}
```

### 4. Environment-Specific Resource Sizing
```hcl
resource "azurerm_linux_virtual_machine" "app" {
  size = var.vm_size  # Different sizes per environment
  
  os_disk {
    storage_account_type = var.environment == "production" ? "Premium_LRS" : "Standard_LRS"
  }
}
```

### 5. Dynamic Tagging
```hcl
tags = merge(var.tags, {
  Environment = var.environment
  Purpose     = "application-server"
})
```

## GitHub Actions Patterns

### 1. OIDC Authentication
```yaml
- name: Azure Login via OIDC
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

### 2. Matrix Strategy for Multi-Environment Planning
```yaml
strategy:
  matrix:
    environment: [staging, production]
```

### 3. Environment Protection Rules
```yaml
deploy-production:
  environment: production  # Requires manual approval
  needs: deploy-staging    # Depends on staging success
```

### 4. Artifact Management
```yaml
- name: Upload Plan Artifacts
  uses: actions/upload-artifact@v4
  with:
    name: terraform-plan-${{ matrix.environment }}
    path: |
      ${{ matrix.environment }}.tfplan
      plan_output.txt
```

## Verification and Testing

### Verify Infrastructure Deployment

1. **Check resource groups:**
   ```bash
   # List all resource groups
   az group list --query "[?contains(name, 'terraform-cicd')].{Name:name, Location:location}" --output table
   ```

2. **Test application endpoints:**
   ```bash
   # Get staging VM IP
   STAGING_IP=$(az vm show -d -g rg-terraform-cicd-staging -n vm-terraform-cicd-staging-001 --query publicIps -o tsv)
   echo "Staging: http://$STAGING_IP"
   
   # Test staging endpoint
   curl http://$STAGING_IP
   
   # Get production VM IP  
   PRODUCTION_IP=$(az vm show -d -g rg-terraform-cicd-production -n vm-terraform-cicd-production-001 --query publicIps -o tsv)
   echo "Production: http://$PRODUCTION_IP"
   
   # Test production endpoint
   curl http://$PRODUCTION_IP
   ```

3. **Verify state files:**
   ```bash
   # Check staging state
   az storage blob list \
     --account-name sttfstatelab4staging \
     --container-name tfstate \
     --output table
   
   # Check production state
   az storage blob list \
     --account-name sttfstatelab4production \
     --container-name tfstate \
     --output table
   ```

### Test CI/CD Pipeline Features

1. **Test plan on PR:**
   - Create a feature branch
   - Modify infrastructure (e.g., change VM size)
   - Create pull request
   - Verify plan comment appears

2. **Test deployment workflow:**
   - Merge PR to main
   - Monitor staging deployment (automatic)
   - Approve production deployment
   - Verify both environments updated

3. **Test failure scenarios:**
   - Introduce syntax error in Terraform
   - Verify pipeline fails gracefully
   - Check error reporting in GitHub

## Troubleshooting

### Common Issues and Solutions

#### OIDC Authentication Failures
**Error**: `Error: authentication failed`

**Solution**:
```bash
# Verify federated credentials
az ad app federated-credential list --id $AZURE_CLIENT_ID

# Check GitHub repository secrets
# Ensure AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID are set

# Verify service principal permissions
az role assignment list --assignee $AZURE_CLIENT_ID
```

#### Backend Configuration Issues
**Error**: `Error configuring the backend "azurerm"`

**Solution**:
```bash
# Verify storage account exists
az storage account show --name sttfstatelab4staging --resource-group rg-terraform-state-staging

# Check container exists
az storage container show --name tfstate --account-name sttfstatelab4staging

# Verify permissions
az role assignment list --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/rg-terraform-state-staging"
```

#### Plan/Apply Failures
**Error**: Various Terraform execution errors

**Solution**:
```bash
# Check workflow logs in GitHub Actions
# Verify environment variables are set correctly
# Test locally with same variable files

# Common fixes:
# 1. Update backend storage account names
# 2. Ensure SSH key exists: ssh-keygen -t rsa -b 4096
# 3. Check Azure quotas and limits
# 4. Verify resource naming uniqueness
```

#### Environment Protection Issues
**Error**: Production deployment doesn't wait for approval

**Solution**:
1. Go to Repository Settings → Environments
2. Select `production` environment
3. Add protection rules:
   - Required reviewers
   - Deployment branches restriction
4. Save environment settings

### State Management Best Practices

1. **State Lock Issues:**
   ```bash
   # Check for locks
   az storage blob list --container-name tfstate --account-name STORAGE_ACCOUNT --include u
   
   # Force unlock if needed (use with caution)
   terraform force-unlock LOCK_ID
   ```

2. **State File Backup:**
   ```bash
   # Download current state for backup
   az storage blob download \
     --account-name STORAGE_ACCOUNT \
     --container-name tfstate \
     --name staging.tfstate \
     --file staging.tfstate.backup
   ```

3. **State File Recovery:**
   ```bash
   # Upload state backup if needed
   az storage blob upload \
     --account-name STORAGE_ACCOUNT \
     --container-name tfstate \
     --name staging.tfstate \
     --file staging.tfstate.backup \
     --overwrite
   ```

## Security Best Practices

### 1. Least Privilege Access
- Service Principal has Contributor role only on target subscription
- GitHub environments restrict deployment branches
- Production requires manual approval

### 2. Secret Management
- No long-lived secrets stored in GitHub
- OIDC eliminates need for service principal keys
- Environment-specific backend configurations

### 3. Network Security
- SSH access configurable per environment
- Production restricts SSH to specific IP ranges
- Network Security Groups control traffic flow

### 4. State File Security
- Backend storage accounts use private endpoints (recommended)
- State files encrypted at rest
- Access logging enabled

## Clean Up

When you're ready to clean up the resources:

1. **Destroy via GitHub Actions:**
   - Create a PR with infrastructure changes that remove resources
   - Or manually run terraform destroy in each environment

2. **Manual cleanup:**
   ```bash
   # Destroy production
   cp environments/production/backend.tf .
   terraform init
   terraform destroy -var-file=production.tfvars -auto-approve
   
   # Destroy staging
   cp environments/staging/backend.tf .
   terraform init
   terraform destroy -var-file=staging.tfvars -auto-approve
   
   # Clean up backend storage (optional)
   az group delete --name rg-terraform-state-staging --yes --no-wait
   az group delete --name rg-terraform-state-production --yes --no-wait
   ```

3. **Clean up Azure OIDC configuration:**
   ```bash
   # Remove role assignments
   az role assignment delete --assignee $AZURE_CLIENT_ID
   
   # Delete service principal
   az ad sp delete --id $AZURE_CLIENT_ID
   
   # Delete app registration
   az ad app delete --id $AZURE_CLIENT_ID
   ```

## Key Learning Outcomes

After completing this lab, you'll have mastered:

- ✅ **OpenID Connect (OIDC) Authentication**: Secure, keyless authentication between GitHub Actions and Azure
- ✅ **Multi-Environment CI/CD**: Automated staging deployments with manual production approvals
- ✅ **Infrastructure as Code (IaC) Pipeline**: Plan on PR, apply on merge workflow
- ✅ **Environment Protection**: GitHub environment protection rules and approval gates
- ✅ **State Management**: Separate backends for different environments
- ✅ **Security Best Practices**: Least privilege access, secret management, network security
- ✅ **Automated Testing**: Infrastructure validation and health checks
- ✅ **Error Handling**: Graceful failure handling and rollback capabilities

## Next Steps and Extensions

### Advanced Features to Explore
1. **Drift Detection**: Scheduled workflow to detect infrastructure drift
2. **Cost Estimation**: Integration with Infracost for cost analysis
3. **Policy as Code**: Integration with Azure Policy or OPA Gatekeeper
4. **Integration Testing**: Post-deployment testing with Terratest
5. **Notifications**: Slack/Teams integration for deployment status

### Production Enhancements
1. **Multi-Region Deployments**: Extend to multiple Azure regions
2. **Blue-Green Deployments**: Zero-downtime deployment strategies
3. **Canary Deployments**: Gradual rollout mechanisms
4. **Disaster Recovery**: Automated backup and recovery procedures
5. **Compliance Scanning**: Security and compliance validation

## Additional Resources

- [GitHub Actions for Azure](https://docs.microsoft.com/en-us/azure/developer/github/github-actions)
- [OpenID Connect with Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Backend Configuration](https://www.terraform.io/docs/language/backend/azurerm.html)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)