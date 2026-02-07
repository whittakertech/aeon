# WhittakerTech::Aeon

Temporal physics engine for Rails.

Aeon projects immutable temporal laws (Allocations) into materialized Occurrences while preserving historical integrity through forward-only timeline forking. It is **not** a calendar, job runner, audit engine, or domain validator — those concerns belong above Aeon.

## Requirements

- Ruby >= 3.1
- Rails ~> 7.1
- PostgreSQL 16+
- UUID primary keys on host models that include `Schedulable`

## Installation

Add the gem to your Gemfile:

```ruby
gem 'whittaker_tech-aeon'
```

Install the bundle:

```sh
bundle install
```

Run the install generator (copies the initializer and migrations into your app):

```sh
rails generate whittaker_tech:aeon:install
```

Optionally edit the generated initializer at `config/initializers/aeon.rb` to customize settings.

Run the copied migrations to create the `wt_aeon` schema and tables:

```sh
rails db:migrate
```

## Configuration

```ruby
WhittakerTech::Aeon.configure do |config|
  config.projection_buffer             = 14.days
  config.max_projection_window         = 1.year
  config.disposal_policy               = :windowed
  config.invalidated_retention_window  = 60.days
  config.queue_adapter                 = :sidekiq
end
```

| Option                         | Type                      | Default     | Description                                                                                             |
|--------------------------------|---------------------------|-------------|---------------------------------------------------------------------------------------------------------|
| `projection_buffer`            | `ActiveSupport::Duration` | `14.days`   | How far ahead of `Time.current` the projector extends by default                                        |
| `max_projection_window`        | `ActiveSupport::Duration` | `1.year`    | Absolute ceiling on how far a single allocation can be projected                                        |
| `disposal_policy`              | `Symbol`                  | `:windowed` | Retention strategy for invalidated occurrences (`:ephemeral`, `:windowed`, `:historical`, `:permanent`) |
| `invalidated_retention_window` | `ActiveSupport::Duration` | `60.days`   | How long invalidated occurrences are retained before purging                                            |
| `queue_adapter`                | `Symbol`                  | `:sidekiq`  | ActiveJob queue backend for `ProjectionJob`                                                             |

#### Disposal Policies

The disposal policy determines how invalidated occurrences are handled.

| Policy        | Description                                                                  |
|---------------|------------------------------------------------------------------------------|
| `:ephemeral`  | Invalidated occurrences are immediately purged.                              |
| `:windowed`   | Invalidated occurrences are retained for a fixed window before being purged. |
| `:historical` | Invalidated occurrences are retained indefinitely.                           |
| `:permanent`  | Invalidated occurrences are never purged.                                    |


## Usage

Include `Schedulable` in any host model that owns a temporal schedule. The host model **must** use UUID primary keys.

```ruby
class Lesson < ApplicationRecord
  include WhittakerTech::Aeon::Schedulable

  schedule :time_slot
end
```

This generates:

- `lesson.time_slot` — the active Allocation (`valid_to IS NULL`)
- `lesson.time_slot_occurrences` — Occurrence collection via `:through`

### Ensure projection

Project occurrences ahead of time so reads never block:

```ruby
lesson.ensure_projected!(window: 30.days)
```

### Fork future

Change the schedule from a point in time forward. Past occurrences are untouched:

```ruby
lesson.fork_future(pivot: 1.week.from_now, rrule: new_rule)
```

### Fork all

Replace the entire allocation. All existing occurrences are invalidated:

```ruby
lesson.fork_all(rrule: new_rule)
```

### Override a single occurrence

Cancel or reschedule one occurrence without affecting the rest of the series:

```ruby
lesson.override_occurrence(starts_at: target_time, canceled: true)
lesson.override_occurrence(starts_at: target_time, replacement_time_range: new_range)
```

### Async projection

Enqueue projection as a background job:

```ruby
WhittakerTech::Aeon::ProjectionJob.perform_later(allocation.id, horizon.iso8601)
```

## Core Concepts

- **Allocation** — An immutable temporal law attached to a host model via polymorphic `schedulable`. Never mutated in place; fork forward instead. Has a `temporal_kind`: `instant`, `span`, or `schedule`.
- **Occurrence** — A materialized prediction projected from an Allocation. Coordinates (`time_range`, `starts_at`, `ends_at`) are immutable once created.
- **Override** — A surgical single-instance deviation layered on top of an Occurrence. One per occurrence. Never triggers re-projection.

## Architectural Invariants

- **Allocations are append-only.** Never edit in place. Fork forward.
- **Occurrences are coordinate-immutable.** Never rewrite `time_range`, `starts_at`, or `ends_at`.
- **Projection is monotonic.** `projected_until` only moves forward.
- **Projection is idempotent.** Running the projector twice produces no duplicates.
- **Invalidation is set-based SQL.** No Ruby loops over datasets.
- **Reads are never blocked on projection.** Return partial results; enqueue projection async.
- **Overrides win during reads.** They layer on top of base occurrences.

## License

MIT License. See [MIT-LICENSE](MIT-LICENSE) for details.
