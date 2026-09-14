# Phase 8 — Kubernetes platform baseline (tasks 8.1–8.7)

**GOAL:** private, policy-guarded cluster with working public HTTPS, ZERO apps.
**START ONLY WHEN:** Phase 7 done. All `kubectl` via the public-endpoint kubeconfig `~/.kube/walfa-prod` (no tunnel).
**Workdir:** `walfa/infra/kubernetes/`.

## Task 8.1 — Namespaces, quotas, policies, service accounts

- [ ] `base/`: namespaces `platform apps observability` with `pod-security.kubernetes.io/enforce=restricted`.
- [ ] `ResourceQuota` + `LimitRange` per namespace (defaultRequest `100m/128Mi`, defaultLimit `500m/512Mi`).
- [ ] Default-deny NetworkPolicies per namespace.
- [ ] Dedicated ServiceAccounts; `automountServiceAccountToken: false` everywhere (exceptions listed + justified).
- [ ] Every pod MUST still set explicit `requests` + `limits` in its own spec — LimitRange defaults are not a substitute (master §20.2): a pod that inherits LimitRange defaults without explicit values will fail admission in namespaces that also enforce a ResourceQuota requiring explicit limits.
- [ ] PDB + anti-affinity expectation: every multi-replica Deployment (stateless services, gateway, bff) ships a `PodDisruptionBudget` with `minAvailable: 1` and a soft pod anti-affinity (`preferredDuringSchedulingIgnoredDuringExecution`) keyed on `app.kubernetes.io/name` to spread replicas across the 2 nodes; single-replica stateful workloads (Keycloak, Valkey) omit PDB (documented per workload).

**Verify:** `kubectl auth can-i --list --as=system:serviceaccount:apps:default -n apps | grep -i "create pods" || echo "DEFAULT-DENY OK"`.

## Task 8.2 — metrics-server

- [ ] Install; `kubectl top nodes` works.

**Verify:** `kubectl top nodes` returns both nodes with usage numbers.

## Task 8.3 — ingress-nginx + the ONE LB (ADR-015)

- [ ] Apply upstream manifests at the versions-table controller version (exact tag + manifest digest — placeholders forbidden in committed files).
- [ ] Patch Service: `type: LoadBalancer` + OCI annotations (flexible, 10 Mbps — exact keys from Oracle docs into ADR-015 ALONGSIDE resolved version + digest). **associate the LB Service with the ADOPTED reserved IP `walfa-ingress-ip` via the exact OCI annotation keys documented in ADR-015; wrong keys silently create a paid/second LB** (single-LB tripwire below catches this, but prevention is cheaper).
- [ ] Run single-LB tripwire IMMEDIATELY: count 0 → exactly 1.

**Verify:**
```bash
oci lb load-balancer list --compartment-id $OCI_COMPARTMENT_OCID | grep -c '"lifecycle-state": "ACTIVE"'  # exactly 1
# Tripwire: LB IP must equal the adopted reserved IP (not a newly provisioned one)
kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'  # must equal ↓
terraform output -raw public_ip_ingress                                                                        # reserved IP
```

## Task 8.4 — cert-manager + staging TLS + Full (strict)

- [ ] Upstream manifests `v1.21.1` (per versions table); `cloudflare-api-token-secret` in cert-manager ns (CI-rendered from `CLOUDFLARE_API_TOKEN`).
- [ ] `ClusterIssuer letsencrypt-staging` (DNS-01/Cloudflare, master §11.4 YAML verbatim + documented fields only).
- [ ] Test Ingress `tls-test.$WALFA_DOMAIN` (default-backend 404, staging issuer) → Certificate READY True.
- [ ] Create `letsencrypt-prod` issuer (unused until Phase 24).
- [ ] Cloudflare SSL mode = Full (strict). Never Flexible.

**Verify:**
```bash
kubectl get certificate -A -o jsonpath='{range .items[*]}{.metadata.name} {.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'  # tls-test True
curl -sk https://tls-test.$WALFA_DOMAIN/ -o /dev/null -w "%{http_code}\n"   # 404
```

## Task 8.5 — Point DNS at the LB

- [ ] VERIFY-ONLY: the 3 `cloudflare_dns_record` values must already equal the reserved IP (records were created in Phase 5). Terraform plan should show no changes. Apply a Terraform change ONLY if a value is mismatched.

**Verify:** `dig +short app.$WALFA_DOMAIN` must equal the reserved IP (`terraform output -raw public_ip_ingress`); records were created in Phase 5 — fix by Terraform change ONLY if mismatched.

## Task 8.6 — Free overlay + frozen scale dir

- [ ] `overlays/prod/`: kustomization (free-capacity values + hostname).
- [ ] `overlays/scale/`: ONLY `README.md` ("future, do not apply").

**Verify:** `kustomize build overlays/prod` succeeds; `ls overlays/scale/` shows only README.

## Task 8.7 — Phase gate

- [ ] 1 LB (flexible 10 Mbps) · [ ] staging TLS terminates (canary green) · [ ] quotas/policies enforced · [ ] prod issuer unused · [ ] scale/ unappliable.

## Phase gate

All of 8.7 ticked.

**DO NOT:** deploy apps/Keycloak, expose NodePorts, or accept a second LB "for testing".
