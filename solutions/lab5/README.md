# Lab 10 Solution: Terraform Module Quality Gate & Release Automation

Demonstrates a simple module (`modules/web_app`) with example usage, Terratest, and CI workflow.

## Structure
- `modules/web_app` – Reusable module
- `examples/basic` – Consumer example
- `tests/web_app_test.go` – Terratest (basic apply)
- `.github/workflows/ci.yml` – CI pipeline (lint, validate, security, test)

## Run Locally
```
cd labs/lab10/examples/basic
terraform init
terraform apply
```

## Testing
```
cd labs/lab10/tests
go test -v -timeout 30m
```

## Next Steps
- Add semantic release workflow generating tags from conventional commits.
- Add tflint config with custom rules.
- Expand tests to assert outputs & HTTPS only setting.

## Cleanup
Destroy the example resources:
```
terraform destroy
```
