---
owner: "WhittakerTech"
status: "Stable"
phase: "3"
depends_on: [Aeon::Timestamp]
consumed_by: [All Host Models]
last_updated: "2025-11-14"
---

# 🪞 Aeon::Schedulable – 4 + 1 Architecture

> *Lets any model become a keeper of time.*

---

## 1️⃣ Logical View

**Purpose:**  
`Aeon::Schedulable` is a Rails concern that grants host models the ability to attach schedules.  
It defines the `has_one_schedule` DSL and dynamically builds associations for timestamps.

**Responsibilities**
- Generate one or more `has_one :aeon_timestamp` associations per symbol.
- Accept nested attributes for mass assignment.
- Expose helper methods (`*_schedule`, `*_schedule_attributes=`).
- Delegate `to_period` and `next_occurrence` for ease of access.

---

## 2️⃣ Process View

1. Developer includes the concern:
   ```ruby
   include Aeon::Schedulable
   has_one_schedule :event
   has_one_schedule :deadline
   ```
2. Rails dynamically builds:
  - `has_one :event_schedule, class_name: "Aeon::Timestamp", as: :schedulable`
  - `accepts_nested_attributes_for :event_schedule`
3. When model saves, nested attributes create or update Aeon::Timestamp.
4. Timestamp changes trigger CacheInvalidation → Refresher → Timekeeper updates.

---

## 3️⃣ Development View

**File:** `app/models/concerns/aeon/schedulable.rb`

```ruby
module Aeon::Schedulable
  extend ActiveSupport::Concern

  class_methods do
    def has_one_schedule(name)
      assoc = "#{name}_schedule"
      has_one assoc.to_sym,
              as: :schedulable,
              class_name: "Aeon::Timestamp",
              dependent: :destroy
      accepts_nested_attributes_for assoc.to_sym
      define_method(name) { send(assoc)&.to_period }
    end
  end
end
```

---

## 4️⃣ Physical View

| Attribute     | Description                       |
|---------------|-----------------------------------|
| Layer         | ApplicationModel (Rails)          |
| Store         | Postgres (via Aeon::Timestamp)    |
| Dependencies  | Aeon::Timestamp, ActiveRecord     |
| Observability | Argus `aeon.schedulable.attached` |

---

## ➕ 1 Scenario View

### Scenario A: Attaching to Task
```ruby
class Task < ApplicationRecord
  include Aeon::Schedulable
  has_one_schedule :deadline
end
```
→ `task.deadline_schedule` automatically available.

### Scenario B: Multiple Schedules
A `Project` can define both `kickoff_schedule` and `review_schedule`.

**Security:**  
Nested attribute mass assignment is scoped to trusted contexts only.  
**Metrics:**  
`aeon_schedulable_associations_total`.

---