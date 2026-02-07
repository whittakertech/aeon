class CreateAeonSchema < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      dir.up do
        enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
        execute "CREATE SCHEMA IF NOT EXISTS #{schema_name}"
      end
      dir.down do
        execute "DROP SCHEMA IF EXISTS #{schema_name} CASCADE"
        # Do NOT disable pgcrypto — other engines may depend on it
      end
    end
  end

  private

  def schema_name
    WhittakerTech::Aeon.table_name_prefix.delete_suffix(".")
  end
end
