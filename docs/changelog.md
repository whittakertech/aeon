# Changelog

## [0.1.0] — YYYY-MM-DD

### Added
- Core engine: Allocations, Occurrences, Overrides in dedicated `wt_aeon` PG schema
- Projector service: idempotent, monotonic, batched IceCube expansion
- Forker service: forward-only timeline forking (fork future / fork all)
- OverrideApplier service: surgical single-occurrence cancellation and rescheduling
- Schedulable DSL concern: `schedule :name` macro with `fork_future`, `fork_all`, `override_occurrence`, `ensure_projected!`
- ProjectionJob: async projection via ActiveJob
- Immutability guards: AR callbacks + PG BEFORE UPDATE triggers (two-tier allocation, hard-blocked occurrence)
- Configuration: projection_buffer, max_projection_window, disposal_policy, retention window, queue adapter
