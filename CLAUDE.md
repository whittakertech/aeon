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
- `whittaker_tech_aeon_allocations` — polymorphic schedulable, temporal_kind enum, rrule jsonb, fork lineage via `supersedes_allocation_id`, partial unique index enforcing one active allocation per schedulable
- `whittaker_tech_aeon_occurrences` — tstzrange `time_range` with GiST index, unique `(allocation_id, starts_at)` for idempotent upsert, partial index on active rows, FK to allocations for both `allocation_id` and `invalidated_by_allocation_id`
- `whittaker_tech_aeon_overrides` — unique `occurrence_id` constraint (one override per occurrence), `replacement_time_range` tstzrange, `canceled` boolean

**Next: Phase 2 — Models (thin — enums, associations, scopes only)**

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
5. Models (thin — enums, associations, scopes only)
6. Projector service
7. Forker service
8. OverrideApplier service
9. Schedulable DSL concern
10. Projection worker (ActiveJob/Sidekiq)
11. Guards (immutability enforcement)
12. Tests (structural, not micro)
13. Performance pass

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
- UUID primary keys everywhere
- All timestamps are `timestamptz` in UTC
- Key indexes: GiST on `occurrences.time_range`, partial unique on active allocations, unique `(allocation_id, starts_at)` on occurrences

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
  c.occurrence_retention_policy = :windowed
  c.invalidated_retention_window = 60.days
  c.queue_adapter = :sidekiq
end
```

## Key Files Reference

- `ARCHETECTURE.md` — Full 4+1 architecture document
- `EXECUTION_PLAN.md` — Phase-by-phase implementation roadmap
- `../docker-compose.yml` — PostgreSQL 16 + Redis 7 services
