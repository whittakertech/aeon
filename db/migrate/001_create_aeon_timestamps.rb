class CreateAeonTimestamps < ActiveRecord::Migration[7.1]
  def change
    create_table :aeon_timestamps, id: :uuid do |t|
      # Polymorphic reference to schedulable host
      t.references :schedulable, polymorphic: true, type: :uuid, null: false, index: true

      # Core temporal data
      t.datetime :starts_at, null: false
      t.bigint :duration, null: false, comment: "Duration in seconds"
      t.string :timezone, default: "UTC", null: false

      # Recurrence rules (IceCube serialized)
      t.jsonb :repetition_rules, default: {}, null: false

      # Metadata and context
      t.jsonb :meta, default: {}, null: false

      t.timestamps
    end

    add_index :aeon_timestamps, :starts_at
    add_index :aeon_timestamps, [:schedulable_type, :schedulable_id, :starts_at]
  end
end
