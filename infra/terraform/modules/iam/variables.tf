variable "tenancy_ocid" {
  description = "Tenancy OCID"
  type        = string
}

variable "compartment_id" {
  description = "Compartment OCID for policies"
  type        = string
}

variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "walfa"
}

variable "github_actions_matching_rule" {
  description = "Matching rule for the GitHub Actions dynamic group"
  type        = string
  default     = "any {instance.principal.id = 'placeholder'}"
}
