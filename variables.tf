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
  description = "User name to display"
  type        = string
  default     = "TerraformUser"
}