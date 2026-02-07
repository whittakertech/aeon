class CreateAeonTables < ActiveRecord::Migration[7.1]
  def change
    # ── Allocations ──────────────────────────────────────────────────────
    create_table table("allocations"), id: :uuid do |t|
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

    add_index table("allocations"),
              [:schedulable_type, :schedulable_id],
              name: :idx_aeon_allocations_on_schedulable

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX idx_aeon_allocations_active_per_schedulable
            ON #{table("allocations")} (schedulable_type, schedulable_id)
            WHERE valid_to IS NULL;
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS #{schema_name}.idx_aeon_allocations_active_per_schedulable;
        SQL
      end
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE #{table("allocations")}
            ADD CONSTRAINT fk_aeon_allocations_supersedes
            FOREIGN KEY (supersedes_allocation_id)
            REFERENCES #{table("allocations")} (id);
        SQL
      end
      dir.down do
        execute <<~SQL
          ALTER TABLE #{table("allocations")}
            DROP CONSTRAINT IF EXISTS fk_aeon_allocations_supersedes;
        SQL
      end
    end

    # ── Occurrences ──────────────────────────────────────────────────────
    create_table table("occurrences"), id: :uuid do |t|
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
          ALTER TABLE #{table("occurrences")}
            ADD CONSTRAINT fk_aeon_occurrences_allocation
            FOREIGN KEY (allocation_id)
            REFERENCES #{table("allocations")} (id);
        SQL
        execute <<~SQL
          ALTER TABLE #{table("occurrences")}
            ADD CONSTRAINT fk_aeon_occurrences_invalidated_by
            FOREIGN KEY (invalidated_by_allocation_id)
            REFERENCES #{table("allocations")} (id);
        SQL
      end
      dir.down do
        execute <<~SQL
          ALTER TABLE #{table("occurrences")}
            DROP CONSTRAINT IF EXISTS fk_aeon_occurrences_invalidated_by;
        SQL
        execute <<~SQL
          ALTER TABLE #{table("occurrences")}
            DROP CONSTRAINT IF EXISTS fk_aeon_occurrences_allocation;
        SQL
      end
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE INDEX idx_aeon_occurrences_on_time_range
            ON #{table("occurrences")}
            USING gist (time_range);
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS #{schema_name}.idx_aeon_occurrences_on_time_range;
        SQL
      end
    end

    add_index table("occurrences"),
              [:allocation_id, :starts_at],
              unique: true,
              name: :idx_aeon_occurrences_unique_per_allocation

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE INDEX idx_aeon_occurrences_active
            ON #{table("occurrences")} (allocation_id, starts_at)
            WHERE invalidated_at IS NULL AND purged_at IS NULL;
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS #{schema_name}.idx_aeon_occurrences_active;
        SQL
      end
    end

    # ── Overrides ────────────────────────────────────────────────────────
    create_table table("overrides"), id: :uuid do |t|
      t.uuid    :occurrence_id,          null: false
      t.tstzrange :replacement_time_range
      t.boolean :canceled,               null: false, default: false

      t.timestamps
    end

    add_index table("overrides"),
              :occurrence_id,
              unique: true,
              name: :idx_aeon_overrides_unique_per_occurrence

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE #{table("overrides")}
            ADD CONSTRAINT fk_aeon_overrides_occurrence
            FOREIGN KEY (occurrence_id)
            REFERENCES #{table("occurrences")} (id);
        SQL
      end
      dir.down do
        execute <<~SQL
          ALTER TABLE #{table("overrides")}
            DROP CONSTRAINT IF EXISTS fk_aeon_overrides_occurrence;
        SQL
      end
    end
  end

  private

  def prefix
    WhittakerTech::Aeon.table_name_prefix
  end

  def schema_name
    prefix.delete_suffix(".")
  end

  def table(name)
    "#{prefix}#{name}"
  end
end
