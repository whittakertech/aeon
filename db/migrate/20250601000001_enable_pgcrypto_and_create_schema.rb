class EnablePgcryptoAndCreateSchema < ActiveRecord::Migration[7.1]
  def change
    enable_extension "pgcrypto"

    reversible do |dir|
      dir.up do
        execute "CREATE SCHEMA IF NOT EXISTS wt_aeon"
      end
      dir.down do
        execute "DROP SCHEMA IF EXISTS wt_aeon CASCADE"
      end
    end
  end
end
