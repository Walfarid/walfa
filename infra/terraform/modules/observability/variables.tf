variable "compartment_id" {
  description = "Compartment OCID"
  type        = string
}

variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "walfa"
}
