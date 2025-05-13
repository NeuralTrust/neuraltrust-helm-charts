variable "client_id" {
  description = "The Client ID for the Service Principal"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "The Client Secret for the Service Principal"
  type        = string
  sensitive   = true
}

variable "subscription_id" {
  description = "The Subscription ID"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "The Tenant ID"
  type        = string
  sensitive   = true
} 