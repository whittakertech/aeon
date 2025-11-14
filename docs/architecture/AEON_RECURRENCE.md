---
owner: "WhittakerTech"
status: "Stable"
phase: "3"
depends_on: [Aeon::Timestamp]
consumed_by: [Aeon::PeriodQuery]
last_updated: "2025-11-14"
---

# 🧮 Aeon::RecurrenceAdapter – 4 + 1 Architecture

> *Bridging human recurrence to IceCube’s crystalline precision.*

---

## 1️⃣ Logical View

**Purpose:**  
Convert Aeon’s JSON-based recurrence definitions into executable IceCube schedules  
and back again.

**Responsibilities**
- Parse `repetition_rules` JSON into `IceCube::Schedule`.
- Serialize IceCube objects back to JSON.
- Expose `occurrences_between` and `next_occurrence` helpers.

---

## 2️⃣ Process View

1. Timestamp saved with `repetition_rules`.
2. Adapter loads JSON → IceCube schedule.
3. When queried by PeriodQuery:
  - Compute occurrences in given range.
  - Apply exception dates if present.
4. Serialize back when timestamp updates.

---

## 3️⃣ Development View

**File:** `app/services/aeon/recurrence_adapter.rb`

```ruby
require "ice_cube"

class Aeon::RecurrenceAdapter
  def initialize(timestamp)
    @timestamp = timestamp
  end

  def schedule
    IceCube::Schedule.new(@timestamp.starts_at).tap do |s|
      rules = @timestamp.repetition_rules || {}
      frequency = rules["frequency"]
      s.add_recurrence_rule(build_rule(rules)) if frequency
    end
  end

  def occurrences_between(period)
    schedule.occurrences_between(period.starts_at, period.ends_at)
  end

  private

  def build_rule(rules)
    freq = rules["frequency"].to_sym
    IceCube::Rule.send(freq, rules["interval"] || 1).tap do |r|
      r.day(rules["by_day"]) if rules["by_day"]
      r.until(Time.parse(rules["until"])) if rules["until"]
    end
  end
end
```

---

## 4️⃣ Physical View

| Attribute   | Description                                 |
|-------------|---------------------------------------------|
| Dependency  | IceCube gem                                 |
| Cache       | Optional Redis memoization of computed sets |
| Integration | Used by PeriodQuery and Mutator             |

---

## ➕ 1 Scenario View

### Scenario A: Weekly Meeting
```ruby
rules = { "frequency" => "weekly", "by_day" => ["monday", "thursday"] }
Aeon::RecurrenceAdapter.new(timestamp).schedule
```

### Scenario B: Single-Use Deadline
`repetition_rules: nil` → one-off event.

### Observability
- Argus event: `aeon.recurrence.expanded`
- Metrics: `aeon_occurrence_count_total`

---