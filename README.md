# Hands-On Labs: Enterprise Azure with Terraform

This lab series maps directly to the six advanced course modules. Each lab is self‑contained, builds real Azure artifacts, and reinforces enterprise patterns (layered architecture, landing zones with AVM, hybrid management, DevSecOps CI/CD, security & governance, brownfield + AI enablement).

## Lab Index
| Lab | Title | Core Focus | Key Azure Services | GitHub / Tooling Focus |
| --- | ----- | ---------- | ------------------ | ---------------------- |
| lab1 | Remote State & Layered Architecture | Secure azurerm backend, state locking, versioning, cross-layer data | Storage Account, Resource Group, VNet, Subnets, Linux VM | Basic workflow: init/plan/apply locally |
| lab2 | Landing Zone Foundation with AVM | CAF hierarchy, management groups, multi-subscription networking | Management Groups, Log Analytics, Hub VNet, Firewall (logical) | Module composition & multi-provider patterns |
| lab3 | Production-Grade GitHub Actions Pipeline | OIDC auth, multi-env plan/apply, approvals | (Reuses lab1 infra) | GitHub Actions (plan/apply workflows) |
| lab5 | DevSecOps Hardening | Key Vault secret consumption, Policy as Code, static analysis | Key Vault, Azure Policy, VM, Storage | Checkov, TFLint integration |
| lab6 | Brownfield Import & AI Acceleration | terraform import workflow, Copilot improvements | Existing VNet, App Service Plan/Web App | GitHub Copilot usage & review |
| lab7 | Multi-Region Active/Passive DR | Region-paired infra, failover orchestration | Front Door/Traffic Manager, Storage (RA-GRS), App Service/VM, SQL Failover Group | Regional modules, conditional deploy, health check script |
| lab8 | Advanced Policy as Code & Remediation | Initiative + deployIfNotExists + remediation | Azure Policy (definitions, initiative, assignments), Log Analytics | Policy graph, remediation tasks via Terraform |
| lab9 | Private Network Zero-Trust Layer | Fully private PaaS + controlled egress | Private Endpoints, Private DNS, Firewall, Route Tables, NSGs, Key Vault, Storage | For_each endpoint map, network dependency mgmt |
| lab10 | Terraform Module Quality Gate & Release Automation | Module test, lint, security & semantic release | Terratest, TFLint, Checkov, GitHub Actions, Tags | Automated quality gates & version tagging |

---
## Global Prerequisites (Before Any Lab)
1. Azure Subscription with Contributor (or Owner for management group operations in lab2) rights.
2. Azure CLI installed and logged in: `az login`.
3. Terraform >= 1.7 installed.
4. Git installed and repository cloned locally.
5. VS Code with Terraform & (optionally) GitHub Copilot extensions.
6. Environment variables (adjust naming):
   - `export TF_VAR_location="southeastasia"`
   - `export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)`
   - For multi-subscription in lab2: set `MGMT_SUB_ID` and `CONN_SUB_ID` if distinct.
7. Enable feature flags (if required) for any preview resources you use.

> Cost Control: Destroy lab resources when finished (`terraform destroy`) except shared state RG/storage if reused.

---
## Lab 1: Remote State & Layered Architecture
### Objective
Implement a production-ready Terraform remote state backend using Azure Blob Storage with state locking and versioning, then design a layered infrastructure architecture with separate state files for networking and application tiers that share data via `terraform_remote_state` data sources.

### Key Learning Outcomes
- Configure secure Azure Blob Storage remote backend with state locking
- Implement Terraform workspace and state file isolation strategies
- Design and implement layered infrastructure architecture
- Share data between Terraform configurations using remote state data sources
- Apply enterprise-grade state management and dependency patterns

### Architecture
```
Foundation Layer (Backend) → Networking Layer → Application Layer
     ↓                           ↓                    ↓
State Storage Setup    →    VNet, Subnets, NSG   →   VM, Data Disks
(backend.tfstate)          (networking.tfstate)     (application.tfstate)
```

