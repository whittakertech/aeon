# API Reference

Aeon's public API has two layers:

1. **Quick reference** (below) — method signatures for the DSL, services, and model scopes
2. **Full YARD docs** ([/api/](/api/)) — generated class and method documentation with full parameter details

## Schedulable DSL

The `schedule` macro generates associations and verbs on the host model.

### Macro

```ruby
schedule :name, dependent: :nullify
```

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `Symbol` | *(required)* | Association name (e.g., `:time_slot`) |
| `dependent` | `Symbol` | `:nullify` | Dependency strategy for the `has_one` association |

### Generated Associations

| Association | Type | Description |
|---|---|---|
| `model.name` | `has_one` | Active allocation (`valid_to IS NULL`) |
| `model.name_occurrences` | `has_many :through` | Occurrences via the active allocation |

### Generated Methods

| Method | Returns | Description |
|---|---|---|
| `fork_future(pivot:, **attrs)` | `Allocation` | Fork at `pivot`, preserving past occurrences |
| `fork_all(**attrs)` | `Allocation` | Replace the entire allocation |
| `override_occurrence(starts_at:, **attrs)` | `Override` | Cancel or reschedule a single occurrence |
| `ensure_projected!(window:)` | `void` | Ensure projection covers `Time.current + window` |

## Service Classes

All services are stateless and invoked via `.call`.

### Projector

```ruby
WhittakerTech::Aeon::Projector.call(
  allocation_id: String,   # UUID
  target_until:  Time      # desired projection horizon
) # => void
```

Locks the allocation, expands IceCube rules, upserts occurrences in batches of 5,000, and advances `projected_until`.

### Forker

```ruby
WhittakerTech::Aeon::Forker.call(
  allocation_id: String,   # UUID
  pivot:         Time,     # split point
  **new_attrs              # attribute overrides for successor
) # => Allocation (the successor)
```

Closes the old allocation, creates a successor with lineage, invalidates future occurrences, and projects the successor inline.

### OverrideApplier

```ruby
WhittakerTech::Aeon::OverrideApplier.call(
  occurrence_id:          String,        # UUID
  canceled:               Boolean,       # default: false
  replacement_time_range: String | nil   # PG tstzrange literal
) # => Override
```

Creates an override for a single occurrence. Either `canceled: true` or `replacement_time_range` must be provided (not both).

### ProjectionJob

```ruby
WhittakerTech::Aeon::ProjectionJob.perform_later(
  allocation_id,     # String (UUID)
  horizon_iso8601    # String (ISO 8601 timestamp)
)
```

Async wrapper around `Projector.call`. Runs on the `aeon_projection` queue.

## Model Scopes

### Occurrence

| Scope | Description |
|---|---|
| `.active` | Not invalidated, not purged — matches the partial index |
| `.invalidated` | Invalidated by a fork (`invalidated_at IS NOT NULL`) |
| `.within_range(range)` | Overlaps the given tstzrange using the GiST-indexed `&&` operator |

## Enums

### Allocation#temporal_kind

| Value | Integer | Description |
|---|---|---|
| `instant` | 0 | Single point in time |
| `span` | 1 | Fixed-duration event |
| `schedule` | 2 | Recurring pattern (IceCube) |

### Occurrence#state

| Value | Integer | Description |
|---|---|---|
| `active` | 0 | Current, valid occurrence |
