class CreateAeonAllocations < ActiveRecord::Migration[7.1]
  def change
    create_table "wt_aeon.allocations", id: :uuid do |t|
      t.string   :schedulable_type,            null: false
      t.uuid     :schedulable_id,              null: false
      t.integer  :temporal_kind,               null: false
      t.timestamptz :starts_at,                null: false
      t.integer  :duration_seconds
      t.string   :timezone
      t.jsonb    :rrule
      t.timestamptz :valid_from,               null: false
      t.timestamptz :valid_to
      t.timestamptz :projected_until,          null: false
      t.uuid     :supersedes_allocation_id
      t.string   :disposal_policy
      t.string   :attachment_version_ref

      t.timestamps
    end

    add_index "wt_aeon.allocations",
              [:schedulable_type, :schedulable_id],
              name: :idx_aeon_allocations_on_schedulable

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX idx_aeon_allocations_active_per_schedulable
            ON wt_aeon.allocations (schedulable_type, schedulable_id)
            WHERE valid_to IS NULL;
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS wt_aeon.idx_aeon_allocations_active_per_schedulable;
        SQL
      end
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE wt_aeon.allocations
            ADD CONSTRAINT fk_aeon_allocations_supersedes
            FOREIGN KEY (supersedes_allocation_id)
            REFERENCES wt_aeon.allocations (id);
        SQL
      end
      dir.down do
        execute <<~SQL
          ALTER TABLE wt_aeon.allocations
            DROP CONSTRAINT IF EXISTS fk_aeon_allocations_supersedes;
        SQL
      end
    end
  end
end