### Prerequisites
- Azure CLI authenticated with Contributor permissions
- Terraform >= 1.7 installed
- Ability to create storage accounts and assign RBAC roles
- Basic understanding of Terraform state concepts

### Success Criteria
- ✅ Secure Azure Blob Storage backend configured with versioning and soft delete
- ✅ State locking implemented using Azure Storage Account blob lease
- ✅ Three independent state files: backend, networking, and application
- ✅ Application layer successfully references networking outputs via remote state
- ✅ Linux VM deployed in subnet created by networking layer
- ✅ Proper resource group and storage account security configurations

For detailed step-by-step instructions, see [Lab 1 README](solutions/lab1/README.md).

---
## Lab 2: Landing Zone Foundation with AVM
### Objective
Deploy a Cloud Adoption Framework (CAF) compliant Azure Landing Zone using Azure Verified Modules (AVM) with proper management group hierarchy, centralized logging, and hub networking across multiple subscriptions using advanced Terraform provider patterns.

### Key Learning Outcomes
- Implement multi-subscription Terraform deployments with provider aliases
- Deploy Azure Landing Zone foundation using Azure Verified Modules
- Configure management group hierarchy with policies and governance
- Set up centralized logging and monitoring infrastructure
- Deploy hub networking with Azure Firewall for secure connectivity

### Prerequisites
- Tenant-level Management Group write permissions (Owner or User Access Administrator role)
- Two Azure subscription IDs (management and connectivity subscriptions)
- Azure CLI authenticated with appropriate permissions
- Terraform >= 1.7 installed
- Required Azure providers registered

### Success Criteria
- ✅ Management group hierarchy deployed with CAF-aligned structure (e.g., `alz`, `alz-platform`, `alz-landing-zones`)
- ✅ Azure Landing Zone policies and role definitions properly assigned
- ✅ Log Analytics workspace deployed in management subscription with monitoring solutions
- ✅ Hub virtual network with Azure Firewall deployed in connectivity subscription  
- ✅ Data collection rules for Azure Monitor Agent configured
- ✅ All resources deployed across two subscriptions in a single Terraform plan
- ✅ Proper provider configuration with aliases for multi-subscription deployment

For detailed step-by-step instructions, see [Lab 2 README](solutions/lab2/README.md).

---
## Lab 3: Production-Grade GitHub Actions CI/CD Pipeline
### Objective
Implement a production-ready CI/CD pipeline for Terraform using GitHub Actions with OpenID Connect (OIDC) authentication, automated planning on pull requests, multi-environment deployments with approval gates, and secure state management across staging and production environments.

### Key Learning Outcomes
- Configure OpenID Connect (OIDC) authentication between GitHub Actions and Azure
- Implement automated Terraform plan generation and PR commenting
- Design multi-environment deployment workflows with approval controls
- Set up environment protection rules and deployment gates
- Apply Infrastructure as Code (IaC) best practices in CI/CD pipelines
- Implement secure secret management without long-lived credentials

