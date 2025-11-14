---
owner: "WhittakerTech"
status: "Stable"
phase: "3"
depends_on: [Aeon::Timestamp]
consumed_by: [Aeon::Mutator]
last_updated: "2025-11-14"
---

# 🧫 Aeon::DeepCloneService – 4 + 1 Architecture

> *Copies time and the things bound to it without breaking the threads.*

---

## 1️⃣ Logical View

**Purpose:**  
Performs deep duplication of `Aeon::Timestamp` and its attached ` schedulable ` record.

**Responsibilities**
- Clone the timestamp record.
- Optionally clone the associated host record (`schedulable`).
- Preserve foreign keys and associations in a single transaction.
- Optionally apply parameter overrides.

---

## 2️⃣ Process View

1. Mutator calls `DeepCloneService.call(timestamp, params)`.
2. Service duplicates the timestamp and attached model.
3. Applies attribute overrides.
4. Commits transaction; returns new timestamp instance.

---

## 3️⃣ Development View

**File:** `app/services/aeon/deep_clone_service.rb`

```ruby
class Aeon::DeepCloneService
  def self.call(timestamp, overrides = {})
    ActiveRecord::Base.transaction do
      new_schedulable = timestamp.schedulable.deep_dup
      new_schedulable.assign_attributes(overrides.except(:starts_at, :duration))
      new_schedulable.save!
      new_timestamp = timestamp.dup
      new_timestamp.assign_attributes(overrides)
      new_timestamp.schedulable = new_schedulable
      new_timestamp.save!
      new_timestamp
    end
  end
end
```

---

## 4️⃣ Physical View

| Attribute     | Description                          |
|---------------|--------------------------------------|
| Store         | Postgres (transactional)             |
| Concurrency   | Atomic via ActiveRecord transactions |
| Observability | Argus `aeon.deepclone.created`       |

---

## ➕ 1 Scenario View

### Scenario A – Cloning a Single Event
Called by Mutator#change_this; new timestamp inherits series rules.

### Scenario B – Partial Clone
Pass overrides ( title, location ) to create variant instances.

---