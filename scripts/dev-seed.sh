#!/usr/bin/env bash
# WALFA local dev seed script
# Waits for Oracle to become healthy, then prints connection summary.
# Idempotent: safe to run multiple times.
set -euo pipefail

COMPOSE_FILE="scripts/dev-compose.yml"
TIMEOUT=300
ELAPSED=0

echo "==> Waiting for Oracle to become ready (timeout: ${TIMEOUT}s)..."

while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' walfa-oracle 2>/dev/null || echo "not_found")
    if [ "$STATUS" = "healthy" ]; then
        echo "==> Oracle is healthy (${ELAPSED}s elapsed)"
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    printf "    ... %ds (status: %s)\r" $ELAPSED "$STATUS"
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "==> ERROR: Oracle did not become healthy within ${TIMEOUT}s"
    echo "    Last status: $STATUS"
    echo "    Check logs: docker compose -f $COMPOSE_FILE logs oracle"
    exit 1
fi

echo ""
echo "==> WALFA Local Dev — Connection Summary"
echo "========================================="
echo "  Oracle:  localhost:1521/FREEPDB1"
echo "           user: system  password: dev-only-not-secret"
echo "  Valkey:  localhost:6379  password: dev-only"
echo "  Keycloak: http://localhost:8080"
echo "           admin: admin / admin"
echo ""
echo "  DB_WALLET_ENABLED=false (no wallet needed locally)"
echo "  These passwords are dev-only. Do NOT reuse anywhere else."
echo "========================================="
