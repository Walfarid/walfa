variable "region" {
  description = "OCI region"
  type        = string
  default     = "ap-singapore-1"
}

variable "compartment_id" {
  description = "OCID of the WALFA compartment"
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
}

variable "object_storage_namespace" {
  description = "Object Storage namespace"
  type        = string
}

variable "prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "walfa"
}

# ── OKE settings ─────────────────────────────

variable "cluster_name" {
  description = "OKE cluster name"
  type        = string
  default     = "walfa-prod"
}

variable "node_pool_name" {
  description = "Node pool name"
  type        = string
  default     = "walfa-prod-pool"
}

variable "kubernetes_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "v1.36.1"
}

variable "node_ocpus" {
  description = "Total OCPUs for the ARM64 node pool"
  type        = number
  default     = 4
}

variable "node_memory_gbs" {
  description = "Total memory (GB) for the ARM64 node pool"
  type        = number
  default     = 24
}

variable "boot_volume_size_gbs" {
  description = "Boot volume size per node (GB)"
  type        = number
  default     = 200
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "api_endpoint_private" {
  description = "Whether the OKE API endpoint is private"
  type        = bool
  default     = false
}

variable "availability_domain" {
  description = "Availability domain for worker nodes (leave empty to use first AD)"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for OKE node access"
  type        = string
  default     = ""
}

variable "bastion_allowed_cidrs" {
  description = "CIDRs allowed to reach the bastion / operator SSH. NEVER 0.0.0.0/0 in prod."
  type        = list(string)
  default     = []
}

variable "github_actions_matching_rule" {
  description = "Matching rule for the GitHub Actions OIDC dynamic group"
  type        = string
  default     = "any {instance.principal.id = 'placeholder'}"
}