### Architecture
```
GitHub Repository
    ↓
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Workflows                   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┤
│  │                    PR Workflow                              │
│  │  Trigger: pull_request → branches: [main]                  │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │  1. Checkout Code                                       │
│  │  │  2. Azure OIDC Login                                    │
│  │  │  3. Terraform Setup                                     │
│  │  │  4. Format Check                                        │
│  │  │  5. Validate                                            │
│  │  │  6. Plan (staging & prod)                               │
│  │  │  7. Comment Plan on PR                                  │
│  │  └─────────────────────────────────────────────────────────┘
│  └─────────────────────────────────────────────────────────────┘
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┤
│  │                 Deploy Workflow                             │
│  │  Trigger: push → branches: [main]                          │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │              Staging Job                                │
│  │  │  1. Checkout & Setup                                    │
│  │  │  2. Azure OIDC Login                                    │
│  │  │  3. Terraform Plan                                      │
│  │  │  4. Terraform Apply (Auto)                              │
│  │  └─────────────────────────────────────────────────────────┘
│  │                      ↓                                     │
│  │  ┌─────────────────────────────────────────────────────────┤
│  │  │             Production Job                              │
│  │  │  Depends on: staging                                    │
│  │  │  Environment: production (protected)                    │
│  │  │  ┌─────────────────────────────────────────────────────┤
│  │  │  │  → Manual Approval Required ←                       │
│  │  │  │  1. Checkout & Setup                                │
│  │  │  │  2. Azure OIDC Login                                │
│  │  │  │  3. Terraform Plan                                  │
│  │  │  │  4. Terraform Apply                                 │
│  │  │  └─────────────────────────────────────────────────────┘
│  │  └─────────────────────────────────────────────────────────┘
│  └─────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
                                 ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Azure Environment                         │
│  ┌─────────────────────────────────────────────────────────────┤
│  │  Microsoft Entra ID (Azure AD)                             │
│  │  ├── App Registration: github-actions-terraform            │
│  │  ├── Federated Credentials: repo-branch-main               │
│  │  ├── Federated Credentials: repo-pull-request              │
│  │  └── Service Principal: with Contributor role              │
│  └─────────────────────────────────────────────────────────────┘
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┤
│  │  Azure Subscription                                        │
│  │  ├── Staging Environment (rg-terraform-staging)            │
│  │  │   ├── Storage Account: staging backend                  │
│  │  │   └── Application Resources                             │
│  │  └── Production Environment (rg-terraform-production)      │
│  │      ├── Storage Account: production backend               │
│  │      └── Application Resources                             │
│  └─────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
```

### Prerequisites
- **GitHub Repository**: Personal or organization repository with Actions enabled
- **Azure Permissions**: Contributor or Owner role on target subscription
- **Azure CLI**: Installed and authenticated for initial setup
- **Microsoft Entra ID**: Permissions to create App Registrations and assign roles
- **GitHub Secrets**: Repository or environment-level secrets configuration
- **Basic Terraform Knowledge**: Understanding of state management and backends

### Success Criteria
- ✅ OIDC authentication configured without long-lived secrets stored in GitHub
- ✅ Automated Terraform plan generation and PR commenting on pull requests
- ✅ Multi-environment deployment with staging (automatic) and production (manual approval)
- ✅ Environment protection rules enforced for production deployments
- ✅ Separate state files and backends for staging and production environments
- ✅ Workflow security best practices implemented (least privilege, secure outputs)
- ✅ Proper error handling and rollback capabilities
- ✅ Infrastructure drift detection and remediation capabilities

For detailed step-by-step instructions, see [Lab 3 README](solutions/lab3/README.md).

---
## Lab 5: DevSecOps Hardening (Key Vault, Policy, Static Analysis)
### Objective
Integrate secret retrieval, static analysis, and Policy as Code into existing pipeline.

### Prerequisites
- Existing pipeline from lab4.
- Key Vault with secret `vm-admin-password`.

### Steps
1. Add Key Vault data source in VM module: `data "azurerm_key_vault_secret" "vm_pwd" {...}` and use value in resource.
2. Add `policy.tf`: create restricted VM size policy + subscription assignment.
3. Update `plan.yml` to add steps:
   - Install TFLint (optional) & run.
   - Run Checkov action; fail on high severity.
4. Introduce an intentional violation (e.g., disallowed VM size) to see policy block during apply.
5. Fix violation; re-run.

### Success Criteria
- Checkov fails insecure config; passes after fix.
- Policy denies non-compliant SKU during apply.
- Secret never committed in repo; pulled at runtime only.

---
## Lab 6: Brownfield Import & AI Acceleration
### Objective
Import an existing manually-created VNet and then use GitHub Copilot to scaffold App Service with slot, applying best-practice hardening.

### Prerequisites
- Manually created VNet with custom DNS.
- Copilot extension enabled.

### Steps
1. Manually create VNet (Portal or CLI) capturing its resource ID.
2. Write minimal resource block in `main.tf` for that VNet.
3. Run `terraform import azurerm_virtual_network.imported_vnet <resourceId>`.
4. Run `terraform plan`; note large diff.
5. Iteratively fill missing arguments (especially `dns_servers`) until plan shows no changes.
6. New file `app_service.tf`: comment describing desired infra; accept Copilot suggestions.
7. Review AI code: add `https_only = true`, disable FTP, add tags, ensure SKU appropriate.
8. Plan & apply; verify slot exists.

