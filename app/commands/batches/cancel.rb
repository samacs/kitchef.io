module Batches
  # Cancels an active batch and restocks every ingredient that was
  # deducted at start-time. After this fires, the inventory ledger
  # contains a matched +/− pair for the batch; the batch row stays as
  # a historical record (state = :canceled) so reports still see it.
  class Cancel < ApplicationCommand
    option :batch

    def call
      return failure([ "transition_not_allowed" ]) unless batch.aasm.may_fire_event?(:cancel)

      ActiveRecord::Base.transaction do
        Batches::RestockIngredients.call(batch: batch)
        batch.cancel!
        # Free any order items that were consuming from this batch:
        # rebind to another active batch when possible, else flag
        # oversold so the kanban surfaces it.
        Batches::ReleaseConsumption.call(batch: batch)
      end

      success(batch)
    end
  end
end
