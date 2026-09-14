variable "compartment_id" {
  description = "Compartment OCID for OCIR repositories"
  type        = string
}

variable "prefix" {
  description = "Repository namespace prefix"
  type        = string
  default     = "walfa"
}

variable "repositories" {
  description = "List of container repository names to create"
  type        = list(string)
  default     = ["edge-gateway", "web-bff", "identity", "portfolio", "publishing", "media", "analytics", "frontend"]
}
