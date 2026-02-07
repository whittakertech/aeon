class CreateAeonOverrides < ActiveRecord::Migration[7.1]
  def change
    create_table "wt_aeon.overrides", id: :uuid do |t|
      t.uuid    :occurrence_id,          null: false
      t.tstzrange :replacement_time_range
      t.boolean :canceled,               null: false, default: false

      t.timestamps
    end

    add_index "wt_aeon.overrides",
              :occurrence_id,
              unique: true,
              name: :idx_aeon_overrides_unique_per_occurrence

    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE wt_aeon.overrides
            ADD CONSTRAINT fk_aeon_overrides_occurrence
            FOREIGN KEY (occurrence_id)
            REFERENCES wt_aeon.occurrences (id);
        SQL
      end
      dir.down do
        execute <<~SQL
          ALTER TABLE wt_aeon.overrides
            DROP CONSTRAINT IF EXISTS fk_aeon_overrides_occurrence;
        SQL
      end
    end
  end
end
