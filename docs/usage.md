# Usage Guide

## The Schedulable DSL

Include `WhittakerTech::Aeon::Schedulable` in any host model that owns a temporal schedule. The host model **must** use UUID primary keys.

```ruby
class Lesson < ApplicationRecord
  include WhittakerTech::Aeon::Schedulable

  schedule :time_slot
end
```

### Generated Associations

The `schedule :time_slot` macro generates:

- `lesson.time_slot` — the active Allocation (`valid_to IS NULL`)
- `lesson.time_slot_occurrences` — Occurrence collection via `:through`

These are standard ActiveRecord associations. You can chain scopes, eager-load, and query them like any other relation.

## Ensuring Projection

Projection is demand-driven. Call `ensure_projected!` to guarantee occurrences exist through a given window:

```ruby
lesson.ensure_projected!(window: 30.days)
```

This is a no-op if the allocation is already projected past the requested horizon. The default window comes from `config.projection_buffer` (14 days).

!!! note
    `ensure_projected!` is synchronous — it runs the Projector inline. For async projection, use `ProjectionJob` directly.

## Forking Schedules

Allocations are immutable. When a schedule needs to change, you **fork** — closing the old allocation and creating a successor.

### Fork Future

Change the schedule from a point in time forward. Past occurrences are untouched:

```ruby
lesson.fork_future(pivot: 1.week.from_now, rrule: new_rule)
```

This:

1. Closes the current allocation at the pivot (`valid_to = pivot`)
2. Creates a successor allocation with the new attributes
3. Invalidates future occurrences from the old allocation (set-based SQL)
4. Projects the new allocation inline

### Fork All

Replace the entire allocation. All existing occurrences are invalidated:

```ruby
lesson.fork_all(rrule: new_rule)
```

Equivalent to forking at `valid_from` — every occurrence is invalidated and the allocation is fully replaced.

### What You Can Change

Any allocation attribute can be overridden in a fork. Common examples:

```ruby
# Change the recurrence rule
lesson.fork_future(pivot: 1.week.from_now, rrule: new_ice_cube_hash)

# Change the duration
lesson.fork_future(pivot: 1.week.from_now, duration_seconds: 3600)

# Change the timezone
lesson.fork_future(pivot: 1.week.from_now, timezone: "America/New_York")

# Change multiple attributes at once
lesson.fork_all(
  rrule: new_rule,
  duration_seconds: 5400,
  timezone: "Europe/London"
)
```

## Overriding Single Occurrences

For single-instance changes (cancel one meeting, reschedule one class), use overrides instead of forks:

### Cancel an Occurrence

```ruby
lesson.override_occurrence(starts_at: target_time, canceled: true)
```

### Reschedule an Occurrence

```ruby
lesson.override_occurrence(
  starts_at: target_time,
  replacement_time_range: "[2025-07-01 14:00:00+00,2025-07-01 15:00:00+00)"
)
```

Overrides layer on top of the base occurrence. During reads, the override always wins.

!!! warning
    Do not fork for single-instance edits. Forking invalidates *all* future occurrences from the old allocation. Overrides are surgical and affect only the targeted occurrence.

## Async Projection

For background projection, enqueue `ProjectionJob`:

```ruby
WhittakerTech::Aeon::ProjectionJob.perform_later(
  allocation.id,
  30.days.from_now.iso8601
)
```

The job runs on the `aeon_projection` queue and delegates to `Projector.call`. Arguments are serialization-safe (UUID string + ISO 8601 timestamp).

## Querying Occurrences

Occurrences provide scopes for common queries:

```ruby
# Active (not invalidated, not purged)
lesson.time_slot_occurrences.active

# Invalidated by a fork
lesson.time_slot_occurrences.invalidated

# Overlapping a time range (GiST-indexed)
Occurrence.within_range("[2025-07-01,2025-07-31)")
```

The `within_range` scope uses the PostgreSQL `&&` operator on the GiST-indexed `time_range` column for efficient temporal queries.
