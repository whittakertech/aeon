WhittakerTech::Aeon — Execution Plan
===================================

> Purpose: Translate the 4+1 architecture into a deterministic, implementation-ready roadmap suitable for LLM-assisted execution (ClaudeCode, etc.).
>
> This plan is intentionally structured to:
> - minimize architectural drift
> - enforce invariants early
> - avoid speculative infrastructure
> - produce a shippable engine quickly
>
> Build vertically. Stabilize primitives first. Do not parallelize prematurely.

---

# Execution Strategy (Read This First)

## Ordering Principle

Always build in this order:

```
Schema → Constraints → Models → Services → DSL → Workers → Guards → Tests → Docs
```

Never reverse it.

Schedulers fail when behavior exists before physics.

---

# Phase 0 — Engine Skeleton

## Goal
Create a boring, predictable Rails Engine with zero temporal logic yet.

## Tasks

### Generate Engine
- Isolated namespace: `WhittakerTech::Aeon`
- API-only engine (no views/helpers)

```
rails plugin new whittaker_tech-aeon \
  --mountable \
  --api \
  --skip-hotwire \
  --skip-javascript
```

### Configure Immediately
- UUID primary keys
- UTC enforced everywhere
- Rails 7.1+ / 8 ready migrations
- FactoryBot + RSpec (or your house style)
- Rubocop + StandardRB (optional but recommended)

### Deliverable
Engine boots cleanly inside dummy app.

**STOP HERE AND COMMIT.**

---

# Phase 1 — Database Physics (Most Important Phase)

> Do not write services yet.

## Migration 1 — Allocations

Create table:

**allocations**
- id: uuid
- schedulable_type (string, not null)
- schedulable_id (uuid/bigint, not null)
- temporal_kind (int/enum, not null)

- starts_at (timestamptz, not null)
- duration_seconds (integer, nullable)
- timezone (string, nullable)
- rrule (text/jsonb, nullable)

- valid_from (timestamptz, not null)
- valid_to (timestamptz, nullable)

- projected_until (timestamptz, not null)

- supersedes_allocation_id (uuid, nullable)

- occurrence_retention_policy (string/enum, nullable)
- attachment_version_ref (string, nullable)

### Indexes
```
index_allocations_on_schedulable
(schedulable_type, schedulable_id)

partial unique index:
one active allocation per schedulable
WHERE valid_to IS NULL
```

(Use partial index if Postgres ≥ 11 — which you absolutely should.)

---

## Migration 2 — Occurrences

**occurrences**
- id: uuid
- allocation_id (uuid FK, NOT NULL)

- time_range (tstzrange, NOT NULL)

- starts_at (timestamptz, NOT NULL)
- ends_at (timestamptz, NOT NULL)

- state (int enum, default: active)

- projection_fingerprint (string)
- projected_at (timestamptz)

- invalidated_at (timestamptz)
- invalidated_by_allocation_id (uuid)

- purged_at (timestamptz)

### Critical Indexes

GiST:
```
CREATE INDEX ON occurrences USING GIST (time_range);
```

Uniqueness:
```
UNIQUE(allocation_id, starts_at)
```

Partial:
```
WHERE invalidated_at IS NULL
```

---

## Migration 3 — Overrides

**overrides**
- id
- occurrence_id (FK)
- replacement_time_range (tstzrange)
- canceled (boolean)

### Constraint
```
UNIQUE(occurrence_id)
```

---

## Deliverable
Run `EXPLAIN` on a range query before writing a single service.

If Postgres is fast now — it stays fast later.

Commit.

---

# Phase 2 — Models (Keep Them Thin)

## Allocation Model

### Responsibilities
- enums
- associations
- simple guards

### DO NOT:
- fork here
- project here
- parse IceCube here

Keep it boring.

---

## Occurrence Model

Add scopes:

```
active
invalidated
within_range(range)
```

Do not add business semantics.

---

## Override Model

Simple presence validation.

Nothing clever.

---

## Deliverable
Models load.
Associations work.
Console smoke test passes.

Commit.

---

# Phase 3 — Core Services (The Engine's Spine)

Now we build the three forces that make Aeon real.

---

## Service 1 — Projector

### Responsibilities
- Expand IceCube
- Upsert occurrences
- Advance projection boundary
- Be idempotent

### Algorithm (LLM-safe)

```
lock allocation row
determine projection_start = projected_until
determine projection_end = requested_horizon

expand schedule via IceCube

for each occurrence:
  INSERT ... ON CONFLICT DO NOTHING

update projected_until = projection_end
```

