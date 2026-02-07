# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Aeon is a Rails Engine (isolated namespace `WhittakerTech::Aeon`) that serves as a **temporal physics engine**. It projects immutable temporal laws (Allocations) into materialized Occurrences while preserving historical integrity through forward-only timeline forking. It is **not** a calendar, job runner, audit engine, or domain validator.

## Environment

- **Ruby:** 3.1.4 via asdf — managed by .ruby-version
- **Rails:** 7.1.6 (pinned `~> 7.1.0` in gemspec)
- **PostgreSQL:** 16 via Docker at `127.0.0.1:5432` (user/pass: `postgres/postgres`) — see `../docker-compose.yml`
- **Redis:** 7 via Docker (available for Sidekiq work)
- **Databases:** `whittaker_tech_aeon_development`, `whittaker_tech_aeon_test`
- **Dummy app:** `test/dummy/` (test harness for the engine)

## Commands

```bash
# Setup
asdf local ruby 3.1.4 # If ruby version differs from .ruby-version
bundle install
bundle exec rails db:create db:migrate # This is an engine migrations for a host app.

# Tests (RSpec, not Minitest)
bundle exec rspec                                                  # all tests (~70 examples)
bundle exec rspec spec/services/whittaker_tech/aeon/projector_spec.rb  # single file
bundle exec rspec spec/services/                                   # directory
bundle exec rspec spec/performance/benchmark_spec.rb               # performance benchmarks

# Lint
bundle exec rubocop

# Database
bundle exec rails db:migrate
bundle exec rails db:schema:dump           # regenerates test/dummy/db/structure.sql

# Docs
bundle exec yard doc                       # YARD API docs → doc/api/
mkdocs serve                               # local MkDocs site
```

**Migration gotcha:** Rails Engine development migrations automatically inject the engine's `db/migrate` and `test/dummy/db/migrate` into the same request, so cloning the migration files into the dummy creates duplicate migrations.
## Architecture

### Core Entities (all tables in dedicated PG schema `wt_aeon`)

- **Allocation** (`wt_aeon.allocations`) — Immutable temporal law attached to a host via polymorphic `schedulable` + `schedulable_label`. Has `temporal_kind` enum: `instant`, `span`, `schedule`. A host can have multiple named schedules (e.g. `schedule :time_slot`, `schedule :availability`), each distinguished by `schedulable_label`. Never mutated in place; fork forward instead.
- **Occurrence** (`wt_aeon.occurrences`) — Materialized prediction projected from an Allocation. `tstzrange` `time_range` with GiST index. Coordinates (`time_range`, `starts_at`, `ends_at`) are immutable once created. Unique `(allocation_id, starts_at)` for idempotent upsert.
- **Override** (`wt_aeon.overrides`) — Surgical single-instance deviation. One per occurrence (DB-enforced unique). Never triggers re-projection.

### Services (stateless, in `app/services/whittaker_tech/aeon/`)

- **Projector** — `Projector.call(allocation_id:, target_until:)` — Expands IceCube rrules → upserts Occurrence rows. Locks allocation (`FOR UPDATE NOWAIT`), batches `insert_all` in 5k slices, advances `projected_until` monotonically.
- **Forker** — `Forker.call(allocation_id:, pivot:, **new_attrs)` — Closes old allocation (`valid_to = pivot`), creates successor with lineage, invalidates future occurrences via set-based SQL, projects successor inline.
- **OverrideApplier** — `OverrideApplier.call(occurrence_id:, canceled:, replacement_time_range:)` — Creates override row. Never regenerates projections.
- **Resolver** — `Resolver.between(schedulable:, range:, label:)` — Canonical read path. Merges allocations, occurrences, overrides, and invalidations into a sorted array of frozen `ResolvedOccurrence` value objects. Never triggers projection. Known v1 limitation: a replacement override that shifts an occurrence INTO the window (whose base was outside) will not be caught.
- **Disposer** — Not yet implemented. Low-priority background purge of invalidated occurrences per retention policy.

### Schedulable DSL (`app/models/concerns/whittaker_tech/aeon/schedulable.rb`)

Host models include `WhittakerTech::Aeon::Schedulable` and declare `schedule :name`. The schedule name becomes the `schedulable_label` on the allocation, allowing multiple named schedules per host. Generates `has_one` (scoped by `valid_to: nil` and `schedulable_label`) / `has_many :through` associations and explicit verbs: `fork_future`, `fork_all`, `override_occurrence`, `ensure_projected!`, `resolve_<name>`. Hosts must never manipulate allocations directly.

