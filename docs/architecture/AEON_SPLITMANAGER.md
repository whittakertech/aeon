---
owner: "WhittakerTech"
status: "Prototype"
phase: "4"
depends_on: [Aeon::Mutator, Aeon::DeepCloneService, Aeon::ExceptionManager]
consumed_by: [Aeon::UI, Aeon::Refresher]
last_updated: "2025-11-14"
---

# 🪢 Aeon::SplitManager – 4 + 1 Architecture

> *Where one timeline becomes two.*

---

## 1️⃣ Logical View

**Purpose:**  
Handles complex series splits—when recurring events branch into independent streams.

**Responsibilities**
- Detect overlap points between two recurrences.
- Deep-clone from split point forward.
- Add exception cutoff to original series.
- Propagate metadata and caching updates.

---

## 2️⃣ Process View

1. User selects occurrence to split.
2. Manager identifies its timestamp.
3. Calls `ExceptionManager.end_recurrence_at`.
4. Calls `DeepCloneService.call` with new start.
5. Creates two distinct recurring streams.
6. Invalidates caches and emits Argus event.

---

## 3️⃣ Development View

**File:** `app/services/aeon/split_manager.rb`

```ruby
class Aeon::SplitManager
  def self.call(occurrence)
    original = occurrence.timestamp
    cutoff = occurrence.starts_at
    Aeon::ExceptionManager.end_recurrence_at(original, cutoff)
    clone = Aeon::DeepCloneService.call(original, starts_at: cutoff)
    Argus.emit("aeon.split.created", meta: { from: original.id, to: clone.id })
    [original, clone]
  end
end
```

---

## 4️⃣ Physical View

| Attribute     | Description                        |
|---------------|------------------------------------|
| Store         | Postgres (Aeon::Timestamp)         |
| Dependencies  | DeepCloneService, ExceptionManager |
| Observability | Argus `aeon.split.created`         |

---

## ➕ 1 Scenario View

### Scenario A – Semester Boundary
A weekly lecture series splits into Spring and Summer semesters.  
SplitManager ends Spring recurrence on May 31, creates new Summer series.

### Scenario B – Policy Change
Pricing schedule changes mid-year; SplitManager duplicates future entries.

---