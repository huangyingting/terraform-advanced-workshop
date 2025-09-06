# Lab 9 Solution: Private Network Zero-Trust Layer

Implements private DNS zones, private endpoints for Storage (blob), Key Vault, ACR, and an optional test VM to validate private access. Extend with firewall / forced tunneling as desired.

## Usage
Provision prerequisite resources (Storage Account, Key Vault, ACR) and generate a tfvars file with their IDs (run inside this `labs/lab9` directory):
```
./provision-prereqs.sh   # optional env vars: RG_NAME LOCATION STORAGE_NAME KV_NAME ACR_NAME TFVARS_FILE
```

Then run Terraform (the generated `lab9-prereqs.auto.tfvars` is auto-loaded). By default a small test VM is created unless you set `-var create_test_vm=false`:
```
terraform init
terraform plan
terraform apply
```

## Validate Connectivity
After apply, SSH to the VM (if you enabled a public IP separately or via Bastion/Jumpbox) or run a command from within the subnet (Cloud Shell not in VNet cannot reach private endpoints):

Examples from VM:
```
nslookup ${STORAGE_ACCOUNT}.blob.core.windows.net
curl -v https://${STORAGE_ACCOUNT}.blob.core.windows.net/ 2>&1 | head -n 5
nslookup ${KV_NAME}.vault.azure.net
nslookup ${ACR_NAME}.azurecr.io
```
All should resolve to 10.60.1.x private IPs matching the private endpoints.

## Next Extensions
- Disable public network access on Storage, Key Vault, ACR (after confirming private endpoints work).
- Add Azure Firewall / NVA and route tables for egress control.
- Add Private Endpoint for Key Vault `secrets` sub-resource if needed (same as `vault`).
- Integrate Defender for Cloud policies for mandatory private access.

## Cleanup
`terraform destroy`
