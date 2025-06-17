variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}
variable "vnet_name" {
  description = "vnet name"
  type        = string
  default     = "vnet-test-main"
}
variable "snet1_name" {
  description = "subnet1 name"
  type        = string
  default     = "snet1"
}
variable "snet2_name" {
  description = "subnet2 name"
  type        = string
  default     = "snet2"
}

variable "snet_db_name" {
  description = "subnet database name"
  type        = string
  default     = "snet-db"
}


variable "key_vault_name" {
  description = "Name of the existing Key Vault"
  type        = string
  default = "devopsRg-test-keyvault"
}
