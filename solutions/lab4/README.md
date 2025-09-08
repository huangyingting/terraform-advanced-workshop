## Overview

The primary goal of Lab 4 is to implement secure, environment-aware GitHub Actions workflows for Terraform: validating Pull Requests (plan only), promoting approved changes to staging, and then deploying to production with OpenID Connect (OIDC) – all without storing long‑lived cloud credentials. The infrastructure code (VNet, VM, NSG, optional monitoring) exists mainly to give the workflows something realistic to manage.

Core themes:
* GitHub OIDC federation (no secrets) via automated bootstrap (`prepare.sh`)
* Environment separation (staging vs production) using `.tfvars` + distinct remote state backends
* PR feedback loop (plan surfaced in workflow logs / PR comments)
* Promotion mechanics (merge to main triggers staging apply; protected production environment triggers prod apply)
* Conditional features (monitoring on only in production)
* Traceability through outputs and tagging strategy

You will leave this lab with a pattern you can generalize to multi-stage Terraform delivery pipelines.

## Prerequisites

* Azure Subscription with rights to create RBAC role assignments & AD app registrations
* Logged in locally: `az login`
* GitHub CLI authenticated: `gh auth login`
* Terraform >= 1.5 (tested with >=1.6 recommended)
* Bash (for `prepare.sh`)
* SSH client (for VM access)
* Existing (or willingness to create) GitHub repository (`GITHUB_REPO` environment variable)

Optional but recommended:
* Existing `~/.ssh/id_rsa.pub` (script will generate a key if absent)
* Separate Azure subscription or clear naming to avoid collisions

## Step-by-Step Instructions

### 1. Bootstrap Azure + GitHub (One-Time)
Run the helper script to create the Azure AD application, federated credentials, storage accounts for remote state, GitHub environments, and required secrets:
```
export GITHUB_REPO="<org>/<repo>"
./prepare.sh
```
Outputs include: Client ID, Tenant ID, Subscription ID, storage account names, environment confirmation.

#### Post-Bootstrap Required Manual Governance Steps
Immediately after running `./prepare.sh`, configure repository governance so workflows enforce proper review & approval:

1. Protect the `main` branch (Settings → Branches → Add rule):
	* Require a pull request before merging → Require approvals
	* Dismiss stale pull request approvals when new commits are pushed (optional but recommended)
2. Configure Environment protection:
	* Go to Settings → Environments → `staging` → Require reviewers → add at least one team/user
	* Repeat for `production` (typically stricter: 2 reviewers or a specific ops/security group)
	* (Optional) Add wait timer for `production` to introduce a controlled pause
3. (Optional) Enable required secret scanning / dependency alerts for defense-in-depth.
4. Test by opening a PR: verify direct push to `main` is blocked and plan workflow comment appears.

Result: merges cannot bypass plan visibility, and production deploys require explicit human approval via the protected environment gate.

### 2. Workflow Overview (Actual Files)
| Purpose | File | Trigger | Key Actions | Notes |
|---------|------|---------|-------------|-------|
| Pull Request planning (both envs) | `.github/workflows/lab4-plan.yml` | `pull_request` to `main`, manual dispatch | Matrix over `staging, production`; `fmt`, `validate`, dual `plan`, summarize + PR comment | Produces artifacts & rich PR comment |
| Continuous deployment (staging → production) | `.github/workflows/lab4-apply.yml` | `push` to `main`, manual dispatch | Staging plan/apply then production plan/apply (if staging succeeded) | Skips apply when plan exit code = 0 |
| Selective destroy | `.github/workflows/lab4-destory.yml` | Manual dispatch with inputs | Safety confirm, plan-destroy + apply per env | Typo in filename (`destory`) kept intentionally |

### 3. Workflow Deep Dive
#### `lab4-plan.yml`
* Runs for PRs touching lab4 Terraform or workflow files.
* Matrix executes `plan` for `staging` and `production` using corresponding `*.tfvars`.
* Generates markdown summaries (`plan_summary_<env>.md`) and comments (updates in place if re-run).
* Exit code handling: 0 = no changes, 2 = changes, 1 = failure (fails job).

#### `lab4-apply.yml`
* Trigger: merge (push to `main`) or manual dispatch.
* Staging job: init → plan → conditional apply → output capture → optional HTTP health check.
* Production job waits for staging success, repeats pattern with `production.tfvars`.
* Artifacts: state snapshot (`post-apply-*.tfstate`) + JSON outputs.

#### `lab4-destory.yml`
* Manual only; requires `environment` selection and `DESTROY` confirmation string.
* Plans destruction; only applies when exit code 2 (resources exist).
* Runs staging before production when `all` selected.

### 4. Environment Config & Promotion Logic
Two `.tfvars` files drive differences:
* `staging.tfvars` – low cost footprint, monitoring disabled
* `production.tfvars` – higher spec VM, monitoring enabled, longer retention

Promotion flow implemented:
1. PR → `lab4-plan.yml` (visibility only)
2. Merge → `lab4-apply.yml` (staging apply, then production apply)
3. Optional manual `workflow_dispatch` for re-deploy or `lab4-destory.yml` for teardown

### 5. Local Debugging (Optional)
You can still run locally if needed:
```
terraform init -backend-config="resource_group_name=<staging backend RG>" \
	-backend-config="storage_account_name=<staging sa>" \
	-backend-config="container_name=tfstate" \
	-backend-config="key=staging.tfstate"

terraform plan -var-file=staging.tfvars
```

### 6. Accessing the Deployed VM
After staging or production apply completes, retrieve the suggested SSH command from workflow logs or locally via:
```
terraform output -raw ssh_connection_command
```
Ensure your public key existed before apply or manage keys centrally in real scenarios.

### 7. Cleaning Up (Pipelines or Local)
Trigger destroy workflows (if you author them) or run locally per environment:
```
terraform destroy -var-file=staging.tfvars
terraform destroy -var-file=production.tfvars
```

### 8. Extending the Pipeline (Ideas)
* Add a security scan stage (tfsec / checkov) in PR workflow
* Generate and upload cost estimate (Infracost) on PRs
* Emit structured outputs to an artifact for downstream release notes
* Introduce drift detection via a scheduled plan workflow

## Key Learning Outcomes

* Implement GitHub Actions based Terraform delivery (PR plan → staging apply → production apply)
* Use OIDC to remove static cloud credentials from CI
* Structure environment promotion with minimal duplication
* Apply conditional resource strategies (cost vs capability) per environment
* Capture and surface Terraform plan & outputs for observability
* Prepare a foundation for adding security, cost, and drift checks

## Questions

1. How will you enforce policy (e.g., tag, security, cost) gates in PR before merge?
2. What criteria should trigger an automated production deployment vs a manual approval?
3. How could you standardize backend + var file selection to avoid copy/paste in workflows?
4. Where would you store and version workflow templates for reuse across repos?
5. How will you surface Terraform drift or failed applies to stakeholders (chat ops, dashboards)?
6. What additional compliance or security scanners would you insert into the PR pipeline?
7. How could you integrate cost estimation to block unexpectedly expensive changes?

## Additional Resources

* Terraform Docs – Conditional Expressions: https://developer.hashicorp.com/terraform/language/expressions/conditionals
* Terraform Docs – Input Variables & Validation: https://developer.hashicorp.com/terraform/language/values/variables
* AzureRM Provider Docs (azurerm_linux_virtual_machine): https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
* Azure AD OIDC for GitHub Actions: https://learn.microsoft.com/azure/developer/github/connect-from-azure
* Log Analytics Workspace Overview: https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview
* Azure Networking Concepts: https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview