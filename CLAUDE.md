# CLAUDE.md — WhittakerTech::Aeon

## What This Is

Aeon is a Rails Engine (isolated namespace `WhittakerTech::Aeon`) that serves as a **temporal physics engine**. It projects immutable temporal laws (Allocations) into materialized Occurrences while preserving historical integrity through forward-only timeline forking. It is **not** a calendar, job runner, audit engine, or domain validator.

## Current State

**Phase 0 — Engine Skeleton: COMPLETE**

- Rails 7.1.6 / Ruby 3.1.4
- Mountable, API-only, isolated namespace
- UUID primary keys configured via engine generator initializer
- UTC enforced (`config.time_zone = "UTC"`, `default_timezone = :utc`)
- PostgreSQL via Docker (`127.0.0.1:5432`, user/pass: `postgres/postgres`)
- Databases created: `whittaker_tech_aeon_development`, `whittaker_tech_aeon_test`
- RSpec + FactoryBot configured
- Dummy app at `test/dummy/` with explicit `config.root`

**Phase 1 — Database Physics (Migrations): COMPLETE**

- `pgcrypto` extension enabled for UUID generation
- Dedicated PostgreSQL schema `wt_aeon` (tables use short names: `wt_aeon.allocations`, etc.)
- `schema_format = :sql` — `structure.sql` captures PG schema, GiST indexes, partial indexes, tstzrange columns
- `wt_aeon.allocations` — polymorphic schedulable, temporal_kind enum, rrule jsonb, fork lineage via `supersedes_allocation_id`, partial unique index enforcing one active allocation per schedulable
- `wt_aeon.occurrences` — tstzrange `time_range` with GiST index, unique `(allocation_id, starts_at)` for idempotent upsert, partial index on active rows, FK to allocations for both `allocation_id` and `invalidated_by_allocation_id`
- `wt_aeon.overrides` — unique `occurrence_id` constraint (one override per occurrence), `replacement_time_range` tstzrange, `canceled` boolean

**Phase 2 — Models (thin): COMPLETE**

- `Allocation` — `temporal_kind` enum (`instant`, `span`, `schedule`), polymorphic `schedulable`, fork lineage (`superseded_allocation` / `superseding_allocation`), `has_many :occurrences`, `has_many :invalidated_occurrences`
- `Occurrence` — `state` enum (`active`), `belongs_to :allocation` / `:invalidated_by_allocation`, `has_one :override`, scopes: `active` (matches partial index), `invalidated`, `within_range` (GiST `&&` operator)
- `Override` — `belongs_to :occurrence` (no validations — DB enforces constraints)
- `table_name_prefix` defined on `WhittakerTech::Aeon` module in `lib/whittaker_tech/aeon.rb` before engine load, preempting `isolate_namespace` override

**Phase 3 — Projector service: COMPLETE**

- Stateless service: `Projector.call(allocation_id:, target_until:)`
- Lock allocation (`FOR UPDATE NOWAIT`), expand IceCube rrules, upsert occurrences (`INSERT ON CONFLICT DO NOTHING`), advance `projected_until` frontier
- Handles all three temporal kinds: `instant`, `span`, `schedule`
- Capped by `max_projection_window` and `valid_to`

**Phase 4 — Forker service: COMPLETE**

- Stateless service: `Forker.call(allocation_id:, pivot:, **new_attrs)`
- Lock → validate pivot → close old allocation (`valid_to = pivot`) → create successor with lineage → invalidate future occurrences (set-based SQL) → project successor inline
- When `pivot == valid_from` (fork-all), skips `starts_at >=` filter to handle IceCube millisecond truncation vs PG microsecond precision

**Phase 5 — OverrideApplier service: COMPLETE**

- Stateless service: `OverrideApplier.call(occurrence_id:, canceled:, replacement_time_range:)`
- Finds occurrence, validates it's active (not invalidated), creates override row
- DB unique index enforces one override per occurrence; never triggers re-projection

**Phase 6 — Schedulable DSL concern: COMPLETE**

- `WhittakerTech::Aeon::Schedulable` concern with `schedule :name` macro
- Generates: `has_one :name` (active allocation, scoped `valid_to: nil`), `has_many :name_occurrences` (through)
- Exposes verbs: `fork_future(pivot:, **new_attrs)`, `fork_all(**new_attrs)`, `override_occurrence(starts_at:, **attrs)`, `ensure_projected!(window:)`
- `has_many :through` requires explicit `class_name: "WhittakerTech::Aeon::Occurrence"` for cross-namespace resolution

**Phase 7 — Projection Worker: COMPLETE**

- `ProjectionJob < ApplicationJob`, queue: `aeon_projection`
- `perform(allocation_id, horizon_iso8601)` → delegates to `Projector.call`
- Serializes horizon as ISO 8601 string for safe job serialization
- No chaining, no orchestration, no callbacks — deterministic single-job execution

