# WhittakerTech::Aeon

**Temporal physics engine for Rails.**

Aeon projects immutable temporal laws (Allocations) into materialized Occurrences while preserving historical integrity through forward-only timeline forking.

## What Aeon Does

Aeon answers one question: **"When does it occur?"**

Given a temporal definition (a one-off timestamp, a fixed span, or a recurring schedule), Aeon materializes concrete occurrence rows in PostgreSQL, keeps them in sync when schedules change, and provides efficient range queries via GiST-indexed `tstzrange` columns.

The guiding design principle:

> *"Does this concern define time — or merely describe what happens within it?"*
>
> If it defines time, it belongs in Aeon. If it describes what happens, it belongs above Aeon.

## What Aeon Is NOT

Aeon is deliberately scoped. It is **not**:

- **A calendar system** — Aeon provides temporal facts, not presentation. No rendering, no UI payloads, no display concerns.
- **A job runner** — Aeon materializes time. It does not execute business work or trigger side effects.
- **An audit engine** — Aeon preserves temporal structure, not semantic history. No snapshots, no attribute diffs.
- **A lifecycle manager** — Aeon does not decide whether a host record should exist.
- **A domain validator** — Aeon enforces temporal physics, not business rules. Capacity constraints, conflict detection, and scheduling policies belong to the host application.

These concerns belong **above** Aeon. Protect the primitive.

## Quick Links

- [Installation](installation.md) — Get up and running
- [Core Concepts](concepts.md) — Understand allocations, occurrences, and overrides
- [Configuration](configuration.md) — Tune projection windows and disposal policies
- [Usage Guide](usage.md) — The Schedulable DSL and service APIs
- [Architecture](architecture.md) — How Aeon is built internally
- [Invariants & Guards](guards.md) — Immutability enforcement at every layer
- [API Reference](api.md) — Method signatures and YARD docs
