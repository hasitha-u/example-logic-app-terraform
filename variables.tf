variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "user_name" {
  description = "User name for tagging"
  type        = string
  default     = "Admin"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "logicapp-kv"
}

variable "enable_purge_protection" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = false # Set to true in production
}