# Lab 8 Solution: Advanced Policy as Code & Remediation

Implements two custom policies (required tag modify + AMA deployIfNotExists) bundled into an initiative and assigned at subscription scope.

## Files
- `policies/require-tag.json` – Modify policy to enforce tag.
- `policies/ensure-ama.json` – deployIfNotExists AMA extension (simplified template placeholder).
- `main.tf` – Terraform definitions and assignment.

## Usage
```
terraform init
terraform apply
```

## Validate
1. Create VM without tag; after assignment remediation (portal or auto), tag appears.
2. Extension AMA installed (may require remediation trigger depending on policy timing).

## Cleanup
`terraform destroy`
