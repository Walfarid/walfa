# Phase 6 — OKE CNI switch + verification (tasks 6.1–6.4). Cluster exists.

**GOAL:** VCN-native CNI live; everything else verified untouched.
**START ONLY WHEN:** Phase 5 applied.
**Workdir:** `walfa/infra/terraform/` (`main.tf` only).

## Task 6.1 — CNI switch (the one change)

- [ ] `cni_type`: `"flannel"` → `"vcn-native"` (ADR-019; flannel cannot enforce NetworkPolicy).
- [ ] Expect cluster/node-pool REPLACEMENT in plan. Allowed ONLY with zero workloads deployed (`kubectl get deployments -A` empty first).
- [ ] Plan must show NO changes to bastion host, VCN, repos, buckets, IP. Anything else → STOP.

**Verify:** plan replaces cluster + node pool ONLY.

## Task 6.2 — Keep + record

- [ ] Keep: Basic, 2× A1 (2/12 each, boot 50, OL9, custom image ID), public endpoint, `create_operator = false`, `v1.36.1`.
- [ ] Check module 5.5.1 for API-endpoint CIDR restriction: set operator CIDR if supported, else record follow-up in ADR-015 scope.
- [ ] ADR-013: `v1.36.1` (adopted applied version). Auto-upgrade OFF.
- [ ] `docs/runbooks/cluster-access.md`: public kubeconfig refresh + bastion SSH (`terraform output ssh_to_bastion`) + DB tunnel pointer (Phase 10).

**Verify:** version identical in `main.tf`, ADR-013, `kubectl version`.

## Task 6.3 — Kubeconfig (public endpoint, no tunnel)

- [ ] `oci ce cluster create-kubeconfig --cluster-id $(terraform output -raw oke_cluster_id) --file ~/.kube/walfa-prod --region ap-singapore-1`.

**Verify:** `kubectl --kubeconfig ~/.kube/walfa-prod get nodes` → 2 nodes Ready, v1.36.1.

## Task 6.4 — Phase gate

- [ ] 2 ARM64 nodes, 2 OCPU/12 GB each · [ ] CNI vcn-native (no flannel DaemonSet, pod subnet exists) · [ ] kubeconfig works tunnel-less · [ ] adopted resources untouched · [ ] 0 LBs:
```bash
kubectl --kubeconfig ~/.kube/walfa-prod get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.kubernetes\.io/arch}{"\t"}{.status.capacity.cpu}{"\t"}{.status.capacity.memory}{"\n"}{end}'  # both arm64 2 ~12Gi
kubectl --kubeconfig ~/.kube/walfa-prod get pods -n kube-system -l k8s-app=kube-dns
oci lb load-balancer list --compartment-id $OCI_COMPARTMENT_OCID | grep -c ocid || echo "ZERO LB — CORRECT"
```

## Phase gate

All of 6.4 ticked.

**DO NOT:** enable Enhanced, touch the bastion host, or approve replacement of anything but cluster/node-pool.
