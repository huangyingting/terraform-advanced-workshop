# Makefile for Lab 5 - Terraform Module Quality Gate

.PHONY: help fmt lint validate test test-unit test-integration clean init plan apply destroy

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development targets
fmt: ## Format all Terraform files
	@echo "Formatting Terraform files..."
	terraform fmt -recursive .

lint: ## Run TFLint on all Terraform files
	@echo "Running TFLint..."
	tflint --init
	tflint --format compact ./modules/web_app
	tflint --format compact ./examples/basic

validate: ## Validate Terraform configurations
	@echo "Validating Terraform configurations..."
	cd modules/web_app && terraform init && terraform validate
	cd examples/basic && terraform init && terraform validate

security: ## Run Checkov security scan
	@echo "Running Checkov security scan..."
	checkov --config-file .checkov.yml --directory . --output cli

# Testing targets
test: test-unit test-integration ## Run all tests

test-unit: ## Run unit tests (fast validation)
	@echo "Running unit tests..."
	cd tests && go test -v -short -timeout 5m

test-integration: ## Run integration tests (creates real resources)
	@echo "Running integration tests..."
	cd tests && go test -v -timeout 30m

# Infrastructure targets for examples
init: ## Initialize Terraform for basic example
	@echo "Initializing Terraform..."
	cd examples/basic && terraform init

plan: init ## Plan Terraform deployment for basic example
	@echo "Planning Terraform deployment..."
	cd examples/basic && terraform plan -out=tfplan

apply: plan ## Apply Terraform deployment for basic example
	@echo "Applying Terraform deployment..."
	cd examples/basic && terraform apply tfplan

destroy: ## Destroy Terraform deployment for basic example
	@echo "Destroying Terraform deployment..."
	cd examples/basic && terraform destroy -auto-approve

# Utility targets
clean: ## Clean up temporary files
	@echo "Cleaning up..."
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.tfplan" -delete 2>/dev/null || true
	find . -name "*.tfstate*" -delete 2>/dev/null || true
	find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true

# Quality gate pipeline (runs all checks)
quality-gate: fmt lint validate security test-unit ## Run complete quality gate pipeline
	@echo "✅ Quality gate pipeline completed successfully!"

# CI pipeline simulation
ci: quality-gate test-integration ## Simulate complete CI pipeline
	@echo "✅ CI pipeline completed successfully!"
