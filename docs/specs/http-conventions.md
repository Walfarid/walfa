# HTTP Conventions (Frozen Spec v1)

Every WALFA service implements these conventions independently. No shared middleware.

## Error shape

All error responses use this canonical JSON shape:

```json
{
  "code": "NOT_FOUND",
  "message": "Resource not found",
  "request_id": "01920b3c-7a6d-7f33-8a21-4f51e06497f1"
}
```

Fields: `code` (string, machine-readable), `message` (string, human-readable), `request_id` (string, from `X-Request-Id` header).

## Pagination

Query parameters: `page` (integer, default 1), `page_size` (integer, default 20, max 100).
Return 422 if `page_size > 100` or `page < 1`.

Response envelope:

```json
{
  "items": [...],
  "page": 1,
  "page_size": 20,
  "total": 42
}
```

## Request ID

Header: `X-Request-Id`. If absent, the service generates a UUID v7 and attaches it. Propagate to all downstream calls and log entries.

## Mandatory endpoints

Every service exposes on its main port:

- `GET /health/live` — liveness probe (must not depend on DB unless service would deadlock)
- `GET /health/ready` — readiness probe (must fail if service cannot perform required work)
- `GET /metrics` — Prometheus-format metrics

## JWT algorithm allow-list

Services that validate JWTs hardcode: `RS256, ES256`. These same values are written locally in each service — never imported from a shared package.

## Security headers

All responses include:

- `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`
- `X-Content-Type-Options: nosniff`
- `Referer-Policy: strict-origin-when-cross-origin`
- `X-Frame-Options: DENY`

Copied by edge-gateway from this spec.
