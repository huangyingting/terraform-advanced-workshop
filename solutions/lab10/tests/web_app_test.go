package tests

import (
  "testing"
  "github.com/gruntwork-io/terratest/modules/terraform"
)

func TestWebAppModulePlan(t *testing.T) {
  t.Parallel()
  terraformOptions := &terraform.Options{ TerraformDir: "../examples/basic", NoColor: true }
  defer terraform.Destroy(t, terraformOptions)
  terraform.InitAndApply(t, terraformOptions)
}
