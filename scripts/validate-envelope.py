#!/usr/bin/env python3
"""
Validate event envelope fixtures against the WALFA JSON Schema.

Exits 0 if good.json passes AND bad.json fails.
Exits non-zero otherwise.

Uses only Python stdlib (no jsonschema package).
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
SCHEMA_PATH = ROOT / "docs/specs/event-envelope.v1.json"
GOOD_PATH = ROOT / "docs/specs/fixtures/good.json"
BAD_PATH = ROOT / "docs/specs/fixtures/bad.json"

REQUIRED_FIELDS = {
    "event_id",
    "occurred_at",
    "aggregate_type",
    "aggregate_id",
    "entity_version",
    "event_type",
    "payload",
}

UUID_PATTERN = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)

EVENT_TYPE_PATTERN = re.compile(r"^[a-z]+\.[a-z-]+\.v1$")


def validate_envelope(envelope: dict) -> list[str]:
    """Return list of validation errors (empty = valid)."""
    errors = []

    if not isinstance(envelope, dict):
        return ["envelope must be an object"]

    # Required fields
    missing = REQUIRED_FIELDS - set(envelope.keys())
    if missing:
        errors.append(f"missing required fields: {sorted(missing)}")

    # No extra fields (additionalProperties: false)
    extra = set(envelope.keys()) - REQUIRED_FIELDS
    if extra:
        errors.append(f"additional properties not allowed: {sorted(extra)}")

    # event_id: string, UUID format
    if "event_id" in envelope:
        eid = envelope["event_id"]
        if not isinstance(eid, str):
            errors.append("event_id must be a string")
        elif not UUID_PATTERN.match(eid):
            errors.append("event_id must match UUID format (8-4-4-4-12 hex)")

    # occurred_at: string (basic date-time check not enforced beyond type)
    if "occurred_at" in envelope and not isinstance(envelope["occurred_at"], str):
        errors.append("occurred_at must be a string")

    # aggregate_type: string, minLength 1
    if "aggregate_type" in envelope:
        at = envelope["aggregate_type"]
        if not isinstance(at, str):
            errors.append("aggregate_type must be a string")
        elif len(at) < 1:
            errors.append("aggregate_type must have minLength 1")

    # aggregate_id: string, minLength 1
    if "aggregate_id" in envelope:
        aid = envelope["aggregate_id"]
        if not isinstance(aid, str):
            errors.append("aggregate_id must be a string")
        elif len(aid) < 1:
            errors.append("aggregate_id must have minLength 1")

    # entity_version: integer, minimum 1
    if "entity_version" in envelope:
        ev = envelope["entity_version"]
        if not isinstance(ev, int) or isinstance(ev, bool):
            errors.append("entity_version must be an integer")
        elif ev < 1:
            errors.append("entity_version must be >= 1")

    # event_type: string, pattern ^[a-z]+\.[a-z-]+\.v1$
    if "event_type" in envelope:
        et = envelope["event_type"]
        if not isinstance(et, str):
            errors.append("event_type must be a string")
        elif not EVENT_TYPE_PATTERN.match(et):
            errors.append(
                f"event_type must match pattern ^[a-z]+\\.[a-z-]+\\.v1$ (got {et!r})"
            )

    # payload: object
    if "payload" in envelope and not isinstance(envelope["payload"], dict):
        errors.append("payload must be an object")

    return errors


def main() -> int:
    schema = json.loads(SCHEMA_PATH.read_text())
    good = json.loads(GOOD_PATH.read_text())
    bad = json.loads(BAD_PATH.read_text())

    good_errors = validate_envelope(good)
    bad_errors = validate_envelope(bad)

    ok = True

    if good_errors:
        print(f"GOOD failed validation: {good_errors}")
        ok = False
    else:
        print("GOOD passes")

    if not bad_errors:
        print("BAD passed validation (should have failed)")
        ok = False
    else:
        print("BAD fails (as expected)")

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