### Immutability Guards (two tiers)

1. **ActiveRecord** `before_update` callbacks raise `ReadonlyAttributeError` on temporal/coordinate fields. Services bypass via `update_column`/`update_columns`/`update_all` (skip callbacks).
2. **PG `BEFORE UPDATE` triggers** — Allocations have a two-tier guard: identity/temporal fields are hard-blocked; `valid_to`/`projected_until` are service-mutable via `SET LOCAL aeon.bypass_guard = 'true'` within a transaction. Occurrence coordinate fields are hard-blocked (no bypass).

### Key Wiring Details

- **`table_name_prefix`** is `"wt_aeon."`, defined on the `WhittakerTech::Aeon` module in `lib/whittaker_tech/aeon.rb`. An engine initializer uses `on_load(:active_record)` + `redefine_method` to override `isolate_namespace`'s own callback that would otherwise clobber it.
- **Schema format is `:sql`** (`structure.sql`, not `schema.rb`) — required to capture PG schema, GiST indexes, partial indexes, tstzrange columns, triggers.
- **UUID mandatory** for all PKs, FKs, and polymorphic IDs. No integer IDs anywhere. Host models using `Schedulable` must also use UUID primary keys.
- **Foreign keys** use raw `ALTER TABLE ... ADD/DROP CONSTRAINT` in `reversible` migration blocks — Rails `add_foreign_key` cannot reverse schema-qualified tables.
- **`has_many :through` cross-namespace** requires explicit `class_name: "WhittakerTech::Aeon::Occurrence"`.
- **IceCube truncates to millisecond precision** while PG `timestamptz` preserves microseconds. The Forker accounts for this when `pivot == valid_from` (fork-all).
- **ProjectionJob** (`app/jobs/`) — queue `aeon_projection`, serializes horizon as ISO 8601 string, delegates to `Projector.call`.

## Database

- All timestamps are `timestamptz` in UTC
- Key indexes: GiST on `time_range`, partial unique on active allocations `(schedulable_type, schedulable_id, schedulable_label) WHERE valid_to IS NULL`, unique `(allocation_id, starts_at)` on occurrences
- `config/database.yml` uses `schema_search_path: "public,wt_aeon"`
- Single consolidated migration: `db/migrate/20250601000001_create_aeon_schema_and_tables.rb`

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
- Append-only writes, idempotent operations, set-based SQL
- Immutable records, monotonic time progression
- Thin models (enums, associations, scopes only), services for all business logic
- `reversible` blocks wrapping raw `execute` in migrations

### Avoid
- ActiveRecord callbacks for business logic
- Ruby loops over datasets (use SQL)
- Speculative abstractions, infinite/unbounded projection
- Domain logic inside the engine, job chaining or workflow orchestration

## Testing

- **RSpec + FactoryBot** — structural tests, not micro-tests
- Factory: `spec/factories/whittaker_tech/aeon/allocations.rb` (traits: `:instant`, `:span`, `:projected`)
- Test host model: `spec/support/schedulable_host.rb` (creates `schedulable_hosts` table with UUID PK, includes `schedule :time_slot`)
- FactoryBot paths configured in `spec/rails_helper.rb` (uses `__dir__`-relative paths, not `Rails.root`)
- When testing `before_update` guards on `belongs_to` fields, use `save!(validate: false)` to bypass AR validations while still firing callbacks
- When DB-level immutability triggers are installed, specs that `update_columns` on guarded fields must wrap in a transaction with `SET LOCAL aeon.bypass_guard = 'true'`

## Anti-Scope (Do NOT Build)

- UI adapters / FullCalendar serializers / calendar rendering
- Analytics / reporting / event buses / domain callbacks
- Audit engines / version diffs / lifecycle management of host records
- Domain validation (capacity, conflicts, business rules)

These belong **above** Aeon. Protect the primitive.

## Key Files

- `ARCHITECTURE.md` — Full 4+1 architecture document
- `EXECUTION_PLAN.md` — Phase-by-phase implementation roadmap
- `lib/whittaker_tech/aeon.rb` — Module definition, Configuration class, `table_name_prefix`
- `lib/whittaker_tech/aeon/engine.rb` — Engine class, initializers (UUID PKs, UTC, schema format, table prefix enforcement)
- `../docker-compose.yml` — PostgreSQL 16 + Redis 7 services