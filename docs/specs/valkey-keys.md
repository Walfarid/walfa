# Valkey Key Layout (Frozen Spec v1)

Every WALFA service writes its own thin Valkey client (~30 lines) using `valkey-go`. No shared wrapper.

## Key namespaces (mandatory prefixes)

| Prefix | Purpose | TTL |
|---|---|---|
| `sess:<session-id>` | Server-side session record | = session idle timeout |
| `ratelimit:<scope>:<key>` | Fixed-window rate limit counter | = window length |
| `bff:public:<route>` | web-bff cached public aggregates | <= 300s |

## Rules

1. NO immortal keys. Every key has a mandatory TTL. No SET without EXPIRE.
2. Authentication mandatory. All connections use `VALKEY_PASSWORD`.
3. Each service writes its own client to this layout. No shared package.
4. Raw unprefixed key access is forbidden by review.
5. LRU eviction (`allkeys-lru`) handles overflow; session invalidation on logout is an explicit DEL.
