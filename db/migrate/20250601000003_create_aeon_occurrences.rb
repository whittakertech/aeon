class CreateAeonOccurrences < ActiveRecord::Migration[7.1]
  def change
    create_table "wt_aeon.occurrences", id: :uuid do |t|
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

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE wt_aeon.occurrences
            ADD CONSTRAINT fk_aeon_occurrences_allocation
            FOREIGN KEY (allocation_id)
            REFERENCES wt_aeon.allocations (id);
        SQL
        execute <<~SQL
          ALTER TABLE wt_aeon.occurrences
            ADD CONSTRAINT fk_aeon_occurrences_invalidated_by
            FOREIGN KEY (invalidated_by_allocation_id)
            REFERENCES wt_aeon.allocations (id);
        SQL
      end
      dir.down do
        execute <<~SQL
          ALTER TABLE wt_aeon.occurrences
            DROP CONSTRAINT IF EXISTS fk_aeon_occurrences_invalidated_by;
        SQL
        execute <<~SQL
          ALTER TABLE wt_aeon.occurrences
            DROP CONSTRAINT IF EXISTS fk_aeon_occurrences_allocation;
        SQL
      end
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE INDEX idx_aeon_occurrences_on_time_range
            ON wt_aeon.occurrences
            USING gist (time_range);
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS wt_aeon.idx_aeon_occurrences_on_time_range;
        SQL
      end
    end

    add_index "wt_aeon.occurrences",
              [:allocation_id, :starts_at],
              unique: true,
              name: :idx_aeon_occurrences_unique_per_allocation

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE INDEX idx_aeon_occurrences_active
            ON wt_aeon.occurrences (allocation_id, starts_at)
            WHERE invalidated_at IS NULL AND purged_at IS NULL;
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS wt_aeon.idx_aeon_occurrences_active;
        SQL
      end
    end
  end
end
