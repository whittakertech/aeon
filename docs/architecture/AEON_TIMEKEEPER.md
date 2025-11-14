---
owner: "WhittakerTech"
status: "MVP"
phase: "3"
depends_on: [Aeon::PeriodQuery, Aeon::RecurrenceAdapter, Aeon::CacheWindow]
consumed_by: [Prisms, Calendars, Admin Dashboards]
last_updated: "2025-11-14"
---

# 🕵️‍♀️ Aeon::Timekeeper – 4 + 1 Architecture

> *Aeon::Timekeeper is the oracle of “what’s happening when.”*

---

## 1️⃣ Logical View

**Purpose:**  
Provide a unified API for querying temporal data across any model using Aeon schedules.  
It wraps `Aeon::PeriodQuery`, applies caching, and emits Argus metrics.

**Responsibilities**
- Collect timestamps within a defined range.
- Expand recurring events via RecurrenceAdapter.
- Cache results via CacheWindow + CacheManager.
- Return flattened list of `Aeon::Occurrence` objects.

**Public API**
```ruby
Aeon::Timekeeper.within(span: Aeon::Period)
Aeon::Timekeeper.for(Task, span: 1.month)
Aeon::Timekeeper.refresh!
```

---

## 2️⃣ Process View

1. User (or UI) requests data for a range.
2. Timekeeper resolves a normalized `Aeon::Period`.
3. Checks cache; if cold, runs `Aeon::PeriodQuery`.
4. Expands recurrences.
5. Stores occurrences in cache for next access.
6. Emits Argus metrics.

---

## 3️⃣ Development View

**File:** `app/services/aeon/timekeeper.rb`

```ruby
class Aeon::Timekeeper
  def self.within(span:)
    period = normalize(span)
    cache_key = CacheWindow.key_for(period)
    CacheManager.fetch(cache_key) do
      PeriodQuery.new(period).call
    end
  end

  def self.for(model, span:)
    within(span: span).select { |occ| occ.schedulable_type == model.name }
  end

  def self.refresh!
    CacheManager.clear_expired
  end

  def self.normalize(span)
    span.is_a?(Aeon::Period) ? span : Aeon::Period.new(starts_at: span.begin, ends_at: span.end)
  end
end
```

---

## 4️⃣ Physical View

| Attribute     | Description                           |
|---------------|---------------------------------------|
| Store         | Redis (cache) + Postgres (source)     |
| Dependencies  | Aeon::CacheManager, Aeon::PeriodQuery |
| Observability | Argus metrics, Veritas validations    |

---

## ➕ 1 Scenario View

### Scenario A: Weekly Calendar Render
```ruby
Aeon::Timekeeper.within(span: Date.today.beginning_of_week..Date.today.end_of_week)
```
→ Returns combined meetings, deadlines, due dates.

### Scenario B: Type-Scoped Query
```ruby
Aeon::Timekeeper.for(Meeting, span: Aeon::Period.new(...))
```

### Scenario C: Cache Refresh
Admin runs `Aeon::Timekeeper.refresh!`  
→ Clears expired cache windows, pre-fetches upcoming periods.

---

**Security & Observability**
- Internal-only access.
- Emits metrics: `aeon_timekeeper_queries_total`, `aeon_cache_hits_total`.

---