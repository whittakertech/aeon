# 🕰️ Aeon — The Temporal Engine of WhittakerTech

> *Time, distilled into code.*  
> Aeon unifies scheduling, recurrence, and time-aware logic across all WhittakerTech engines.  
> It connects events, calendars, jobs, and temporal states through a consistent DSL and adapter-based architecture.

---

## ✨ Purpose

Aeon manages **when** things happen — whether it’s a recurring meeting, a job retry, or a cache refresh.  
It provides a unified interface for:

- 🗓️ **Scheduling:** attach time data to any model via `Aeon::Schedulable`
- ♻️ **Recurrence:** use IceCube-compatible rules for repeating events
- 🔍 **Querying:** fetch occurrences across time windows with `Aeon::Timekeeper`
- 💾 **Caching:** memoize expanded schedules for rapid calendar rendering
- 🧬 **Mutation:** handle “Change This / All / Future” logic safely
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

📘 See the full documentation: [**Aeon Architecture Index**](docs/architecture/AEON_OVERVIEW.md)

---

## 🧩 Development Phases

### Phase 1 — Foundation ✅
- **Period:** immutable time arithmetic (`>>`/`<<` shift, `+`/`-` grow, `*`/`/` scale)
- **Timestamp:** persistent schedule storage with polymorphic associations
- **RecurrenceAdapter:** bridges Aeon rules to IceCube schedules

### Phase 2 — Query & Cache *(In Progress)*
- **PeriodQuery:** expands occurrences from recurrence rules
- **CacheWindow:** temporal buffering to prevent cache thrash
- **CacheManager:** Redis storage and TTL management
- **Timekeeper:** public query API

### Phase 3 — Mutation
- **Mutator:** “Change This / All / Future” semantics
- **DeepCloneService:** safe cloning of timestamps and attached records
- **ExceptionManager:** IceCube exception handling
- **CacheInvalidation:** automatic cache refreshing

### Phase 4 — Integration & Polish
- **Refresher:** proactive cache pre-warming
- **Schedulable:** model concern for attaching schedules
- **Adapters:** contracts for observability, validation, and metrics

---

## ⚙️ Installation

```ruby
gem "whittaker_tech-aeon"
bundle install

# Run migrations
bin/rails db:migrate
```

Optional initializer:

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

Adapters are swappable:

```ruby
config.metrics_adapter = PrometheusAdapter.new
config.validation_adapter = JSONSchemaValidator.new
```

---

## 🧩 Integration Surfaces

Aeon communicates through **open contracts**, not dependencies.  
Each connected engine plugs into a different surface of time:

| Engine              | Role              | Interface                                 |
|---------------------|-------------------|-------------------------------------------|
| **Prisms**          | Consumer          | `Aeon::Timekeeper` for calendar rendering |
| **Leeloo**          | Consumer          | `Aeon::CacheManager` for access control   |
| **Mercury / Oscar** | Legacy Consumers  | `Aeon::Worker` for job orchestration      |
| **Argus / Veritas** | Optional Adapters | Metrics & validation providers            |

> Replace any adapter at runtime — Aeon adapts to your environment.

---

## 🧪 Usage Examples

### Define a Schedulable Model

```ruby
class Task < ApplicationRecord
  include WhittakerTech::Aeon::Schedulable
  has_one_schedule :deadline
end
```

### Create a Task with Schedule

```ruby
task = Task.create!(
  title: "Quarterly Review",
  deadline_schedule_attributes: {
    starts_at: 3.days.from_now,
    duration: 3600,  # 1 hour
    timezone: "UTC",
    repetition_rules: { frequency: "yearly" }
  }
)
```

### Query Occurrences

```ruby
# Coming in Phase 2
# Aeon::Timekeeper.within(span: Aeon::Period.new(...))
```

---

## 🧩 Development

```bash
cd engines/aeon
bin/rails db:migrate
bin/rspec
```

**Directory structure:**

```
app/
  models/whittaker_tech/aeon/
  services/whittaker_tech/aeon/
  concerns/whittaker_tech/aeon/
docs/
  architecture/
lib/
  whittaker_tech/aeon/engine.rb
```

---

## 📘 Architecture Docs

See `/docs` for detailed 4 + 1 architecture documentation for each subsystem.  
Each document is standalone and linked through the [Aeon Architecture Index](docs/architecture/AEON_OVERVIEW.md).

---

## 🧪 Testing

```bash
bundle exec rspec
```

---

## 🧭 MkDocs Preview (Local)

Developers can preview Aeon’s documentation locally:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install mkdocs mkdocs-material
mkdocs serve
```

View at [http://localhost:8000](http://localhost:8000).

---

## 🌙 Philosophy

> *Aeon began as a clock.*  
> *It became a calendar.*  
> *Now it keeps the rhythm of creation — steady, quiet, eternal.*

— *WhittakerTech Temporal Systems Architecture Team*

---

## 🪞 License

MIT © 2025 WhittakerTech