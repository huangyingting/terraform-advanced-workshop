# Terraform Advanced Workshop

This challenge series maps directly to six advanced Terraform + Azure focus areas: remote state & layered deployment, landing zone foundation with AVM, advanced policy & remediation, production-grade GitHub Actions CI/CD, Terraform quality gates with testing, and import of existing resources.

## Challenges
| Challenge | Title | Core Focus | Key Azure Services |
| --- | ----- | ---------- | ------------------ |
| 1 | [Remote State & Layered Deployment](#challenge-1-remote-state--layered-deployment) | Secure azurerm backend, state locking, versioning, cross-layer data | Storage Account, Resource Group, VNet, Subnets, Linux VM |
| 2 | [Landing Zone Foundation with AVM](#challenge-2-landing-zone-foundation-with-avm) | CAF hierarchy, management groups, multi-subscription networking | Management Groups, Log Analytics, Hub VNet, Firewall (logical) |
| 3 | [Advanced Policy as Code & Remediation](#challenge-3-advanced-policy-as-code--remediation) | Initiative + deployIfNotExists + remediation | Azure Policy (definitions, initiative, assignments), Log Analytics |
| 4 | [Production-Grade GitHub Actions Pipeline](#challenge-4-production-grade-github-actions-cicd-pipeline) | OIDC auth, multi-env plan/apply, approvals | VM, Log Analytics |
| 5 | [Terraform Quality Gate & Release Automation](#challenge-5-terraform-quality-gate--integration-tests) | Module test, lint, security | Terratest, TFLint, Checkov, GitHub Actions |
| 6 | [Import Existing Azure Resources](#challenge-6-import-existing-azure-resources--drift-management) | Declarative & imperative import, drift detection, incremental adoption | Storage, VNet, Subnet, Public IP |
| 7 | [Terraform Cloud + GitHub VCS Workflow](#challenge-7-terraform-cloud--github-vcs-workflow) | Integrate Terraform Cloud (TFC) with a GitHub repository to provision secure Azure infrastructure using remote state | Storage |

---
## Prerequisites
1. Azure Subscription with Contributor (or Owner for management group operations in lab2) rights. ([Create one](https://azure.microsoft.com/free))
2. Azure CLI installed and logged in: `az login`. ([Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli))
3. Terraform >= 1.7 installed. ([Install Terraform](https://developer.hashicorp.com/terraform/install))
4. Git installed and repository cloned locally. ([Download Git](https://git-scm.com/downloads))
5. VS Code ([Download](https://code.visualstudio.com/Download)) with Terraform extension ([HashiCorp Terraform](https://marketplace.visualstudio.com/items?itemName=HashiCorp.terraform)) & (optionally) GitHub Copilot extension ([GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot)).
6. Enable feature flags (if required) for any preview resources you use. ([Preview features overview](https://learn.microsoft.com/azure/azure-resource-manager/management/preview-features))
7. Cost Control: Destroy challenge resources when finished (`terraform destroy`) except shared state RG/storage if reused.

---
## Challenge 1: Remote State & Layered Deployment
### Objective
Implement a production-ready Terraform remote state and layered deployment model that:
- Creates a secure Azure Blob Storage backend for storing terraform state (versioning, soft delete, locking via blob lease).
- Establishes a layered dependency pattern (network layer outputs consumed by application layer).
- Segregates each layer into its own isolated remote state file (e.g., networking, application).
- Uses terraform_remote_state data sources for cross-layer data access (e.g., subnet IDs, NSG names).
- Applies naming + resource group conventions suitable for multi-environment expansion.
- Demonstrates safe change workflows (plan/apply per layer, explicit dependency ordering).
- Ensures state integrity (no hard‑coded IDs; all consumed via outputs or data sources).
- Documents teardown considerations (preserve backend, destroy dependent layers in reverse order).
- Maintains idempotency (repeat apply yields zero changes per layer).

### Success Criteria
- ✅ Azure Blob Storage backend configured with versioning and soft delete
- ✅ State locking implemented using Azure Storage Account blob lease
- ✅ Two independent state files: networking, and application
- ✅ Application layer successfully references networking outputs via remote state
- ✅ Linux VM deployed in subnet created by networking layer
- ✅ Proper resource group and storage account security configurations

#### Resources
- Terraform Deployment with Layered Architecture: https://terrateam.io/blog/terraform-deployment-with-layered-architecture
- Terraform Backends (Azure Storage): https://developer.hashicorp.com/terraform/language/settings/backends/azurerm
- Remote State Data Source: https://developer.hashicorp.com/terraform/language/state/remote-state-data
- Azure Storage security features (soft delete, versioning): https://learn.microsoft.com/azure/storage/blobs/blob-versioning-overview
- Lease (blob) for locking concept: https://learn.microsoft.com/azure/storage/blobs/concurrency-manage-locks
- Naming & conventions (CAF): https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging
- azurerm Provider docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- Useful commands: terraform init / plan / apply / state list / output

For solution, see [Challenge 1 README](solutions/lab1/README.md).

---
## Challenge 2: Landing Zone Foundation with AVM
### Objective
Implement a CAF-aligned multi-subscription Azure Landing Zone that:
- Establishes a management group hierarchy (root, platform, landing-zones, connectivity, management, online/corp).
- Uses Azure Verified Modules (AVM) where possible for standardized, supportable building blocks.
- Configures provider aliases for management and connectivity subscriptions (single plan, multiple contexts).
- Deploys centralized logging and monitoring (Log Analytics workspace, data collection rules, identities).
- Provisions hub networking (hub VNet, Azure Firewall, required subnets, address space segmentation).
- Applies core governance scaffolding (policies/placeholders, role assignments) for future expansion.
- Enables cross-subscription resource references with clear output/remote data patterns.
- Ensures idempotent deployment (repeat terraform apply yields zero changes) with documented dependency ordering.

### Success Criteria
- ✅ Management group hierarchy deployed with CAF-aligned structure (e.g., `alz`, `alz-platform`, `alz-landing-zones`)
- ✅ Azure Landing Zone policies and role definitions properly assigned
- ✅ Log Analytics workspace deployed in management subscription with monitoring solutions
- ✅ Hub virtual network with Azure Firewall deployed in connectivity subscription  
- ✅ Data collection rules for Azure Monitor Agent configured
- ✅ All resources deployed across two subscriptions in a single Terraform plan
- ✅ Proper provider configuration with aliases for multi-subscription deployment

#### Resources
- CAF Landing Zone (management groups): https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/
- Azure Verified Modules (AVM): https://aka.ms/avm
- Management Groups: https://learn.microsoft.com/azure/governance/management-groups/
- Log Analytics Workspace: https://learn.microsoft.com/azure/azure-monitor/logs/
- Azure Firewall overview: https://learn.microsoft.com/azure/firewall/
- Data Collection Rules (AMA): https://learn.microsoft.com/azure/azure-monitor/agents/data-collection-rule-overview
- Provider aliases pattern: https://developer.hashicorp.com/terraform/language/providers/configuration#alias-multiple-provider-configurations
- Cross subscription with azurerm: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/multiple-subscriptions

For solution, see [Challenge 2 README](solutions/lab2/README.md).

---
## Challenge 3: Advanced Policy as Code & Remediation
### Objective
Implement enterprise-grade Azure Policy governance that:
- Authors custom policy definitions for tag enforcement (modify), disk encryption (deny), and Azure Monitor Agent deployment (deployIfNotExists).
- Groups policies into a parameterized initiative (policy set) enabling centralized governance.
- Assigns the initiative at subscription scope with appropriate RBAC (least privilege for remediation identity).
- Automates remediation for missing tags and agent deployment using Terraform-managed remediation tasks.
- Validates enforcement by provisioning intentionally non-compliant test resources and confirming policy effects.
- Structures policies as reusable JSON templates with variable-driven parameters (tag key/value, workspace ID).
- Surfaces compliance and remediation status via Azure CLI / Portal inspection steps.

### Success Criteria
- ✅ Three custom policy definitions implemented (modify tag enforcement, deny unmanaged disk encryption, deployIfNotExists AMA) as versionable JSON templates.
- ✅ Policy initiative (policy set) created with parameterized inputs (tag key, tag value, Log Analytics workspace / AMA target) referencing all definitions.
- ✅ Initiative assigned at subscription scope; assignment includes correct parameter values and creates a system-assigned managed identity.
- ✅ Managed identity granted only required roles (e.g., Monitoring Contributor / Resource Tagging scope) for remediation (least privilege pattern explained).
- ✅ Remediation (tag + AMA) executed: non-compliant resources gain required tag; AMA extension present on targeted VM(s).
- ✅ Disk encryption deny policy blocks creation (or modification) of non-compliant resources (validated by failed attempt).
- ✅ Compliance state visible: az policy state/portal shows resources moving from non-compliant to compliant after remediation.
- ✅ Terraform apply is idempotent: second apply reports zero changes.
- ✅ All policy artifacts (definitions, initiative, assignment, remediation) tracked in Terraform state (no out-of-band changes required).
- ✅ Clear validation commands documented (az policy definition/list, az policy state list, az vm extension list).

#### Resources
- Azure Policy overview: https://learn.microsoft.com/azure/governance/policy/overview
- Policy definition structure: https://learn.microsoft.com/azure/governance/policy/concepts/definition-structure
- Effects (deny / modify / deployIfNotExists): https://learn.microsoft.com/azure/governance/policy/concepts/effects
- Terraform Policy resources: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition
- Initiative (policy set) resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_set_definition
- Policy assignment resource: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_assignment
- Remediation tasks (CLI): https://learn.microsoft.com/azure/governance/policy/how-to/remediate-resources
- Tag governance (CAF): https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging
- Validation commands: az policy definition list, az policy state list, az resource show

For solution, see [Challenge 3 README](solutions/lab3/README.md).

---
## Challenge 4: Production-Grade GitHub Actions CI/CD Pipeline
### Objective
Implement a production-grade multi-environment Terraform deployment pipeline that:
- Authenticates to Azure using GitHub OIDC (no long‑lived client secrets).
- Generates terraform fmt / validate / plan for staging and production on pull requests.
- Provides isolated remote state per environment (staging vs production backends).
- Applies automatically to staging; requires approval (protected environment) for production.
- Uses least-privilege role assignment and environment-scoped federated credentials.
- Surfaces plan output (and failures) early for review before merge.
- Supports controlled promotion: staging apply must succeed before production job unblocks.
- Enables drift detection (re-running plan on main reveals unmanaged changes).
- Ensures reproducibility via pinned action versions and Terraform version pin.

### Success Criteria
- ✅ OIDC authentication configured without long-lived secrets stored in GitHub
- ✅ Automated Terraform plan generation and PR commenting on pull requests
- ✅ Multi-environment deployment with staging (automatic) and production (manual approval)
- ✅ Environment protection rules enforced for production deployments
- ✅ Separate state files and backends for staging and production environments
- ✅ Workflow security best practices implemented (least privilege, secure outputs)
- ✅ Proper error handling and rollback capabilities
- ✅ Infrastructure drift detection and remediation capabilities

#### Resources
- GitHub Actions OIDC with Azure: https://learn.microsoft.com/azure/developer/github/connect-from-azure
- Federated credentials (Entra ID apps): https://learn.microsoft.com/entra/identity-platform/workload-identity-federation
- Terraform Setup Action: https://github.com/hashicorp/setup-terraform
- GitHub Environments & approvals: https://docs.github.com/actions/deployment/targeting-different-environments
- Storing state securely (Azure backend): https://developer.hashicorp.com/terraform/language/settings/backends/azurerm
- Drift detection (plan): https://developer.hashicorp.com/terraform/cli/commands/plan
- Least privilege RBAC guidance: https://learn.microsoft.com/azure/role-based-access-control/best-practices
- Caching in Actions (Terraform plugin cache): https://docs.github.com/actions/using-workflows/caching-dependencies-to-speed-up-workflows

For solution, see [Challenge 4 README](solutions/lab4/README.md).

---
## Challenge 5: Terraform Quality Gate & Integration Tests
### Objective
Implement an end-to-end Terraform quality and testing workflow that:
- Create a Terraform module with an example and Terratest integration tests.
- Enforces formatting, validation, linting, security scanning, and integration tests.
- Uses GitHub Actions OIDC (no client secret) with environment-scoped federated credential.
- Separates module, example, and test concerns (module correctness + example viability + Terratest infra assertions).
- Applies a tunable security severity gate (Checkov) and preserves scan artifacts.
- Demonstrates intentional lint failures (non-blocking) for teaching.

### Success Criteria
- ✅ Terraform fmt/validate pass for module and example.
- ✅ TFLint runs on module and example; a failing directory (tflint-fails) executes without breaking the job (continue-on-error).
- ✅ Checkov produces JUnit + SARIF artifacts uploaded as workflow artifacts.
- ✅ Summarized security findings.
- ✅ Integration tests pass against deployed example infrastructure.
- ✅ All jobs complete with green status when code is compliant and no disallowed severity findings exist.

#### Resources
- Terraform Module best practices: https://developer.hashicorp.com/terraform/language/modules/develop
- Terratest (Go): https://terratest.gruntwork.io
- TFLint: https://github.com/terraform-linters/tflint
- Checkov: https://www.checkov.io
- SARIF upload action: https://docs.github.com/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file
- Testing patterns (infrastructure): https://learn.hashicorp.com/tutorials/terraform/test-infrastructure
- Terraform fmt / validate: https://developer.hashicorp.com/terraform/cli/commands/fmt
- Go testing (Terratest base): https://go.dev/doc/tutorial/add-a-test

For solution, see [Challenge 5 README](solutions/lab5/README.md).

---
## Challenge 6: Import Existing Azure Resources & Drift Management
### Objective
Adopt pre-existing (brownfield) Azure resources into Terraform without recreation by:
- Using Terraform 1.5+ declarative `import {}` blocks to hydrate state before planning.
- Demonstrating legacy `terraform import` CLI for comparison.
- Building accurate Terraform resource blocks matching remote configuration (no destructive diffs).
- Detecting and reconciling drift introduced directly in Azure (e.g., added tags, changed properties).
- Practicing selective adoption (data sources vs managed resources) for phased migration.
- Performing safe state hygiene (remove, re-import, potential module address changes).

### Success Criteria
- ✅ All targeted existing Azure resources (Storage Account, Blob Container, Virtual Network, Subnet, Public IP) imported: `Resources: N imported, 0 added, 0 changed, 0 destroyed` on first apply.
- ✅ Subsequent `terraform plan` shows zero changes (no drift) immediately after import.
- ✅ Intentional drift (e.g., external tag) is surfaced in plan and resolved by updating configuration.
- ✅ Demonstrated both declarative import blocks and imperative `terraform import` usage.
- ✅ Resource group left unmanaged via `data` block (or later converted to managed with import) to illustrate incremental adoption.
- ✅ Ability to remove a resource from state (`terraform state rm`) and re-import it cleanly.

#### Resources
- Terraform Import Blocks: https://developer.hashicorp.com/terraform/language/import
- Imperative Import CLI: https://developer.hashicorp.com/terraform/cli/import
- Drift Detection: https://developer.hashicorp.com/terraform/cli/commands/plan
- State Management: https://developer.hashicorp.com/terraform/cli/state

For solution, see [Challenge 6 README](solutions/lab6/README.md).


---
## Challenge 7: Terraform Cloud + GitHub VCS Workflow
### Objective
Integrate Terraform Cloud (TFC) with GitHub for a remote execution workflow that:
- Uses a VCS-driven TFC workspace (working directory `solutions/lab7`).
- Leverages Azure OIDC (federated workload identity) – no client secrets.
- Stores state remotely in Terraform Cloud (not Azure Storage for this lab) with run tasks / policy hooks ready.
- Differentiates plan vs apply phases via distinct federated credentials (subject includes `run_phase`).
- Manages sensitive vs non-sensitive variables appropriately (env vars for auth, TF vars for config).
- Auto-generates a globally unique storage account name (random suffix) while remaining idempotent.
- Supports speculative plans on pull requests and applies on main merges.
- Provides a pattern for attaching cost/security run tasks or Sentinel policies.

### Success Criteria
- ✅ TFC workspace connected to repo and directory `solutions/lab7` (remote execution, VCS workflow).
- ✅ Azure federated credentials created for both plan and apply phases (two subjects with `run_phase`).
- ✅ Environment variables set in TFC: `TFC_AZURE_PROVIDER_AUTH`, `TFC_AZURE_RUN_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` (and no client secret required).
- ✅ Successful speculative plan on a PR (no apply) and successful apply after merge (auto or manual depending on configuration).
- ✅ State visible in Terraform Cloud with correct outputs (resource group + storage account names).
- ✅ Randomized storage account suffix produced when `storage_account_suffix` unspecified (consistent across runs in workspace).
- ✅ Idempotent re-apply yields zero changes.
- ✅ (Optional) Run task or placeholder Sentinel policy ready / documented.

### Resources
- Terraform Cloud VCS Workflows: https://developer.hashicorp.com/terraform/cloud-docs/workspaces/vcs
- AzureRM Provider OIDC Auth: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc
- Workload Identity Federation (Azure AD): https://learn.microsoft.com/entra/identity-platform/workload-identity-federation
- Terraform Cloud Run Tasks: https://developer.hashicorp.com/terraform/cloud-docs/run-tasks
- Sentinel Policies Overview: https://developer.hashicorp.com/terraform/cloud-docs/policy-enforcement
- Random Provider: https://registry.terraform.io/providers/hashicorp/random/latest/docs

For solution, see [Challenge 7 README](solutions/lab7/README.md).

