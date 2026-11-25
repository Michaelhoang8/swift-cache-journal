# Actor-isolated TTL cache journal

Replay cache events through a Swift actor implementing LRU eviction and explicit expiration.

Language: **Swift**.

[![Validation](https://github.com/Michaelhoang8/swift-cache-journal/actions/workflows/ci.yml/badge.svg)](https://github.com/Michaelhoang8/swift-cache-journal/actions/workflows/ci.yml)

## Run

```sh
swift run cache-journal fixtures/journal.json
```

## Behavior

- Actor isolation serializes writes, with a concurrent task-group test.
- Explicit integer ticks make expiry boundaries repeatable without sleeps.
- Hits update recency; replacements renew TTL; expired entries do not count as capacity evictions.

## Validation

```sh
swift run cache-journal --test
```

The workflow executes the checked-in fixtures and boundary tests. See the workflow log for the actual result; tests are included with the source.

## Scope

The CLI uses capacity two. The reusable actor accepts any positive capacity. LRU bookkeeping is linear in cache size, not an optimized linked-list implementation. Timestamps must be monotonic; values are strings.

Code: [MIT](LICENSE). Fixtures are constructed examples.
