variable "location" {
  description = "Azure region to deploy resources into"
  type        = string
  default     = "uaenorth"
}

variable "project_name" {
  description = "Short name used as a prefix for all resources"
  type        = string
  default     = "imageapp"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}
