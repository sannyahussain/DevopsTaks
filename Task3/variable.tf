variable "resource_group" {
  description = "Name of the existing resource group"
  type        = string
  default     = "DevOpsResourceGroup"
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "eastus"
}

variable "source_storage_name" {
  description = "Name of the source blob storage account"
  type        = string
  default     = "sourcestoragexyz"
}

variable "destination_storage_name" {
  description = "Name of the destination Data Lake Gen2 storage account"
  type        = string
  default     = "datalakegen2xyz"
}

