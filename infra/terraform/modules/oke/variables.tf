variable "compartment_id" {
  description = "Compartment OCID"
  type        = string
}

variable "vcn_id" {
  description = "VCN OCID"
  type        = string
}

variable "cluster_name" {
  description = "OKE cluster name"
  type        = string
  default     = "walfa-cluster"
}

variable "node_pool_name" {
  description = "Node pool name"
  type        = string
  default     = "walfa-pool"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.30.1"
}

variable "api_subnet_id" {
  description = "Subnet OCID for the cluster API endpoint"
  type        = string
}

variable "api_endpoint_private" {
  description = "Whether the API endpoint is private"
  type        = bool
  default     = false
}

variable "api_nsg_id" {
  description = "NSG OCID for the API endpoint"
  type        = string
}

variable "worker_subnet_id" {
  description = "Subnet OCID for worker nodes"
  type        = string
}

variable "worker_nsg_id" {
  description = "NSG OCID for worker nodes"
  type        = string
}

variable "lb_subnet_id" {
  description = "Subnet OCID for Kubernetes LoadBalancer services"
  type        = string
}

variable "node_ocpus" {
  description = "Total OCPUs for the node pool (ARM64 Ampere A1)"
  type        = number
  default     = 4
}

variable "node_memory_gbs" {
  description = "Total memory in GB for the node pool"
  type        = number
  default     = 24
}

variable "boot_volume_size_gbs" {
  description = "Boot volume size per node in GB"
  type        = number
  default     = 200
}

variable "node_count" {
  description = "Number of nodes in the pool"
  type        = number
  default     = 1
}

variable "availability_domain" {
  description = "Availability domain for the node pool"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for node access"
  type        = string
  default     = ""
}