**Phase 8 — Guards (immutability enforcement): COMPLETE**

- `Allocation::TEMPORAL_FIELDS` — `before_update` guard blocks AR mutations to `temporal_kind`, `starts_at`, `duration_seconds`, `timezone`, `rrule`, `valid_from`, `valid_to`, `projected_until`, `supersedes_allocation_id`, `schedulable_type`, `schedulable_id`. Metadata fields (`disposal_policy`, `attachment_version_ref`) remain updatable.
- `Occurrence::COORDINATE_FIELDS` — `before_update` guard blocks AR mutations to `time_range`, `starts_at`, `ends_at`, `allocation_id`. Invalidation/state fields remain updatable.
- Services bypass guards via `update_column`/`update_columns`/`update_all` (skip callbacks by design)
- Monotonic projection enforced at service level (Projector's `already_projected?` check)

**Phase 9 — Structural Tests: COMPLETE**

- 58 examples, 0 failures across 6 spec files
- `spec/services/whittaker_tech/aeon/projector_spec.rb` — temporal kind expansion (instant/span/schedule), idempotency, horizon enforcement (max window, valid_to cap, monotonic), upsert correctness (time_range consistency, projection_fingerprint)
- `spec/services/whittaker_tech/aeon/forker_spec.rb` — fork future (close old, create successor, invalidate future, preserve past, inline projection), fork all (invalidates earliest occurrences), validation (pivot bounds, closed allocation, not found), disposal_policy inheritance
- `spec/services/whittaker_tech/aeon/override_applier_spec.rb` — cancellation, rescheduling, constraints (unique, invalidated, no-action, not found)
- `spec/models/whittaker_tech/aeon/guards_spec.rb` — all TEMPORAL_FIELDS blocked on Allocation, all COORDINATE_FIELDS blocked on Occurrence, metadata fields updatable
- `spec/concerns/whittaker_tech/aeon/schedulable_spec.rb` — associations (has_one, has_many through), ensure_projected!, fork_future, fork_all, override_occurrence, error handling
- `spec/jobs/whittaker_tech/aeon/projection_job_spec.rb` — delegation, idempotency, queue name
- Factory: `spec/factories/whittaker_tech/aeon/allocations.rb` with `:instant`, `:span`, `:projected` traits
- Support: `spec/support/schedulable_host.rb` (test host model with UUID PK, `schedule :time_slot`)

**Phase 10 — Performance Pass: COMPLETE**

- Projector `upsert!` batches `insert_all` into slices of 5,000 to prevent unbounded SQL statement size
- Benchmark spec (`spec/performance/benchmark_spec.rb`) with 6 structural performance tests:
  - Projection throughput: 366 daily occurrences in ~60ms (threshold: 1s)
  - Batch scale: 73k occurrences across 100 allocations in ~8s (threshold: 30s)
  - Range query: GiST-indexed `within_range` in ~15ms (threshold: 50ms)
  - Fork invalidation: 366-occurrence fork in ~13ms (threshold: 1s)
  - Idempotent re-projection: no-op in ~1ms (threshold: 200ms)
  - EXPLAIN verification: confirms Bitmap Index Scan on GiST index
- 64 total examples, 0 failures

## Build Order (Strict)

Follow this exact sequence. Never reverse it. Never parallelize prematurely.

```
Schema -> Constraints -> Models -> Services -> DSL -> Workers -> Guards -> Tests -> Docs
```

Phases:
1. ~~Engine skeleton (mountable, API-only, UUID PKs, UTC everywhere)~~ **DONE**
2. ~~Allocations migration~~ **DONE**
3. ~~Occurrences migration~~ **DONE**
4. ~~Overrides migration~~ **DONE**
5. ~~Models (thin — enums, associations, scopes only)~~ **DONE**
6. ~~Projector service~~ **DONE**
7. ~~Forker service~~ **DONE**
8. ~~OverrideApplier service~~ **DONE**
9. ~~Schedulable DSL concern~~ **DONE**
10. ~~Projection worker (ActiveJob/Sidekiq)~~ **DONE**
11. ~~Guards (immutability enforcement)~~ **DONE**
12. ~~Tests (structural, not micro)~~ **DONE**
13. ~~Performance pass~~ **DONE**

## Environment

- **Ruby:** 3.1.4 (via asdf, pinned in `.ruby-version`)
- **Rails:** 7.1.6 (pinned `~> 7.1.0` in gemspec)
- **PostgreSQL:** 16 via Docker (see `../docker-compose.yml`)
- **Redis:** 7 via Docker (available for later Sidekiq work)
- **Test framework:** RSpec + FactoryBot

## Core Entities

- **Allocation** — Immutable temporal law attached to a host via polymorphic `schedulable`. Never mutated; fork instead. Has `temporal_kind` enum: `instant`, `span`, `schedule`.
- **Occurrence** — Materialized prediction projected from an Allocation. Coordinates are immutable once created. Only `state` and invalidation metadata may change.
- **Override** — Surgical single-instance deviation layered on top of an Occurrence. One per occurrence. Never triggers re-projection.

## Database

- **Postgres required** (tstzrange, GiST indexes, partial indexes)
- Dedicated PostgreSQL schema `wt_aeon` — tables are `wt_aeon.allocations`, `wt_aeon.occurrences`, `wt_aeon.overrides`
- `table_name_prefix` defined as `def self.table_name_prefix` on `WhittakerTech::Aeon` module (in `lib/whittaker_tech/aeon.rb`, before engine load) — preempts `isolate_namespace`'s `unless mod.respond_to?` guard
- **UUID mandatory for all IDs, PKs, and FKs** — `id` columns, all `_id` foreign keys, and polymorphic `schedulable_id` must be `uuid`. No integer IDs. No exceptions. Host models using `Schedulable` must also use UUID primary keys.
- All timestamps are `timestamptz` in UTC
- Key indexes: GiST on `wt_aeon.occurrences.time_range`, partial unique on active allocations, unique `(allocation_id, starts_at)` on occurrences
- Schema format: `:sql` (`structure.sql`) — faithfully captures PG schema, GiST indexes, partial indexes, tstzrange columns
- Foreign keys use raw `ALTER TABLE ... ADD/DROP CONSTRAINT` in `reversible` migration blocks (Rails `add_foreign_key` cannot reverse schema-qualified tables)

## Architectural Invariants

- **Allocations are append-only.** Never edit in place. Fork forward.
- **Occurrences are coordinate-immutable.** Never rewrite `time_range`/`starts_at`/`ends_at`.
- **Projection is monotonic.** `projected_until` only moves forward.
- **Projection is idempotent.** Running the projector twice produces no duplicates (INSERT ON CONFLICT DO NOTHING).
- **Invalidation is set-based SQL.** No Ruby loops over datasets. Ever.
- **Reads are never blocked on projection.** Return partial results; enqueue projection async.
- **Overrides win during reads.** They layer on top of base occurrences.

## Coding Conventions

### Prefer
- Append-only writes
- Idempotent operations
- Set-based SQL (UPDATE ... WHERE)
- Immutable records
- Monotonic time progression
- Thin models (enums, associations, scopes)
- Services for all business logic

### Avoid
- ActiveRecord callbacks for business logic
- Hidden mutations / magic
- Ruby loops over datasets (use SQL)
- Speculative abstractions / over-engineering
- Infinite or unbounded projection
- Domain logic inside the engine
- Job chaining or workflow orchestration

## Services

- **Projector** — Expands IceCube rrules into Occurrence rows. Lock allocation, expand from `projected_until` to target horizon, upsert, advance frontier. Never delete, never rewrite.
- **Forker** — Handles "change future" / "change all". Closes old allocation (`valid_to = pivot`), creates new allocation with lineage, invalidates future occurrences via set-based UPDATE, triggers projection for new allocation.
- **OverrideApplier** — Locates occurrence, creates override row. Never regenerates projections.
- **Disposer** — Low-priority background purge of invalidated occurrences per retention policy. Scaffold early, implement later.

## Schedulable DSL

Host models include `WhittakerTech::Aeon::Schedulable` and declare `schedule :name`. This generates `has_one` / `has_many :through` associations and exposes explicit verbs:
- `fork_future(pivot:, ...)`
- `fork_all(...)`
- `override_occurrence(starts_at:, ...)`
- `ensure_projected!(window:)`

Hosts must **never** manipulate allocations directly. Blind temporal mutations are intercepted and forced through forks.

## Anti-Scope (Do NOT Build)

- UI adapters / FullCalendar serializers
- Calendar rendering or display logic
- Analytics / reporting
- Event buses / domain callbacks
- Audit engines / version diffs
- Lifecycle management of host records
- Domain validation (capacity, conflicts, business rules)

These belong **above** Aeon. Protect the primitive.

## Testing Strategy

Write structural tests, not 400 micro-tests. Critical coverage:
- Projection idempotency (run twice, no duplicates)
- Fork correctness (past untouched, future invalidated)
- Override precedence (override wins in query)
- Horizon extension (monotonic forward only)
- Range query performance (benchmark)

## Configuration

```ruby
WhittakerTech::Aeon.configure do |c|
  c.projection_buffer = 14.days
  c.max_projection_window = 1.year
  c.disposal_policy = :windowed
  c.invalidated_retention_window = 60.days
  c.queue_adapter = :sidekiq
end
```

## Key Files Reference

- `ARCHITECTURE.md` — Full 4+1 architecture document
- `EXECUTION_PLAN.md` — Phase-by-phase implementation roadmap
- `../docker-compose.yml` — PostgreSQL 16 + Redis 7 services
