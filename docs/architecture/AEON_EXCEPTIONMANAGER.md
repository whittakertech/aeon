---
owner: "WhittakerTech"
status: "Stable"
phase: "3"
depends_on: [Aeon::RecurrenceAdapter]
consumed_by: [Aeon::Mutator]
last_updated: "2025-11-14"
---

# 🪶 Aeon::ExceptionManager – 4 + 1 Architecture

> *Marks the moments that should never happen again.*

---

## 1️⃣ Logical View

**Purpose:**  
Manages IceCube exception dates for Aeon recurrences, ensuring mutated occurrences are removed from original series.

**Responsibilities**
- Insert exception times for skipped occurrences.
- Apply “until” cutoffs for Change All Future.
- Maintain serialized rules in `repetition_rules`.

---

## 2️⃣ Process View

1. Mutator calls `add_exception(timestamp, time)` or `end_recurrence_at`.
2. Manager loads IceCube schedule via RecurrenceAdapter.
3. Adds `add_exception_time` or sets `until:`.
4. Serializes back into timestamp.
5. CacheInvalidation runs.

---

## 3️⃣ Development View

**File:** `app/services/aeon/exception_manager.rb`

```ruby
class Aeon::ExceptionManager
  def self.add_exception(timestamp, time)
    adapter = Aeon::RecurrenceAdapter.new(timestamp)
    schedule = adapter.schedule
    schedule.add_exception_time(time)
    timestamp.update!(repetition_rules: schedule.to_hash)
  end

  def self.end_recurrence_at(timestamp, cutoff)
    adapter = Aeon::RecurrenceAdapter.new(timestamp)
    schedule = adapter.schedule
    schedule.end_time = cutoff
    timestamp.update!(repetition_rules: schedule.to_hash)
  end
end
```

---

## 4️⃣ Physical View

| Attribute     | Description                    |
|---------------|--------------------------------|
| Store         | Postgres (via Aeon::Timestamp) |
| Dependency    | IceCube                        |
| Observability | Argus `aeon.exception.added`   |

---

## ➕ 1 Scenario View

### Scenario A – Skipping a Holiday
`add_exception_time` called for Dec 25.  
Calendar hides that day automatically.

### Scenario B – Splitting Series
`end_recurrence_at` called at edit boundary for Change All Future.

---