# frozen_string_literal: true

class CreateAeonSchemaAndTables < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      dir.up do
        enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
        execute "CREATE SCHEMA IF NOT EXISTS #{schema_name}"
      end
      dir.down do
        execute "DROP SCHEMA IF EXISTS #{schema_name} CASCADE"
      end
    end

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

    # ── Immutability triggers ────────────────────────────────────────────
    reversible do |dir|
      dir.up do
        # Hard block on occurrence coordinate fields (no bypass mechanism)
        execute <<~SQL
          CREATE OR REPLACE FUNCTION #{schema_name}.guard_occurrence_coordinates()
          RETURNS trigger AS $$
          BEGIN
            IF (OLD.time_range IS DISTINCT FROM NEW.time_range) OR
               (OLD.starts_at IS DISTINCT FROM NEW.starts_at) OR
               (OLD.ends_at IS DISTINCT FROM NEW.ends_at) OR
               (OLD.allocation_id IS DISTINCT FROM NEW.allocation_id) THEN
              RAISE EXCEPTION 'cannot mutate coordinate fields on a persisted Occurrence'
                USING ERRCODE = 'raise_exception';
            END IF;
            RETURN NEW;
          END;
          $$ LANGUAGE plpgsql;
        SQL

        execute <<~SQL
          CREATE TRIGGER guard_occurrence_coordinates
            BEFORE UPDATE ON #{table("occurrences")}
            FOR EACH ROW EXECUTE FUNCTION #{schema_name}.guard_occurrence_coordinates();
        SQL

        # Two-tier allocation guard:
        #   Tier 1 (hard-blocked): identity/temporal fields — no bypass
        #   Tier 2 (service-mutable): valid_to, projected_until — bypass via session variable
        execute <<~SQL
          CREATE OR REPLACE FUNCTION #{schema_name}.guard_allocation_temporal_fields()
          RETURNS trigger AS $$
          BEGIN
            -- Tier 1: hard-blocked fields (no bypass)
            IF (OLD.temporal_kind IS DISTINCT FROM NEW.temporal_kind) OR
               (OLD.starts_at IS DISTINCT FROM NEW.starts_at) OR
               (OLD.duration_seconds IS DISTINCT FROM NEW.duration_seconds) OR
               (OLD.timezone IS DISTINCT FROM NEW.timezone) OR
               (OLD.rrule IS DISTINCT FROM NEW.rrule) OR
               (OLD.valid_from IS DISTINCT FROM NEW.valid_from) OR
               (OLD.supersedes_allocation_id IS DISTINCT FROM NEW.supersedes_allocation_id) OR
               (OLD.schedulable_type IS DISTINCT FROM NEW.schedulable_type) OR
               (OLD.schedulable_id IS DISTINCT FROM NEW.schedulable_id) THEN
              RAISE EXCEPTION 'cannot mutate temporal fields on a persisted Allocation'
                USING ERRCODE = 'raise_exception';
            END IF;

            -- Tier 2: service-mutable fields (bypass via session variable)
            IF current_setting('aeon.bypass_guard', true) = 'true' THEN
              RETURN NEW;
            END IF;

            IF (OLD.valid_to IS DISTINCT FROM NEW.valid_to) OR
               (OLD.projected_until IS DISTINCT FROM NEW.projected_until) THEN
              RAISE EXCEPTION 'cannot mutate temporal fields on a persisted Allocation'
                USING ERRCODE = 'raise_exception';
            END IF;

            RETURN NEW;
          END;
          $$ LANGUAGE plpgsql;
        SQL

        execute <<~SQL
          CREATE TRIGGER guard_allocation_temporal_fields
            BEFORE UPDATE ON #{table("allocations")}
            FOR EACH ROW EXECUTE FUNCTION #{schema_name}.guard_allocation_temporal_fields();
        SQL
      end

      dir.down do
        execute "DROP TRIGGER IF EXISTS guard_occurrence_coordinates ON #{table("occurrences")}"
        execute "DROP FUNCTION IF EXISTS #{schema_name}.guard_occurrence_coordinates()"
        execute "DROP TRIGGER IF EXISTS guard_allocation_temporal_fields ON #{table("allocations")}"
        execute "DROP FUNCTION IF EXISTS #{schema_name}.guard_allocation_temporal_fields()"
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
