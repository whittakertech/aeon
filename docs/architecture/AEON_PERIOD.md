---
owner: "WhittakerTech"
status: "Stable"
phase: "3"
depends_on: []
consumed_by: [Aeon::Timekeeper, Aeon::CacheWindow, Aeon::Mutator]
last_updated: "2025-11-14"
---

# 🧩 Aeon::Period – 4 + 1 Architecture

> *Aeon::Period defines time itself—measurable, movable, and mutable.*

---

## 1️⃣ Logical View

**Purpose:**  
`Aeon::Period` encapsulates a bounded span of time (`starts_at..ends_at`) and provides fluent arithmetic for navigation (`>>`, `<<`), growth (`+`, `-`), and scaling (`*`, `/`).  
It’s the mathematical heart of Aeon.

**Key Responsibilities**
- Represent finite time spans with absolute precision.
- Provide clear operator semantics (shift vs grow vs scale).
- Remain immutable: all mutations return new objects.
- Support construction by `starts_at` + `ends_at` *or* `start` + `duration`.

**Attributes**

| Field       | Type     | Description     |
|-------------|----------|-----------------|
| `starts_at` | datetime | Inclusive start |
| `ends_at`   | datetime | Exclusive end   |
| `duration`  | numeric  | Derived seconds |

---

## 2️⃣ Process View

| Operation   | Meaning              | Example                      |
|-------------|----------------------|------------------------------|
| `>>`        | Shift forward        | `period >> 1.week`           |
| `<<`        | Shift backward       | `period << 2.days`           |
| `+`         | Grow (extend end)    | `period + 1.day`             |
| `-`         | Shrink (reduce end)  | `period - 1.hour`            |
| `*` / `/`   | Scale (around start) | `period * 2` → double length |

All operations are pure functions producing new `Aeon::Period` instances.

---

## 3️⃣ Development View

**File:** `app/models/aeon/period.rb`

**Implementation Highlights**
```ruby
class Aeon::Period
  attr_reader :starts_at, :ends_at

  def initialize(starts_at:, ends_at:)
    @starts_at, @ends_at = starts_at, ends_at
  end

  def duration = ends_at - starts_at
  def range    = starts_at..ends_at

  def +(delta) = new_with(ends_at: ends_at + to_seconds(delta))
  def -(delta) = new_with(ends_at: ends_at - to_seconds(delta))
  def >>(delta)= new_with(starts_at: starts_at + to_seconds(delta), ends_at: ends_at + to_seconds(delta))
  def <<(delta)= new_with(starts_at: starts_at - to_seconds(delta), ends_at: ends_at - to_seconds(delta))
  def *(factor)= new_with(ends_at: starts_at + duration * factor)
  def /(factor)
    raise ZeroDivisionError if factor.to_f.zero?
    *(1.0 / factor)
  end

  private
  def to_seconds(v)
    case v
    when Numeric then v
    when ActiveSupport::Duration then v.to_i
    when Aeon::Period, Range then v.end - v.begin
    else raise ArgumentError, "Unsupported delta #{v.class}"
    end
  end

  def new_with(**opts)
    Aeon::Period.new(starts_at: opts[:starts_at] || starts_at,
                     ends_at:   opts[:ends_at]   || ends_at)
  end
end
```

---

## 4️⃣ Physical View

| Attribute   | Description                                         |
|-------------|-----------------------------------------------------|
| Storage     | None (in-memory object)                             |
| Runtime     | Ruby object within app memory                       |
| Used by     | Aeon::PeriodQuery, Aeon::CacheWindow, Aeon::Mutator |

**Dependencies:** ActiveSupport durations.

---

## ➕ 1 Scenario View

### Scenario A: Shifting a Calendar View
```ruby
march = Aeon::Period.new(starts_at: Date.new(2025,3,1), ends_at: Date.new(2025,3,31))
march >> 1.month  # => April window
```

### Scenario B: Expanding Cache Range
```ruby
window = period * 1.5 + 1.week
# Doubles duration, then grows by one week
```

**Observability:**  
No persistence; debug output via `inspect`.  
`Argus` logs when used indirectly through Timekeeper.

---