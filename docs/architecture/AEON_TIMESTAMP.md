---
owner: "WhittakerTech"
status: "MVP"
phase: "3"
depends_on: [Aeon::Period]
consumed_by: [Aeon::RecurrenceAdapter, Aeon::PeriodQuery]
last_updated: "2025-11-14"
---

# 🧭 Aeon::Timestamp – 4 + 1 Architecture

> *A persisted promise of when something will occur.*

---

## 1️⃣ Logical View

**Purpose:**  
`Aeon::Timestamp` stores persistent temporal data for any schedulable model.  
It defines the source record from which recurring or one-off events are generated.

**Schema**

| Field              | Type     | Description              |
|--------------------|----------|--------------------------|
| `schedulable_type` | string   | Polymorphic reference    |
| `schedulable_id`   | uuid/int | —                        |
| `starts_at`        | datetime | Base time (UTC)          |
| `duration`         | bigint   | Seconds                  |
| `repetition_rules` | jsonb    | Serialized IceCube rules |
| `timezone`         | string   | Default UTC              |
| `meta`             | jsonb    | Optional contextual data |

**Associations**
```ruby
belongs_to :schedulable, polymorphic: true
```

---

## 2️⃣ Process View

1. Host model calls `has_one_schedule :event`.
2. Rails builds `Aeon::Timestamp` via nested attributes.
3. Aeon validates the structure with Veritas.
4. On save, observers trigger cache invalidation or refresh.
5. When queried, Timekeeper expands it using RecurrenceAdapter.

---

## 3️⃣ Development View

**File:** `app/models/aeon/timestamp.rb`

**Callbacks**
- `after_commit :invalidate_cache`
- `after_commit :emit_argus_event`

**Example**
```ruby
class Aeon::Timestamp < ApplicationRecord
  include Aeon::Persistable
  belongs_to :schedulable, polymorphic: true

  validates :starts_at, presence: true
  validates :duration, numericality: { greater_than: 0 }
  validates :repetition_rules, json: true

  def to_period
    Aeon::Period.new(starts_at:, ends_at: starts_at + duration)
  end
end
```

---

## 4️⃣ Physical View

| Attribute    | Description                                          |
|--------------|------------------------------------------------------|
| Store        | PostgreSQL (`aeon_timestamps`)                       |
| Indexes      | `[:schedulable_type, :schedulable_id]`, `:starts_at` |
| Dependencies | Argus (events), Veritas (validation)                 |

---

## ➕ 1 Scenario View

### Scenario A: Creating a Task Deadline
```ruby
Task.create!(
  deadline_schedule_attributes: {
    starts_at: 3.days.from_now,
    duration: 1.hour
  }
)
```

### Scenario B: Modifying a Recurrence
Updating `repetition_rules` triggers cache invalidation  
and RecurrenceAdapter rebuild.

**Observability:**  
Argus event → `aeon.timestamp.updated`.

---