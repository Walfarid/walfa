variable "compartment_id" {
  description = "Compartment OCID for object storage"
  type        = string
}

variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "walfa"
}
