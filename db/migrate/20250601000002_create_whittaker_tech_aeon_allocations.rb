class CreateWhittakerTechAeonAllocations < ActiveRecord::Migration[7.1]
  def change
    create_table :whittaker_tech_aeon_allocations, id: :uuid do |t|
      t.string   :schedulable_type,            null: false
      t.string   :schedulable_id,              null: false
      t.integer  :temporal_kind,               null: false
      t.timestamptz :starts_at,                null: false
      t.integer  :duration_seconds
      t.string   :timezone
      t.jsonb    :rrule
      t.timestamptz :valid_from,               null: false
      t.timestamptz :valid_to
      t.timestamptz :projected_until,          null: false
      t.uuid     :supersedes_allocation_id
      t.string   :occurrence_retention_policy
      t.string   :attachment_version_ref

      t.timestamps
    end

    add_index :whittaker_tech_aeon_allocations,
              [:schedulable_type, :schedulable_id],
              name: :idx_aeon_allocations_on_schedulable

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX idx_aeon_allocations_active_per_schedulable
            ON whittaker_tech_aeon_allocations (schedulable_type, schedulable_id)
            WHERE valid_to IS NULL;
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS idx_aeon_allocations_active_per_schedulable;
        SQL
      end
    end

    add_foreign_key :whittaker_tech_aeon_allocations,
                    :whittaker_tech_aeon_allocations,
                    column: :supersedes_allocation_id
  end
end
