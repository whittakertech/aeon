# Core Concepts

Aeon has three core entities, a projection boundary, and a disposal policy. Understanding these is essential for working with the engine.

## Allocation

An **Allocation** is the immutable temporal law attached to a host record (the *schedulable*). It defines *when* something occurs via a temporal shape and recurrence rule.

Allocations are:

- **Append-only** — never edited in place
- **Supersedable** — forked forward; prior records remain intact
- **Polymorphic** — attached to any host model via `schedulable_type` / `schedulable_id`

Key fields:

| Field | Description |
|---|---|
| `temporal_kind` | Declared shape: `instant`, `span`, or `schedule` |
| `starts_at` | Anchor timestamp |
| `duration_seconds` | Length of the event (optional for instants) |
| `rrule` | IceCube recurrence rule as JSONB (required for `schedule`) |
| `timezone` | IANA timezone string (required for `schedule`) |
| `valid_from` / `valid_to` | Validity window — `valid_to IS NULL` means currently active |
| `projected_until` | Monotonic frontier of how far occurrences have been materialized |
| `supersedes_allocation_id` | Fork lineage — links to the predecessor allocation |
| `disposal_policy` | Per-allocation retention override (optional) |

### Temporal Shape

Allocation rows are self-describing. The `temporal_kind` enum declares the shape:

| `temporal_kind` | Anchor | Duration | RRULE |
|---|:---:|:---:|:---:|
| `instant` | Yes | No | No |
| `span` | Yes | Yes | No |
| `schedule` | Yes | Optional | Yes |

- **Instant** — a single point in time (e.g., a deadline)
- **Span** — a fixed-duration event (e.g., a 60-minute meeting)
- **Schedule** — a recurring pattern (e.g., every Tuesday at 10am for 45 minutes)

## Occurrence

An **Occurrence** is a materialized prediction projected from an Allocation. Each row represents a single point or span on the timeline.

Occurrences are:

- **Coordinate-immutable** — `time_range`, `starts_at`, and `ends_at` never change after creation
- **Query-first** — the canonical `time_range` (tstzrange) column is GiST-indexed for efficient range queries
- **Stateful** — `state` and invalidation metadata may change; coordinates may not

Key fields:

| Field | Description |
|---|---|
| `time_range` | Canonical tstzrange — the authoritative temporal span |
| `starts_at` / `ends_at` | Convenience columns (redundant with `time_range`, but ergonomic) |
| `projection_fingerprint` | SHA-256 hash of the allocation inputs used to project |
| `invalidated_at` | Set when a fork retires this prediction |
| `invalidated_by_allocation_id` | The successor allocation that caused invalidation |

## Override

An **Override** is a surgical deviation layered on top of a single Occurrence. Use overrides for:

- Cancelling a single instance
- Rescheduling a single instance to a different time

Overrides are:

- **One-per-occurrence** — enforced by a DB unique index
- **Non-destructive** — the base occurrence remains; the override layers on top
- **Read-precedent** — overrides always win during queries

An override either sets `canceled: true` or provides a `replacement_time_range`. It never triggers re-projection.

!!! note
    Do not fork allocations for single-instance edits. Use overrides instead. Forking is structural; overrides are surgical.

## Projection Boundary

Each allocation tracks a `projected_until` timestamp — the monotonic frontier of known time.

- **Moves forward only** — never decreases
- **Incremental** — projection extends the frontier in bounded chunks
- **Demand-driven** — consumers call `ensure_projected!` to extend the frontier when needed
- **Non-blocking** — reads return whatever occurrences exist; projection happens asynchronously

## Disposal Policy

Occurrences are materialized artifacts. When allocations are forked, old occurrences become invalidated. The disposal policy determines what happens to them.

The policy can be set globally or overridden per-allocation:

| Policy | Description |
|---|---|
| `:ephemeral` | Invalidated occurrences are immediately purged |
| `:windowed` | Retained for a configurable window, then purged |
| `:historical` | Retained indefinitely |
| `:permanent` | Never purged automatically |

The global default is `:windowed` with a 60-day retention window. Per-allocation overrides use the `disposal_policy` field on the Allocation.
