---
owner: "WhittakerTech"
status: "MVP"
phase: "3"
depends_on: [Aeon::CacheManager]
consumed_by: [Aeon::Refresher, Aeon::Timekeeper]
last_updated: "2025-11-14"
---

# 🧹 Aeon::CacheInvalidation – 4 + 1 Architecture

> *Ensures that when time changes, memory follows.*

---

## 1️⃣ Logical View

**Purpose:**  
Detect changes to Aeon::Timestamp records and purge affected cache windows.

**Responsibilities**
- Subscribe to model events (create, update, destroy).
- Compute affected CacheWindow keys based on timestamp period.
- Delete or mark stale keys in Redis.
- Optionally trigger Refresher jobs.

---

## 2️⃣ Process View

1. `Aeon::Timestamp` commits transaction.
2. Observer fires `after_commit`.
3. CacheInvalidation computes window keys.
4. Deletes cached occurrences.
5. Argus logs and Refresher schedules rebuild.

---

## 3️⃣ Development View

**File:** `app/services/aeon/cache_invalidation.rb`

```ruby
class Aeon::CacheInvalidation
  def self.on_change(timestamp)
    period = timestamp.to_period
    key = Aeon::CacheWindow.key_for(period)
    Aeon::CacheManager.delete(key)
    Argus.emit("aeon.cache.invalidated", meta: { key:, id: timestamp.id })
  end
end
```

**Observer Integration**
```ruby
class Aeon::TimestampObserver < ActiveRecord::Observer
  observe :aeon_timestamp
  def after_commit(record) = Aeon::CacheInvalidation.on_change(record)
end
```

---

## 4️⃣ Physical View

| Attribute   | Description                    |
|-------------|--------------------------------|
| Runtime     | Rails ActiveRecord callbacks   |
| Store       | Redis (through CacheManager)   |
| Events      | Argus `aeon.cache.invalidated` |

---

## ➕ 1 Scenario View

### Scenario A: Timestamp Modified
User updates event → Invalidation removes affected window.

### Scenario B: Deletion
`destroy` → cache purged immediately.

**Observability:**  
Metrics `aeon_cache_invalidations_total`.

---