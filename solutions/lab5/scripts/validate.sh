#!/bin/bash

# Lab 5 - Local Validation Script
# This script runs the complete quality gate pipeline locally

set -e  # Exit on any error

echo "🚀 Starting Lab 5 Quality Gate Pipeline..."
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2 PASSED${NC}"
    else
        echo -e "${RED}❌ $2 FAILED${NC}"
        exit 1
    fi
}

# Function to print section
print_section() {
    echo -e "\n${YELLOW}📋 $1${NC}"
    echo "----------------------------------------"
}

# Check prerequisites
print_section "Checking Prerequisites"
which terraform > /dev/null 2>&1
print_status $? "Terraform installation"

which tflint > /dev/null 2>&1
print_status $? "TFLint installation"

which checkov > /dev/null 2>&1
print_status $? "Checkov installation"

which go > /dev/null 2>&1
print_status $? "Go installation"

# Code formatting
print_section "Code Formatting"
terraform fmt -check -recursive .
print_status $? "Terraform format check"

# Static analysis
print_section "Static Analysis"
tflint --init > /dev/null 2>&1
tflint --format compact modules/web_app/
print_status $? "TFLint - modules"

tflint --format compact examples/basic/
print_status $? "TFLint - examples"

# Terraform validation
print_section "Terraform Validation"
cd modules/web_app
terraform init > /dev/null 2>&1
terraform validate > /dev/null 2>&1
print_status $? "Module validation"
cd ../..

cd examples/basic
terraform init > /dev/null 2>&1
terraform validate > /dev/null 2>&1
print_status $? "Example validation"
cd ../..

# Security scanning
print_section "Security Scanning"
checkov --config-file .checkov.yml --directory . --quiet
print_status $? "Checkov security scan"

# Unit tests
print_section "Unit Tests"
cd tests
go mod download > /dev/null 2>&1
go test -v -short -timeout 5m
print_status $? "Go unit tests"
cd ..

echo -e "\n${GREEN}🎉 All quality gates passed! Ready for CI/CD pipeline.${NC}"
echo "================================================"

# Optional: Display next steps
echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Commit your changes using conventional commit format"
echo "2. Push to trigger the GitHub Actions pipeline"
echo "3. Create a pull request for review"
echo ""
echo "Example commit:"
echo "  git add ."
echo "  git commit -m 'feat: add new configuration option'"
echo "  git push origin feature-branch"
