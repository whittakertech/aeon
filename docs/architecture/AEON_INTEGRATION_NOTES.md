---
owner: "WhittakerTech"
status: "Informational"
phase: "3"
exposes: [Aeon::Period, Aeon::Timekeeper, Aeon::CacheManager, Aeon::Mutator]
consumed_by: [All Engines]
last_updated: "2025-11-14"
---

# 🕯️ Aeon Integration Notes – 4 + 1 Overview

> *Aeon doesn’t just keep time — it connects it.*

---

## 1️⃣ Logical View

**Purpose:**  
Describe how Aeon exchanges data and events across the WhittakerTech ecosystem through open, swappable interfaces.  
Aeon defines *contracts*, not *couplings*: other engines integrate through well-defined temporal surfaces.

**Integration Principles**
1. **Interface-Driven Design:** Aeon exposes I/O contracts rather than dependencies.
2. **Polymorphism Everywhere:** any model can host a schedule via `Aeon::Schedulable`.
3. **Consistency:** all temporal data lives in `aeon_timestamps`.
4. **Visibility:** optional metrics adapters (Argus or others) can mirror lifecycle events.
5. **Predictability:** `CacheWindow` + `Refresher` ensure stable render and query performance.

---

## 2️⃣ Process View

1. A host model includes `Aeon::Schedulable` and defines schedules.
2. The user interacts through a calendar interface (Prisms / FullCalendar).
3. `Aeon::Timekeeper` queries and caches occurrences.
4. Mutations flow through `Mutator`, `DeepCloneService`, or `ExceptionManager`.
5. Optional adapters (metrics, validation, jobs) handle secondary concerns.
6. External engines receive updates via published events or query endpoints.

---

## 3️⃣ Development View

### 🔌 Integration Surfaces

> Aeon exposes optional sockets for collaboration with sibling engines.  
> None are required; all follow lightweight method contracts.

| Engine                 | Interface Type   | Exposed Socket                     | Consumed Socket             | Purpose                                                  |
|------------------------|------------------|------------------------------------|-----------------------------|----------------------------------------------------------|
| **Prisms**             | Consumer         | `Aeon::Timekeeper`                 | —                           | Reads occurrences for calendar rendering                 |
| **Leeloo**             | Consumer         | `Aeon::CacheManager`               | —                           | Manages role-based access to cached ranges               |
| **Aeon (Core)**        | Provider         | `Aeon::Period`, `Aeon::Timekeeper` | —                           | Temporal computation and cache services                  |
| **Mercury**            | Consumer         | —                                  | `Aeon::Worker`              | Uses legacy job scheduler                                |
| **Oscar**              | Consumer         | —                                  | `Aeon::Worker`              | Runs periodic cleanup tasks                              |
| **Metrics Adapter**    | Optional         | `emit(event, meta:)`               | —                           | Receives observability signals (Argus, Prometheus, etc.) |
| **Validation Adapter** | Optional         | —                                  | `validate(record, schema:)` | Provides external validation services                    |

**Design Principles**

- **Contract-based:** Adapters must only respond to known methods (`emit`, `validate`, etc.).
- **Swappable:** Replace Argus, Veritas, or Sidekiq with equivalents through configuration.
- **Fail-Open:** Missing adapters default to safe no-ops.
- **Dependency Inversion:** Aeon imports nothing; host apps inject adapters.

---

## 4️⃣ Physical View

| Attribute     | Description                                              |
|---------------|----------------------------------------------------------|
| Data Store    | PostgreSQL (timestamps) + Redis (caches / jobs)          |
| Observability | Optional metrics adapter (Argus, Prometheus, etc.)       |
| Validation    | Optional schema validator (Veritas, JSONSchemaValidator) |
| Refresh Cycle | Default 15 min prewarm heartbeat via `Aeon::Refresher`   |

---

## ➕ 1 Scenario View

### Scenario A — Calendar Integration (Prisms)
`Prisms` calls
```ruby
Aeon::Timekeeper.within(span: Aeon::Period.new(...))
```  
and receives expanded occurrences for display.

### Scenario B — Admin Prewarm Trigger
Admin UI invokes
```ruby
Aeon::Refresher.run
```  
to pre-generate caches for the next month.

### Scenario C — Legacy Job Execution
`Oscar` enqueues
```ruby
Aeon::Worker.schedule(Oscar::PurgeJob, at: ...)
```  
through the legacy adapter layer.

**Security:**  
All integrations respect Sesame scope isolation and tenant boundaries.

**Observability:**  
Global metric prefix `aeon_*`; emitted through the configured adapter.

---

## 🌙 Closing Note

> *Aeon stands at the crossroads of WhittakerTech’s time —  
> every moment recorded, every recurrence remembered,  
> every change forgiven through perfect memory.*
>
> — *WhittakerTech Temporal Systems Architecture Team*
---