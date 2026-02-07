# Invariants & Guards

Aeon enforces immutability at multiple layers: architectural invariants, ActiveRecord callback guards, and PostgreSQL triggers.

## Architectural Invariants

These seven rules are non-negotiable. Every service, guard, and constraint exists to enforce them.

1. **Allocations are append-only.** Never edit in place. Fork forward.
2. **Occurrences are coordinate-immutable.** Never rewrite `time_range`, `starts_at`, or `ends_at`.
3. **Projection is monotonic.** `projected_until` only moves forward.
4. **Projection is idempotent.** Running the projector twice produces no duplicates (`INSERT ON CONFLICT DO NOTHING`).
5. **Invalidation is set-based SQL.** No Ruby loops over datasets. Ever.
6. **Reads are never blocked on projection.** Return partial results; enqueue projection async.
7. **Overrides win during reads.** They layer on top of base occurrences.

## ActiveRecord Callback Guards

### Allocation: TEMPORAL_FIELDS

A `before_update` callback prevents AR-level mutation of temporal fields:

```
temporal_kind, starts_at, duration_seconds, timezone, rrule,
valid_from, valid_to, projected_until,
supersedes_allocation_id, schedulable_type, schedulable_id
```

Any attempt to change these via standard ActiveRecord methods (`update`, `save`, etc.) raises `ActiveRecord::ReadonlyAttributeError`.

Metadata fields (`disposal_policy`, `attachment_version_ref`) remain updatable through normal AR methods.

### Occurrence: COORDINATE_FIELDS

A `before_update` callback prevents AR-level mutation of coordinate fields:

```
time_range, starts_at, ends_at, allocation_id
```

Invalidation and state fields (`invalidated_at`, `invalidated_by_allocation_id`, `state`, `purged_at`) remain updatable.

### How Services Bypass Guards

Aeon's internal services (`Projector`, `Forker`) legitimately need to update guarded fields (e.g., advancing `projected_until`, setting `valid_to` on a fork). They use `update_column` / `update_columns` / `update_all`, which skip ActiveRecord callbacks by design.

## PostgreSQL Trigger Guards

Beyond AR callbacks, Aeon installs `BEFORE UPDATE` triggers at the database level for defense-in-depth.

### Allocation Trigger (Two-Tier)

The allocation trigger has two tiers:

- **Service-mutable fields** (`valid_to`, `projected_until`) — blocked by default, but can be bypassed by setting the session variable `aeon.bypass_guard = 'true'`
- **Hard-blocked fields** (all other temporal fields) — cannot be changed under any circumstances, even with the bypass variable

The Projector and Forker set `SET LOCAL aeon.bypass_guard = 'true'` inside their transactions to update `valid_to` and `projected_until`.

### Occurrence Trigger

Coordinate fields (`time_range`, `starts_at`, `ends_at`, `allocation_id`) are hard-blocked at the database level. No bypass variable, no exceptions.

!!! warning "For consumers"
    You cannot update temporal fields on allocations or coordinate fields on occurrences, even by using `update_column` to bypass AR callbacks. The PostgreSQL triggers will reject the change at the database level. This is by design — use `fork_future` or `fork_all` to change schedules, and `override_occurrence` for single-instance deviations.

!!! danger "Internal only"
    The `aeon.bypass_guard` session variable exists solely for Aeon's internal services. Consumers should never set this variable. If you find yourself needing to, you are working against Aeon's invariants and should reconsider your approach.