### Success Criteria
- Imported VNet managed with zero-diff plan.
- App Service & slot deployed with security best practices.
- Documented improvements vs raw AI suggestion.

---
## Reusable Folder Layout (Suggested)
```
labs/
  lab1/ ... (see solution folders)
  lab2/
  lab3/
  lab4/.github/workflows/...
  lab5/policy.tf etc.
  lab6/app_service.tf
```

## Cleanup Guidance
For each lab: run `terraform destroy` in that lab's root directory. For shared state storage, retain if needed for later labs; otherwise delete RG when all labs complete.

## Next Steps / Extensions
- Add automated drift detection workflow (nightly `terraform plan -detailed-exitcode`).
- Introduce integration tests (e.g., Terratest or kitchen-terraform) post-apply.
- Add cost estimation (infracost) to PR pipeline.
- Expand Arc lab to include Kubernetes + Flux configuration deployment.

---
Generated: Initial version; adapt subscription IDs, naming conventions, and module versions per your environment.

---
## Lab 7: Multi-Region Active/Passive DR
### Objective
Design and deploy an active (primary) + passive (secondary) regional topology with Terraform, enabling controlled failover for a stateless web tier and stateful data tier.

### Prerequisites
- Two Azure regions selected (e.g., `southeastasia` primary, `eastasia` secondary).
- RA-GRS or GRS capable storage SKU usage allowed.
- (Optional) Azure SQL logical servers in both regions for failover group.

### Architecture
Primary region: App Service (or VM scale set) + Storage (primary) + SQL primary.
Secondary region: Warm standby App Service (slot off or scaled to minimum) + Storage secondary (replicated) + SQL secondary.
Global routing: Azure Front Door (recommended) or Traffic Manager priority routing.

### Steps
1. Variables: define `primary_region`, `secondary_region`, maps for naming.
2. Create resource group modules invoked twice (for_each over region map) producing RG ids.
3. Storage: create one RA-GRS account in primary; replication handled automatically (no account in secondary) – output secondary endpoint.
4. SQL (optional): create logical servers in both regions + database + failover group resource referencing both servers.
5. App Service Plan + Web App in primary; scaled-down plan + Web App in secondary region.
6. Front Door Standard/Premium: backend pool includes both web endpoints with priority (primary=1, secondary=2) + health probe path `/healthz`.
7. Outputs: active endpoint, secondary endpoint, failover instructions.
8. Failover Test (manual or script): temporarily stop primary web or change probe; confirm Front Door routes traffic to secondary.

### Terraform Focus
- Regional abstractions using `for_each` for RG and compute layers.
- Conditional creation (`count` or `for_each`) for secondary tier sizing (different SKU).
- Data source / outputs for Front Door backend hostnames.

### Validation
- `curl` primary Front Door endpoint healthy.
- Simulate failure -> traffic served from secondary (HTTP header / tag indicates region).

### Success Criteria
- Front Door reports healthy both; failover occurs automatically on primary disruption.

---
## Lab 8: Advanced Policy as Code & Remediation
### Objective
Author custom policies + initiative (policy set), assign with parameters, enable deployIfNotExists remediation, trigger remediation tasks via Terraform.

### Prerequisites
- Subscription Owner or Policy Contributor rights.
- Existing Log Analytics workspace id (for agent deployment example) or create as part of lab.

### Policy Set
1. Custom policy: Require specific tags (e.g., `cost-center`). Effect: `modify` to append if missing.
2. Custom policy: Enforce disk encryption (deny if not enabled).
3. deployIfNotExists policy: Ensure Azure Monitor Agent installed on Linux VMs.
4. Initiative groups the above with parameters (tag key, tag value).

### Steps
1. Create `policies/` directory: definition JSON templates.
2. Terraform resources:
   - `azurerm_policy_definition` (three definitions).
   - `azurerm_policy_set_definition` linking them.
   - `azurerm_subscription_policy_assignment` with parameters (tag value) + `enforcement_mode = true`.
