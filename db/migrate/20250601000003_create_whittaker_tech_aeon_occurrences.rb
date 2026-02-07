class CreateWhittakerTechAeonOccurrences < ActiveRecord::Migration[7.1]
  def change
    create_table :whittaker_tech_aeon_occurrences, id: :uuid do |t|
      t.uuid        :allocation_id,                null: false
      t.tstzrange   :time_range,                   null: false
      t.timestamptz :starts_at,                    null: false
      t.timestamptz :ends_at,                      null: false
      t.integer     :state,                        null: false, default: 0
      t.string      :projection_fingerprint
      t.timestamptz :projected_at
      t.timestamptz :invalidated_at
      t.uuid        :invalidated_by_allocation_id
      t.timestamptz :purged_at

      t.timestamps
    end

    add_foreign_key :whittaker_tech_aeon_occurrences,
                    :whittaker_tech_aeon_allocations,
                    column: :allocation_id

    add_foreign_key :whittaker_tech_aeon_occurrences,
                    :whittaker_tech_aeon_allocations,
                    column: :invalidated_by_allocation_id

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE INDEX idx_aeon_occurrences_on_time_range
            ON whittaker_tech_aeon_occurrences
            USING gist (time_range);
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS idx_aeon_occurrences_on_time_range;
        SQL
      end
    end

    add_index :whittaker_tech_aeon_occurrences,
              [:allocation_id, :starts_at],
              unique: true,
              name: :idx_aeon_occurrences_unique_per_allocation

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE INDEX idx_aeon_occurrences_active
            ON whittaker_tech_aeon_occurrences (allocation_id, starts_at)
            WHERE invalidated_at IS NULL AND purged_at IS NULL;
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS idx_aeon_occurrences_active;
        SQL
      end
    end
  end
end
