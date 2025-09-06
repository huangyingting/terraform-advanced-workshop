# Lab 7 Solution: Multi-Region Active/Passive DR

This folder provides a simplified demonstration of deploying identical App Services in two regions and wiring them behind Azure Traffic Manager for priority-based failover.

## Files
- `main.tf` – Core Terraform for RGs, service plans, web apps, and Traffic Manager profile/endpoints.

## Usage
```
terraform init
terraform plan
terraform apply
```

## Test Failover
1. Record FQDN output.
2. Stop (or scale to zero via configuration) primary web app.
3. Curl FQDN until response comes from secondary (check REGION_ROLE env var via custom endpoint if added).

## Cleanup
`terraform destroy`
