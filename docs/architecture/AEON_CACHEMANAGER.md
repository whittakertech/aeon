---
owner: "WhittakerTech"
status: "Stable"
phase: "3"
depends_on: [Aeon::CacheWindow]
consumed_by: [Aeon::Timekeeper, Aeon::Refresher]
last_updated: "2025-11-14"
---

# ⚙️ Aeon::CacheManager – 4 + 1 Architecture

> *Keeps time’s memory close, coherent, and fast.*

---

## 1️⃣ Logical View

**Purpose:**  
`Aeon::CacheManager` is Aeon’s unified caching interface.  
It reads and writes serialized occurrences to Redis, with optional in-process memoization.

**Responsibilities**
- `fetch` → read or compute and store.
- `write` / `delete` / `clear_expired`.
- Enforce TTL and size limits.
- Support tag-based invalidation (`topic:` prefix).

---

## 2️⃣ Process View

1. Timekeeper requests occurrences for a period.
2. CacheManager computes key via `CacheWindow.key_for`.
3. If found → deserialize and return.
4. If missing → execute block, store serialized JSON, set TTL.
5. Refresher periodically rehydrates near-expiring keys.

---

## 3️⃣ Development View

**File:** `app/services/aeon/cache_manager.rb`

```ruby
class Aeon::CacheManager
  TTL_DEFAULT = 6.hours

  def self.fetch(key, ttl: TTL_DEFAULT)
    cached = Redis.current.get(key)
    return deserialize(cached) if cached
    value = yield
    Redis.current.set(key, serialize(value), ex: ttl.to_i)
    value
  end

  def self.delete(key) = Redis.current.del(key)
  def self.clear_expired; end # handled by Redis TTL
  def self.serialize(v)   = JSON.dump(v)
  def self.deserialize(v) = JSON.parse(v, symbolize_names: true)
end
```

---

## 4️⃣ Physical View

| Attribute     | Description                           |
|---------------|---------------------------------------|
| Store         | Redis 6+                              |
| TTL           | Configurable (6 h default)            |
| Index         | key prefix `aeon:cache:`              |
| Observability | Argus metrics `aeon_cache_hits_total` |

---

## ➕ 1 Scenario View

### Scenario A: Cache Hit
```ruby
CacheManager.fetch("aeon:cache:task:abc") { slow_query }
# => returns cached payload
```

### Scenario B: Cache Miss
Computes from source and stores new entry.

### Scenario C: Expiry
After TTL passes, Refresher detects and rebuilds.

---