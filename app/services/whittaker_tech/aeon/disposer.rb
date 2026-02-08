# frozen_string_literal: true

module WhittakerTech
  module Aeon
    # Stateless service that soft-deletes invalidated {Occurrence} rows according
    # to a policy hierarchy: per-allocation +disposal_policy+ override, falling
    # back to the global {Configuration#disposal_policy} default.
    #
    # Supported policies:
    # - +:ephemeral+ — purge immediately on next Disposer run
    # - +:windowed+ — purge after {Configuration#invalidated_retention_window}
    # - +:historical+ / +:permanent+ — never auto-purge
    #
    # Sets +purged_at+ in bounded batches. Never hard-deletes.
    #
    # @example Run a disposal pass
    #   Disposer.call(batch_size: 500)
    #   # => 42
    class Disposer
      # Maximum rows to purge per policy pass.
      DISPOSAL_BATCH_SIZE = 1_000

      # @param batch_size [Integer] max rows to purge per policy pass
      # @return [Integer] total rows purged across all passes
      def self.call(batch_size: DISPOSAL_BATCH_SIZE)
        new(batch_size: batch_size).call
      end

      # @param batch_size [Integer] max rows to purge per policy pass
      def initialize(batch_size:)
        @batch_size = batch_size
      end

      # Runs ephemeral and windowed purge passes.
      #
      # @return [Integer] total rows purged
      def call
        purged = 0
        purged += purge_ephemeral!
        purged += purge_windowed!
        purged
      end

      private

      # Purges invalidated occurrences whose allocation has +:ephemeral+ policy,
      # regardless of invalidation age.
      #
      # @return [Integer] rows purged
      def purge_ephemeral!
        scope = purgeable_scope.where(allocation_id: allocation_ids_for_policy('ephemeral'))
        execute_purge(scope)
      end

      # Purges invalidated occurrences whose effective policy is +:windowed+ AND
      # whose +invalidated_at+ is older than the retention window.
      #
      # @return [Integer] rows purged
      def purge_windowed!
        cutoff = Time.current - WhittakerTech::Aeon.configuration.invalidated_retention_window
        scope = purgeable_scope
          .where(allocation_id: allocation_ids_for_policy('windowed'))
          .where(invalidated_at: ...cutoff)
        execute_purge(scope)
      end

      # Base scope: invalidated but not yet purged.
      #
      # @return [ActiveRecord::Relation]
      def purgeable_scope
        Occurrence.where.not(invalidated_at: nil).where(purged_at: nil)
      end

      # Returns allocation IDs matching a specific effective policy. An
      # allocation's effective policy is its own +disposal_policy+ column,
      # falling back to the global default when NULL.
      #
      # @param policy_string [String] the policy to match
      # @return [ActiveRecord::Relation] subquery of allocation IDs
      def allocation_ids_for_policy(policy_string)
        global = WhittakerTech::Aeon.configuration.disposal_policy.to_s
        scope = Allocation.select(:id)
        if policy_string == global
          scope.where(disposal_policy: [policy_string, nil])
        else
          scope.where(disposal_policy: policy_string)
        end
      end

      # Batched UPDATE via subquery — PG has no +UPDATE ... LIMIT+.
      # Uses +pluck(:id)+ + +where(id:)+ to enforce the batch limit.
      #
      # @param scope [ActiveRecord::Relation]
      # @return [Integer] rows purged
      def execute_purge(scope)
        ids = scope.limit(@batch_size).pluck(:id)
        return 0 if ids.empty?

        Occurrence.where(id: ids).update_all(purged_at: Time.current)
      end
    end
  end
end
