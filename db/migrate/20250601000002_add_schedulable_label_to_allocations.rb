# frozen_string_literal: true

class AddSchedulableLabelToAllocations < ActiveRecord::Migration[7.1]
  def change
    # ── Add column with default for backfill ─────────────────────────────
    add_column table("allocations"), :schedulable_label, :string, limit: 64, null: false, default: "primary"
    change_column_default table("allocations"), :schedulable_label, from: "primary", to: nil

    # ── Recreate partial unique index to include label ───────────────────
    reversible do |dir|
      dir.up do
        execute <<~SQL
          DROP INDEX IF EXISTS #{schema_name}.idx_aeon_allocations_active_per_schedulable;
        SQL
        execute <<~SQL
          CREATE UNIQUE INDEX idx_aeon_allocations_active_per_schedulable
            ON #{table("allocations")} (schedulable_type, schedulable_id, schedulable_label)
            WHERE valid_to IS NULL;
        SQL
      end
      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS #{schema_name}.idx_aeon_allocations_active_per_schedulable;
        SQL
        execute <<~SQL
          CREATE UNIQUE INDEX idx_aeon_allocations_active_per_schedulable
            ON #{table("allocations")} (schedulable_type, schedulable_id)
            WHERE valid_to IS NULL;
        SQL
      end
    end

    # ── Recreate polymorphic lookup index to include label ────────────────
    remove_index table("allocations"),
                 name: :idx_aeon_allocations_on_schedulable

    add_index table("allocations"),
              [:schedulable_type, :schedulable_id, :schedulable_label],
              name: :idx_aeon_allocations_on_schedulable

    # ── Replace PG trigger to add schedulable_label to tier 1 ────────────
    reversible do |dir|
      dir.up do
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
               (OLD.schedulable_id IS DISTINCT FROM NEW.schedulable_id) OR
               (OLD.schedulable_label IS DISTINCT FROM NEW.schedulable_label) THEN
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
      end

      dir.down do
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
