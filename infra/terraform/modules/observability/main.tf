# ──────────────────────────────────────────────
# Observability module — placeholder for logging/metrics
# Actual observability is configured via Helm charts in-cluster.
# ──────────────────────────────────────────────

# Intentionally minimal — observability is managed via Kubernetes resources (Helm).
# This module exists for future OCI-native observability integration
# (e.g. OCI Logging, OCI Monitoring, Alarm definitions).

data "oci_identity_compartment" "this" {
  id = var.compartment_id
}