3. Remediation: use `azurerm_policy_remediation` (if available) OR `azapi_resource` to invoke remediation for the initiative.
4. Create a non-compliant VM (missing tag, no AMA) in test RG.
5. Run apply; observe remediation task creation.
6. Re-plan to confirm drift removed (tags auto-added, extension installed).

### Terraform Focus
- Template files with `file()` function for policy rule JSON.
- Parameterization and initiative composition.
- Remediation orchestration as code.

### Validation
- Policy compliance in Portal shows resources compliant post-remediation.
- VM has required tag and AMA extension after remediation completes.

### Success Criteria
- Initiative deployed + remediation executed without manual portal actions.

---
## Lab 9: Private Network Zero-Trust Layer
### Objective
Convert public PaaS access to private-only with controlled outbound egress through Azure Firewall and private DNS resolution.

### Prerequisites
- Existing hub/spoke VNet model (reuse from previous labs or create minimal hub + workload VNet).
- Contributor on network & security resources.

### Components
- Private Endpoints for: Storage, Key Vault, Container Registry.
- Private DNS Zones: `privatelink.vaultcore.azure.net`, `privatelink.blob.core.windows.net`, `privatelink.azurecr.io` linked to VNets.
- Azure Firewall with DNAT rules only for required inbound (optional) and application rules for allowed egress.
- Route tables forcing 0.0.0.0/0 through Firewall on subnets.

### Steps
1. Variables: list/map of services requiring private endpoints.
2. Create or import VNets + subnets (data source or resources).
3. Deploy Firewall (standard or premium) + public IP.
4. Create route tables and associate with workload subnets.
5. For each service in map: create private endpoint + zone group; create/if-not-exists matching private DNS zone + VNet link.
6. Disable public network access on PaaS resources (Key Vault, Storage, ACR) via resource arguments.
7. Optional: Diagnostic settings for network resources.

### Terraform Focus
- `for_each` over endpoint definitions.
- Handling implicit dependencies (private endpoint before disabling public access) via ordering or `depends_on`.
- Reusable module for private endpoint creation.

### Validation
- `nslookup <storageaccount>.blob.core.windows.net` resolves to private IP inside VNet.
- Public access attempts from outside network fail.
- Outbound traffic restricted (deny unspecified domains if using Firewall FQDN rules).

### Success Criteria
- All targeted services reachable only via private endpoints; no public access.

---
## Lab 10: Terraform Module Quality Gate & Release Automation
### Objective
Establish a reusable Terraform module with automated tests, linting, security scan, semantic version tagging, and release notes generation.

### Prerequisites
- GitHub repository with Actions enabled.
- Go toolchain (for Terratest) available in workflow runners.

### Module Structure
```
modules/
  web_app/
    main.tf
    variables.tf
    outputs.tf
    README.md
examples/
  basic/
    main.tf
```

### Steps
1. Implement module (e.g., App Service + optional slot) with input variables (name, location, sku, tags).
2. Write example usage under `examples/basic`.
3. Add tests: `tests/web_app_test.go` using Terratest to init/plan and assert output naming patterns.
4. GitHub Actions workflow `ci.yml`:
   - tflint + terraform fmt + validate
   - terraform init/plan on example
   - run Checkov
   - run Terratest (go test ./tests -timeout 30m)
5. On tag push `v*.*.*` run release workflow:
   - Re-run tests
   - Generate CHANGELOG (e.g., conventional commits parser action)
   - Create GitHub Release attaching plan artifact and changelog.
6. Add semantic version bump workflow (manual dispatch or commit message driven) that calculates next version and creates tag.

### Terraform Focus
- Module input validation (variable `validation` blocks), version constraints, defensive outputs.
- Example-driven test harness with Terratest.

### Validation
- PR must pass all quality gates before merge.
- Creating a tag `v0.1.0` auto-produces release with changelog + test pass.

### Success Criteria
- Fully automated module pipeline; failed gate blocks release.

