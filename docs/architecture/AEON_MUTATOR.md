---
owner: "WhittakerTech"
status: "MVP"
phase: "3"
depends_on: [Aeon::Timestamp, Aeon::RecurrenceAdapter, Aeon::DeepCloneService]
consumed_by: [Aeon::Timekeeper, Aeon::ExceptionManager]
last_updated: "2025-11-14"
---

# 🧬 Aeon::Mutator – 4 + 1 Architecture

> *Allows mortals to rewrite the flow of time—safely.*

---

## 1️⃣ Logical View

**Purpose:**  
`Aeon::Mutator` implements Aeon’s three editing modes:

| Mode                  | Behavior                                                                                     |
|-----------------------|----------------------------------------------------------------------------------------------|
| **Change This**       | Clones the current occurrence and adds an exception to the original recurrence.              |
| **Change All**        | Edits the attached timestamp directly (modifies the series).                                 |
| **Change All Future** | Splits the recurrence at the edit point → old series ends there, new series begins (cloned). |

**Responsibilities**
- Encapsulate editing logic for recurring records.
- Maintain referential integrity with polymorphic ` schedulable `.
- Apply IceCube exception rules to preserve temporal truth.

---

## 2️⃣ Process View

1. User invokes edit on an occurrence.
2. Mutator determines scope ( this / all / future ).
3. For “this” or “future”, calls `DeepCloneService`.
4. Original timestamp’s IceCube schedule is updated with an exception date.
5. Argus logs mutation event; CacheInvalidation clears affected windows.

---

## 3️⃣ Development View

**File:** `app/services/aeon/mutator.rb`

```ruby
class Aeon::Mutator
  def self.change_this(occurrence, params)
    timestamp = occurrence.timestamp
    clone = Aeon::DeepCloneService.call(timestamp, params)
    Aeon::ExceptionManager.add_exception(timestamp, occurrence.starts_at)
    clone
  end

  def self.change_all(timestamp, params)
    timestamp.update!(params)
    timestamp
  end

  def self.change_all_future(occurrence, params)
    original = occurrence.timestamp
    Aeon::ExceptionManager.end_recurrence_at(original, occurrence.starts_at)
    Aeon::DeepCloneService.call(original, params.merge(starts_at: occurrence.starts_at))
  end
end
```

---

## 4️⃣ Physical View

| Attribute     | Description                         |
|---------------|-------------------------------------|
| Store         | Postgres (Aeon::Timestamp)          |
| Dependencies  | DeepCloneService, ExceptionManager  |
| Observability | Argus `aeon.mutator.changed` events |

---

## ➕ 1 Scenario View

### Scenario A – Change This
User moves a single meeting → Mutator clones timestamp, adds exception.

### Scenario B – Change All
Edits apply to entire series, invalidating caches.

### Scenario C – Change All Future
Mutator splits recurrence into two chronological threads.

**Security:** Only authorized user contexts may invoke mutations.  
**Metrics:** `aeon_mutator_operations_total`.
---