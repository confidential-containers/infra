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
  default     = "ghcr.io/confidential-containers/garm:main"
  description = "Container image for garm"
}

variable "caddy_image" {
  type        = string
  default     = "caddy:2.6.4"
  description = "Container image for caddy"
}

variable "github_token" {
  type        = string
  description = "Github token for garm"
  sensitive   = true
}
