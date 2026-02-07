# Installation

## Requirements

- Ruby >= 3.1
- Rails ~> 7.1
- PostgreSQL 16+
- UUID primary keys on host models that include `Schedulable`

## Setup

Add the gem to your Gemfile:

```ruby
gem 'whittaker_tech-aeon'
```

Install the bundle:

```sh
bundle install
```

Run the install generator (copies the initializer and migrations into your app):

```sh
rails generate whittaker_tech:aeon:install
```

Optionally edit the generated initializer at `config/initializers/aeon.rb` to customize settings.

Run the copied migrations to create the `wt_aeon` schema and tables:

```sh
rails db:migrate
```

## What the Generator Creates

The install generator copies:

1. **Initializer** (`config/initializers/aeon.rb`) — a `WhittakerTech::Aeon.configure` block with sensible defaults
2. **Migrations** — creates the `wt_aeon` PostgreSQL schema with three tables:
    - `wt_aeon.allocations` — immutable temporal laws
    - `wt_aeon.occurrences` — materialized predictions with GiST-indexed `tstzrange`
    - `wt_aeon.overrides` — surgical single-instance deviations

## Host Model Requirements

Any model that includes `WhittakerTech::Aeon::Schedulable` **must** use UUID primary keys:

```ruby
class CreateLessons < ActiveRecord::Migration[7.1]
  def change
    create_table :lessons, id: :uuid do |t|
      t.string :title, null: false
      t.timestamps
    end
  end
end
```

This is required because all Aeon foreign keys and polymorphic IDs are UUIDs.
