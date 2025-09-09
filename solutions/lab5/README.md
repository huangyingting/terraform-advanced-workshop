# Lab 5 – Terraform Quality Gate, Azure OIDC, and Terratest

## Overview
This lab demonstrates a practical Terraform delivery pipeline featuring:
- GitHub Actions OpenID Connect (OIDC) federation to Azure (no static secrets)
- Layered quality gate: fmt, validate, TFLint, Checkov (security / misconfig scanning)
- Severity-based enforcement (configurable threshold)
- Integration tests with Terratest (Go) against Azure using ephemeral auth
- Environment-scoped federated identity + repo environment secrets

You will configure Azure + GitHub, observe pipeline behavior, and tune quality criteria.

## Prerequisites
- Azure subscription Owner or User Access Administrator (for role assignment)
- Tools installed locally:
  - Azure CLI (az) logged in: az login
  - GitHub CLI (gh) authenticated: gh auth login
  - Bash shell
- Repository cloned locally
- Environment variables (export before running script):
  - GITHUB_REPO="your-org/your-repo"
  - (Optional) APP_NAME="custom-app-reg-name" (defaults to github-terraform-cicd)
- Network access to Azure AD + GitHub APIs
- Permissions to create:
  - App registration + service principal
  - Federated credentials
  - Role assignment (Contributor)
  - GitHub environment + secrets

## Step-by-Step Instructions
1. Clone and position  
   git clone <repo>  
   cd terraform-advanced-workshop/solutions/lab5
2. Set required environment variable  
   export GITHUB_REPO="org/repo"
3. (Optional) Override app name  
   export APP_NAME="lab5-oidc-app"
4. Run the OIDC bootstrap script  
   ./prepare.sh  
   What it does:  
   - Creates (or reuses) Azure AD App Registration + Service Principal  
   - Adds federated credential (subject: repo:ORG/REPO:environment:development)  
   - Assigns Contributor at subscription scope  
   - Ensures GitHub environment 'development' exists and injects secrets:  
     AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
5. Verify Azure objects (optional)  
   az ad app show --id "$APP_NAME" --query "{appId:appId, displayName:displayName}"  
   az role assignment list --assignee "$APP_ID" --query "[].roleDefinitionName"
6. Commit / push any changes to solutions/lab5/** (branches: main or develop) to trigger the workflow.
7. Observe workflow jobs (GitHub Actions → Lab 5 Terraform Quality Gate & Integration Tests):  
   Job: quality-gate  
   - terraform fmt -check (module + example)  
   - terraform init / validate (module + example)  
   - TFLint (module, example, a failing sample folder non-blocking)  
   - Checkov security scan -> JUnit + SARIF artifacts uploaded  
   - Severity gating: fails if any finding >= CHECKOV_SEVERITY_THRESHOLD (default MEDIUM)  
   Job: terratest (only on push/workflow_dispatch, not PR)  
   - go mod tidy / download  
   - go test -v -timeout 30m (launches infra, validates, tears down)
8. Adjust security threshold (optional)  
   Edit .github/workflows/lab5-ci.yml: CHECKOV_SEVERITY_THRESHOLD: HIGH (example)  
   Commit → observe pass/fail changes.
9. Add a deliberate misconfiguration (e.g., open firewall) → confirm Checkov blocks at threshold.
10. Explore artifacts  
    - Actions → specific run → Artifacts → checkov-results (download SARIF, view counts in summary)
11. Iterate: fix issues, push again until both jobs pass.
12. (Optional) Add another federated environment (e.g., staging) by replicating the loop in prepare.sh.

## Key Learning Outcomes
- Implement GitHub → Azure OIDC without client secrets
- Enforce Terraform style, validation, linting early
- Apply security-as-code with Checkov + severity gating
- Structure multi-folder (modules/examples) validation
- Run Terratest for integration confidence
- Interpret SARIF outputs and summarize security posture
- Parameterize pipeline (versions, thresholds) via env vars

## Questions
1. Which failures should block delivery: style, lint, security, or tests—and why?  
2. How would you shift from subscription-wide Contributor to least privilege?  
3. What is the risk of setting CHECKOV_SEVERITY_THRESHOLD=CRITICAL?  
4. How could you parallelize lint + security to reduce runtime?  
5. How would you extend Terratest to validate idempotency or drift?  
6. What metrics would you surface to leadership from this pipeline?  
7. How might adding a policy-as-code layer (OPA/Conftest) change the workflow?

## Additional Resources
- Terraform CLI docs: https://developer.hashicorp.com/terraform/cli
- TFLint: https://github.com/terraform-linters/tflint
- Checkov policies: https://www.checkov.io
- Terratest: https://terratest.gruntwork.io
- GitHub OIDC guide: https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- Azure federated credentials: https://learn.microsoft.com/azure/active-directory/develop/workload-identity-federation
- SARIF viewer (VS Code extension) for local analysis

