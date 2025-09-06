variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "sku" {
	type    = string
	default = "B1"
}
variable "tags" {
	type    = map(string)
	default = {}
}
variable "enable_system_identity" {
	type    = bool
	default = true
}
