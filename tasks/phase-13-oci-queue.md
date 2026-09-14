# Phase 13 — OCI Queue access + SDK conformance (tasks 13.1–13.6)

**GOAL:** services authenticated to Queue + implementation pattern proven + 4 transport gates green. Queues built in Phase 5.
**START ONLY WHEN:** Phase 12 done.

## Task 13.1 — Machine user, key, policy (TF + human split)

- [ ] Terraform: user `walfa-queue-client` + group + policy (queue operations ONLY in WALFA compartment).
- [ ] Human: `oci iam user api-key upload` → private key into Vault as `queue-client-key` (11th Vault secret). Never into TF state, never into git.
- [ ] Add `oci-queue-key` Secret template (`/.oci/` mount: `config` + `key.pem`, `OCI_CONFIG_FILE=/.oci/config`) to `infra/kubernetes/base/secrets/` (Phase 9 pattern). (K8s Secret `oci-queue-key` renders Vault `queue-client-key`.)
- [ ] Record in the §4.2-exception ADR with rotation date (90 days, same rhythm as OCIR token).

**Verify:** key fingerprint in Vault metadata matches `oci iam user api-key list`; template renders with placeholders only.

## Task 13.2 — Transport selftest Job (oci CLI only, no WALFA code)

- [ ] `infra/kubernetes/base/jobs/transport-selftest.yaml` with the `oci-cli` image: PutMessages batch of 100 → long-poll GetMessages → count + payload integrity → DeleteMessages → queue empty. Then visibility proof: put 1, get WITHOUT delete, wait past visibility timeout, get again → redelivered.

**Verify:**
```bash
kubectl -n apps apply -f infra/kubernetes/base/jobs/transport-selftest.yaml
kubectl -n apps wait --for=condition=complete job/transport-selftest --timeout=300s
kubectl -n apps logs job/transport-selftest | grep -E "ROUNDTRIP OK|REDELIVERY OK"
```

## Task 13.3 — DLQ proof (once, then clean up)

- [ ] CLI: create TEMPORARY `walfa-dlq-test` (max-delivery-count=2, short visibility) → publish 1 poison → GetMessages repeatedly WITHOUT deleting → after 2 deliveries it routes to `walfa-dlq` → assert arrival → DELETE the temp queue.
- [ ] Queue-count assert: `oci queue queue list --compartment-id $OCI_COMPARTMENT_OCID | grep -c walfa` must return **6** (5 queues created in Phase 5 + 1 DLQ; the temporary `walfa-dlq-test` was deleted above).
- [ ] Log pasted into ADR-009.

**Verify:** `oci queue queue list | grep dlq-test || echo "TEMP GONE"`; `oci queue queue list --compartment-id $OCI_COMPARTMENT_OCID | grep -c walfa` == 6; DLQ assertion output in ADR-009.

## Task 13.4 — Spec sharpening (only if needed)

- [ ] If selftest/DLQ exposed gaps in `queue-topology.md`/`outbox.md`, sharpen the DOCS. Never write code here.

**Verify:** selftest green against final spec text.

## Task 13.5 — ADR-009 closeout

- [ ] Queue canonical with: Phase 5 re-verification result + selftest/DLQ logs + API-call budget math (worst-case estimate vs 1M/month cap) + spend-alarm pointer + outbox-age metric hook expectation for the Phase 5 alarm.

**Verify:** ADR-009 status = closed, all five artifacts present.

## Task 13.6 — Phase gate

- [ ] Selftest green on real Queue · [ ] DLQ proven + temp deleted · [ ] key in Vault (11 secrets) + template renders · [ ] ADR-009 closed · [ ] alarm wired.
- [ ] Per-service duplicate-delivery proofs deferred to Phases 14–18 (own fakes + own tests).

## Phase gate

All of 13.6 ticked.

**DO NOT:** deploy NATS "to compare", share the OCI key with humans, bake keys into images, or write a shared Queue wrapper.
