module Production
  # Cancels an active run and restocks every ingredient that was
  # deducted at start-time. After this fires, the inventory ledger
  # contains a matched +/− pair for the run; the run row stays as a
  # historical record (state = :canceled) so reports still see it.
  class CancelRun < ApplicationCommand
    option :run

    def call
      return failure([ "transition_not_allowed" ]) unless run.aasm.may_fire_event?(:cancel)

      ActiveRecord::Base.transaction do
        Production::RestockIngredients.call(run: run)
        run.cancel!
      end

      success(run)
    end
  end
end
