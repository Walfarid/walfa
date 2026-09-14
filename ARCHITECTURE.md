# WALFA Architecture

## System diagram

```text
                                      Internet
                                         |
                                         v
                               +-------------------------+
                               | OCI Flexible Load Balancer|
                               |   TCP :443 passthrough   |
                               +------------+--------------+
                                            |
                                            v
                               +-------------------------+
                               |      ingress-nginx      |
                               | TLS via cert-manager /  |
                               | Let's Encrypt           |
                               +------------+--------------+
                                            |
                                            v
                               +-------------------------+
                               |       edge-gateway       |
                               | auth | rate limit | CSRF |
                               +------+---------------+----+
                                     |               |
                        +------------+               +------------------+
                        |                                               |
                        v                                               v
                 +-------------+                                +--------------+
                 |  web-bff    |                                |    media     |
                 | read facade |                                | upload/meta  |
                 +------+------+                                +------+-------+
                        |                                              |
                        +------------------+---------------------------+
                                           |
                                           v
                              +--------------------------+
                              |        OKE cluster       |
                              | identity | portfolio     |
                              | publishing | analytics   |
                              | edge | bff | media       |
                              | Keycloak | Valkey        |
                              +------------+-------------+
                                           |
                     +---------------------+----------------------+
                     |                     |                      |
                     v                     v                      v
              Oracle Autonomous DB     OCI Object Storage      OCI Queue
```

## Bounded contexts

| Component | Responsibility | Persistence | External dependencies |
|---|---|---|---|
| `edge-gateway` | auth enforcement, rate limits, request normalization, CSRF checks, routing | none | OIDC provider, Valkey |
| `identity` | app users, local profile linkage, sessions, account purge | `ID_SCHEMA` | OIDC provider, queue/event transport |
| `portfolio` | profile, experience, education, skills, projects | `PORTFOLIO_SCHEMA` | event transport |
| `publishing` | articles, tags, technical guides, policy/legal pages | `PUBLISHING_SCHEMA` | event transport |
| `media` | media metadata, upload workflow, validation, cleanup | `MEDIA_SCHEMA` | OCI Object Storage, event transport |
| `analytics` | beacon intake (`POST /api/v1/beacon`), aggregation, retention, removal | `ANALYTICS_SCHEMA` | event transport |
| `web-bff` | public aggregation, sitemap, ads.txt, cache warming | cache only | Valkey, service APIs |
| Nuxt SPA | browser UI | browser storage only | gateway |
