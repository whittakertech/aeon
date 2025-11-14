# 🕰️ Aeon — The Temporal Engine of WhittakerTech

> *Time, distilled into code.*  
> Aeon unifies scheduling, recurrence, and time-aware logic across all WhittakerTech engines.  
> It is the layer that connects events, calendars, jobs, and temporal states through a consistent DSL and adapter-based architecture.

---

## ✨ Purpose

Aeon manages **when** things happen — whether it’s a recurring meeting, a job retry, or a cache refresh.  
It provides a unified interface for:

- 🗓️ **Scheduling:** attach time data to any model via `Aeon::Schedulable`
- ♻️ **Recurrence:** use IceCube-compatible rules for repeating events
- 🔍 **Querying:** fetch occurrences across time windows with `Aeon::Timekeeper`
- 💾 **Caching:** memoize expanded schedules for rapid calendar rendering
- 🧬 **Mutation:** handle "Change This / All / Future" logic safely
- 🔌 **Integration:** connect to metrics, validation, or job systems via adapters

Aeon does not dictate *how* time is used — it simply ensures every engine agrees on *what time means.*

---

## 🧱 Architecture Overview

| Layer                 | Components                                                      | Description                                                 |
|-----------------------|-----------------------------------------------------------------|-------------------------------------------------------------|
| **Model Layer**       | `Period`, `Timestamp`, `RecurrenceAdapter`                      | Defines how time and recurrence are stored and interpreted. |
| **Query Layer**       | `PeriodQuery`, `Timekeeper`                                     | Expands and queries time ranges.                            |
| **Cache Layer**       | `CacheWindow`, `CacheManager`, `CacheInvalidation`, `Refresher` | Optimizes recurring data retrieval and prewarming.          |
| **Mutation Layer**    | `Mutator`, `DeepCloneService`, `ExceptionManager`               | Handles event updates and change propagation.               |
| **Integration Layer** | `Schedulable`, `Worker`, `IntegrationSurfaces`                  | Exposes Aeon to host models and sibling engines.            |

See full documentation here →  
📘 [**Aeon Architecture Index**](docs/architecture/AEON_OVERVIEW.md)

---

## ⚙️ Configuration Example

```ruby
# config/initializers/aeon.rb
Aeon.configure do |config|
  config.cache_window_count = 2
  config.cache_window_units = :weeks
  config.default_timezone = "UTC"

  # Optional adapters
  config.metrics_adapter    = Argus::Adapter.new(prefix: "aeon")
  config.validation_adapter = Veritas::Adapter.new(strict: true)
end
```

Adapters are fully swappable. For example:

```ruby
config.metrics_adapter = PrometheusAdapter.new
config.validation_adapter = JSONSchemaValidator.new
```

---

## 🧩 Integration Surfaces

Aeon communicates through **open contracts**, not dependencies.  
Each connected engine plugs into a different surface of time:

| Engine | Role | Interface |
|---------|------|------------|
| **Prisms** | Consumer | `Aeon::Timekeeper` for calendar rendering |
| **Leeloo** | Consumer | `Aeon::CacheManager` for access control |
| **Mercury / Oscar** | Legacy Consumers | `Aeon::Worker` for job orchestration |
| **Argus / Veritas** | Optional Adapters | Metrics & validation providers |

> Replace any adapter at runtime — Aeon adapts to your environment.

---

## 🧪 Development

```bash
cd engines/aeon
bin/rails db:migrate
bin/rspec
```

**Directory structure:**

```
app/
  models/aeon/
  services/aeon/
  concerns/aeon/
docs/
  architecture/
lib/
  aeon/engine.rb
```

---

## 🌙 Philosophy

> *Aeon began as a clock.*  
> *It became a calendar.*  
> *Now it keeps the rhythm of creation — steady, quiet, eternal.*

— *WhittakerTech Temporal Systems Architecture Team*

---

### 🔗 Related Docs
- [Aeon Architecture Index](docs/architecture/AEON_OVERVIEW.md)
- [Integration Notes](docs/architecture/AEON_INTEGRATION_NOTES.md)
- [Configuration Reference](docs/architecture/AEON_CONFIGURATION.md)

---

© 2025 WhittakerTech — MIT Licensed.