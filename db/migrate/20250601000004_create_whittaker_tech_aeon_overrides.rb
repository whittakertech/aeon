class CreateWhittakerTechAeonOverrides < ActiveRecord::Migration[7.1]
  def change
    create_table :whittaker_tech_aeon_overrides, id: :uuid do |t|
      t.uuid    :occurrence_id,          null: false
      t.tstzrange :replacement_time_range
      t.boolean :canceled,               null: false, default: false

      t.timestamps
    end

    add_index :whittaker_tech_aeon_overrides,
              :occurrence_id,
              unique: true,
              name: :idx_aeon_overrides_unique_per_occurrence

    add_foreign_key :whittaker_tech_aeon_overrides,
                    :whittaker_tech_aeon_occurrences,
                    column: :occurrence_id
  end
end
