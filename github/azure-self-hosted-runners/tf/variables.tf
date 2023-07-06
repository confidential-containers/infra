variable "resource_group_name" {
  type        = string
  default     = "garm"
  description = "Name for garm resource group"
}

variable "location" {
  type        = string
  default     = "eastus"
  description = "Location for all resources"
}

variable "garm_image" {
  type        = string
  default     = "ghcr.io/mkulke/garm:20230602"
  description = "Container image for garm"
}

variable "caddy_image" {
  type        = string
  default     = "caddy:2.6.4"
  description = "Container image for caddy"
}

variable "storage_account_name" {
  type        = string
  default     = "cocogarmstorage"
  description = "Name for storage account"
}

variable "github_token" {
  type        = string
  description = "Github token for garm"
  sensitive   = true
}
