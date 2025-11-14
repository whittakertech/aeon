---
owner: "WhittakerTech"
status: "Stable"
phase: "3"
depends_on: [Aeon::CacheManager, Aeon::CacheWindow, Aeon::Timekeeper]
consumed_by: [Aeon::Heartbeat]
last_updated: "2025-11-14"
---

# 💨 Aeon::Refresher – 4 + 1 Architecture

> *Breathes new life into stale caches.*

---

## 1️⃣ Logical View

**Purpose:**  
Proactively refresh cached query results before they expire.  
Acts as Aeon’s self-healing temporal daemon.

**Responsibilities**
- Detect near-expiry keys (`TTL < threshold`).
- Recompute occurrences via Timekeeper.
- Write fresh values back to Redis.
- Emit Argus heartbeat metrics.

---

## 2️⃣ Process View

1. Heartbeat job runs every N minutes.
2. Refresher scans `aeon:cache:*` keys.
3. If TTL < 30 min → load window metadata.
4. Calls `Aeon::Timekeeper.within(span: window)` to rebuild.
5. Stores new payload with extended TTL.
6. Logs `aeon.refresher.refreshed`.

---

## 3️⃣ Development View

**File:** `app/services/aeon/refresher.rb`

```ruby
class Aeon::Refresher
  THRESHOLD = 30.minutes

  def self.run
    keys = Redis.current.keys("aeon:cache:*")
    keys.each do |key|
      ttl = Redis.current.ttl(key)
      next unless ttl.between?(0, THRESHOLD.to_i)
      period = decode_period_from_key(key)
      refreshed = Aeon::Timekeeper.within(span: period)
      Redis.current.set(key, JSON.dump(refreshed), ex: Aeon::CacheManager::TTL_DEFAULT)
      Argus.emit("aeon.refresher.refreshed", meta: { key:, ttl: })
    end
  end

  def self.decode_period_from_key(key)
    # optional encoded metadata for reconstruction
  end
end
```

---

## 4️⃣ Physical View

| Attribute    | Description                          |
|--------------|--------------------------------------|
| Runtime      | Sidekiq / Cron job (Aeon::Heartbeat) |
| Store        | Redis and Postgres                   |
| Dependencies | Timekeeper, CacheManager             |

---

## ➕ 1 Scenario View

### Scenario A: Cache Prewarming
At 23:45, Refresher detects next day’s window TTL → rebuilds early.

### Scenario B: Burst Invalidations
Several timestamps updated → Refresher regenerates windows in parallel.

**Observability:**  
Metrics `aeon_refresher_runs_total`, `aeon_refresher_duration_seconds`.

---