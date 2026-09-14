variable "region" {
  description = "OCI region for WALFA resources"
  type        = string
  default     = "ap-singapore-1"
}

variable "tenancy_ocid" {
  description = "OCID of the OCI tenancy"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID of the root compartment (typically the tenancy OCID)"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "walfa"
}
