variable "compartment_id" {
  description = "Compartment OCID for network resources"
  type        = string
}

variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "walfa"
}

variable "vcn_cidr" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vcn_dns_label" {
  description = "DNS label for the VCN (max 15 chars, alphanumeric, must start with letter)"
  type        = string
  default     = "walfa"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]{0,14}$", var.vcn_dns_label))
    error_message = "vcn_dns_label must be 1-15 characters, start with a letter, and contain only alphanumeric characters."
  }
}

variable "lb_subnet_cidr" {
  description = "CIDR block for the load balancer (public) subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "worker_subnet_cidr" {
  description = "CIDR block for the OKE worker (private) subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "api_subnet_cidr" {
  description = "CIDR block for the OKE API endpoint subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "api_endpoint_private" {
  description = "Whether the OKE cluster API endpoint is private"
  type        = bool
  default     = false
}