### Requirements
- Never delete
- Never rewrite
- Never assume infinite projection

---

## Service 2 — Forker

### Responsibilities
- Close old allocation
- Create new allocation
- Link lineage
- Invalidate future occurrences

### Invalidation Query (set-based!)
```
UPDATE occurrences
SET invalidated_at = now()
WHERE allocation_id = ?
AND starts_at >= pivot
```

No Ruby loops. Ever.

---

## Service 3 — OverrideApplier

### Responsibilities
- Locate occurrence
- Create override
- Never regenerate projections

---

## Service 4 — Disposer (Low Priority Worker)

Not needed for MVP shipping, but scaffold now.

Responsibilities:
- purge invalidated rows per policy
- batch deletes

---

## Deliverable
You can:

✅ create allocation  
✅ project occurrences  
✅ fork future  
✅ override one instance

Engine is now alive.

Commit.

---

# Phase 4 — Schedulable DSL (ActiveStorage-Level Ergonomics)

## Goal
Make hosts feel first-class without leaking complexity.

### Implementation

`schedule :time_slot`

Generates:

```
has_one :time_slot,
  as: :schedulable,
  class_name: "WhittakerTech::Aeon::Allocation"
```

### Add Verbs

Hosts must NEVER manipulate allocations directly.

Expose:

```
fork_future
fork_all
override_occurrence
ensure_projected!
```

Intercept blind mutations.

Force forks.

---

## Deliverable
Attach Aeon to a dummy `Lesson` model.

Console demo:

```
lesson.time_slot
lesson.time_slot_occurrences
lesson.fork_future(...)
```

Commit.

---

# Phase 5 — Projection Worker

Use Sidekiq / ActiveJob.

Worker should:

```
perform(allocation_id, horizon)
→ call Projector
```

### DO NOT:
- chain jobs
- orchestrate workflows
- add callbacks

Schedulers die from job orchestration.

Stay deterministic.

---

# Phase 6 — Guardrails (Prevent Future You From Screwing This Up)

## Add Application Guards

### Prevent allocation updates:
Raise if persisted record changes temporal fields.

### Prevent occurrence coordinate mutation:
Readonly after creation.

### Enforce monotonic projection:
Reject backward updates.

---

## Optional (Later)
DB triggers for absolute enforcement.

Not required yet.

---

# Phase 7 — Testing Strategy

Do NOT write 400 micro-tests.

Write structural tests.

## Critical Tests

### Projection idempotency
Run projector twice → no duplicates.

### Fork correctness
Past occurrences untouched.
Future invalidated.

### Override precedence
Override wins in query.

### Horizon extension
Projection moves forward only.

### Range query performance
Use `Benchmark`.

---

# Phase 8 — Performance Pass (Mandatory Before Public Release)

Simulate:

- 10k allocations
- recurring schedules
- range queries

If slow:

→ fix indexes  
NOT Ruby.

---

# Phase 9 — Documentation Hooks (Use Your Forge)

Generate:

- Mermaid lineage diagrams
- projection flow
- fork flow

Let Lorelei render them automatically.

Aeon deserves excellent docs.

It is a cognitive engine.

---

# Definition of MVP DONE

Ship when:

✅ Allocations immutable  
✅ Forking works  
✅ Projection idempotent  
✅ Overrides function  
✅ Range queries fast  
✅ No calendar/UI leakage  
✅ No domain logic inside engine

At this point Aeon is already stronger than most production schedulers.

Seriously.

---

# Strong Anti-Scope Warning

Do NOT build yet:

- UI adapters
- FullCalendar serializers
- analytics
- reporting
- event buses
- audit engines

Those belong ABOVE Aeon.

Protect the primitive.

---

# Suggested Build Order (Ultra-Condensed)

If ClaudeCode needs a strict path:

1. Engine
2. Allocations migration
3. Occurrences migration
4. Overrides migration
5. Models
6. Projector
7. Forker
8. OverrideApplier
9. DSL
10. Worker
11. Guards
12. Tests
13. Performance pass

Follow it exactly.

Do not improvise.

---

# Final Guidance to the Implementing LLM

When uncertain, prefer:

- append-only
- idempotent writes
- set-based SQL
- immutable records
- monotonic time

Avoid:

- callbacks
- hidden mutations
- Ruby loops over datasets
- speculative abstractions

Aeon is a temporal physics engine.

Keep it cold.
Keep it predictable.
Keep it inevitable.