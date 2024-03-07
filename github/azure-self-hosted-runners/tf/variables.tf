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

variable "vm_location" {
  type        = string
  default     = "westeurope"
  description = "Location for the runner VMs"
}

variable "garm_image" {
  type        = string
  default     = "ghcr.io/confidential-containers/garm:main"
  description = "Container image for garm"
}

variable "caddy_image" {
  type        = string
  default     = "caddy:2.6.4"
  description = "Container image for caddy"
}

variable "github_token_key_vault_id" {
  type        = string
  description = "key vault id holding github token secrets"
}
