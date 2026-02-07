class RenameOccurrenceRetentionPolicyToDisposalPolicy < ActiveRecord::Migration[7.1]
  def change
    rename_column "wt_aeon.allocations", :occurrence_retention_policy, :disposal_policy
  end
end
