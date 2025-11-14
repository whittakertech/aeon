---
owner: "WhittakerTech"
status: "Stable"
phase: "3"
depends_on: [Aeon::Period]
consumed_by: [Aeon::CacheManager, Aeon::Timekeeper]
last_updated: "2025-11-14"
---

# 🪣 Aeon::CacheWindow – 4 + 1 Architecture

> *Expands query windows so Aeon can think ahead.*

---

## 1️⃣ Logical View

**Purpose:**  
`Aeon::CacheWindow` defines the normalized temporal span used for caching.  
It widens short queries (like a single week) into predictable overlapping buffers (e.g., month ± 2 weeks) to prevent cache thrash when users scroll.

**Responsibilities**
- Normalize arbitrary ranges into consistent cache buckets.
- Provide deterministic cache keys (`aeon:cache:{type}:{period_hash}`).
- Align overlapping windows to ensure smooth refresh transitions.

**Configuration**
```ruby
Aeon::CacheWindow.config.buffer_weeks = 2
Aeon::CacheWindow.config.alignment    = :month
```

---

## 2️⃣ Process View

1. A `Period` is requested (e.g., Mar 27 – Apr 3).
2. CacheWindow expands it to Feb 15 – May 15 (`month.beginning_of_month.weeks_ago(2)` … `month.end_of_month.weeks_since(2)`).
3. A cache key is generated from the resulting range.
4. `CacheManager` uses that key to fetch or store results.

---

## 3️⃣ Development View

**File:** `app/services/aeon/cache_window.rb`

```ruby
class Aeon::CacheWindow
  BUFFER = 2.weeks

  def self.for(period)
    start = period.starts_at.beginning_of_month.weeks_ago(2).beginning_of_day
    stop  = period.ends_at.end_of_month.weeks_since(2).end_of_day
    Aeon::Period.new(starts_at: start, ends_at: stop)
  end

  def self.key_for(period, topic: "all")
    digest = Digest::SHA1.hexdigest("#{period.starts_at.to_i}-#{period.ends_at.to_i}")
    "aeon:cache:#{topic}:#{digest}"
  end
end
```

---

## 4️⃣ Physical View

| Attribute   | Description                         |
|-------------|-------------------------------------|
| Store       | Redis (via CacheManager)            |
| TTL Policy  | 6 hours – 24 hours                  |
| Integration | Invoked by Timekeeper and Refresher |

---

## ➕ 1 Scenario View

### Scenario A: Monthly Calendar
User opens March → `Aeon::CacheWindow.for(march_period)`  
→ Window = Feb 15 – Apr 15, cache key =`aeon:cache:calendar:7d83…`.

### Scenario B: Week Navigation
Switching to Week 1/Week 2 stays within the same expanded window → instant render.

**Observability:**  
Argus event → `aeon.cachewindow.generated`.

---