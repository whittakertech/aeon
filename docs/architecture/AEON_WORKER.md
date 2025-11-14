---
owner: "WhittakerTech"
status: "Legacy"
phase: "2"
depends_on: [Aeon::Timestamp, Argus]
consumed_by: [Mercury, Oscar, Ensemblize]
last_updated: "2025-11-14"
---

# ⚙️ Aeon::Worker – 4 + 1 Architecture

> *Aeon’s original heartbeat — now a legacy bridge to the past.*

---

## 1️⃣ Logical View

**Purpose:**  
`Aeon::Worker` provides background job orchestration for engines that still depend on Sidekiq and Redis-based scheduling.  
Although Aeon’s primary role is now temporal modeling, Worker remains for compatibility with early WhittakerTech systems (e.g., Mercury mailers, Oscar purge jobs).

**Responsibilities**
- Schedule jobs via Sidekiq.
- Enforce idempotency and retry policies.
- Emit lifecycle events via Argus.

---

## 2️⃣ Process View

1. Job enqueued using `Aeon::Worker.schedule(job_class, at:, args:, idempotency_key:)`.
2. Worker validates and creates job record (`Aeon::Job`).
3. Sidekiq executes at `scheduled_at`.
4. On success/failure, Argus logs events and RetryPolicy re-enqueues if needed.

---

## 3️⃣ Development View

**File:** `app/workers/aeon/worker.rb`

```ruby
class Aeon::Worker
  def self.schedule(job_class, at:, args:, idempotency_key: nil)
    return if idempotency_key && Redis.current.exists?("aeon:lock:#{idempotency_key}")
    Redis.current.set("aeon:lock:#{idempotency_key}", true, ex: 24.hours.to_i) if idempotency_key
    Sidekiq::Client.enqueue_to("aeon", job_class, args.merge(run_at: at))
    Argus.emit("aeon.worker.scheduled", meta: { job_class:, at:, idempotency_key: })
  end
end
```

---

## 4️⃣ Physical View

| Attribute     | Description                                               |
|---------------|-----------------------------------------------------------|
| Runtime       | Sidekiq (separate pool)                                   |
| Store         | Redis (locks), Postgres (jobs)                            |
| Observability | Argus `aeon.worker.completed`, `aeon.worker.failed`       |
| Deprecation   | Legacy layer; will be moved to optional gem `aeon-worker` |

---

## ➕ 1 Scenario View

### Scenario A: Scheduled Email (Mercury)
```ruby
Aeon::Worker.schedule(Mercury::SendMessageJob, at: 10.minutes.from_now, args: { id: 42 })
```

### Scenario B: Cleanup Job (Oscar)
Daily purge enqueued with cron-style Aeon schedule.

**Security:**  
Internal-only; requires trusted job classes.  
**Metrics:**  
`aeon_worker_jobs_total`.

---