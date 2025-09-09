variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "lab7-rg"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default = {
    project = "terraform-advanced-lab7"
    owner   = "example"
  }
}

variable "storage_account_suffix" {
  description = "Optional suffix to make storage account globally unique"
  type        = string
  default     = ""
}
