module Orders
  # Whole-column bulk transition. Finds every eligible order in the
  # account for the event's "from" state and fires the AASM event on each
  # in declaration order. Sequential (not parallel) so the per-card Turbo
  # broadcasts stay ordered — parallel transitions would race the response
  # and leave the kanban inconsistent for a beat.
  #
  # Canceled orders aren't in the live state columns by definition, so no
  # special exclusion. `delivered` / `canceled` are immutable and never
  # eligible for a forward transition. The `failed` bucket only collects
  # orders that were candidates AND the transition refused them (e.g.
  # pickup pedidos on a `ship` event — AASM guard returns false).
  class BulkTransition < ApplicationCommand
    # Each event can fire only from its declared source state. "To confirm
    # a column" means: confirm every `placed` order. "To start production
    # on a column" means: start_production on every `confirmed` order. Etc.
    EVENT_SOURCE_STATE = {
      confirm:          "placed",
      start_production: "confirmed",
      mark_ready:       "in_production",
      ship:             "ready"
    }.freeze

    Outcome = Data.define(:succeeded, :failed) do
      def succeeded_count = succeeded.size
      def failed_count    = failed.size
    end

    option :account
    option :event

    def call
      sym = event.to_sym
      return failure([ "unsupported_event" ]) unless EVENT_SOURCE_STATE.key?(sym)

      source_state = EVENT_SOURCE_STATE.fetch(sym)
      candidates = account.orders.kept
        .where(state: source_state)
        .order(:position, :id)

      outcome = Outcome.new(succeeded: [], failed: [])
      ActiveRecord::Base.transaction do
        candidates.each do |order|
          if order.aasm.may_fire_event?(sym) && order.public_send("#{sym}!")
            outcome.succeeded << order
          else
            outcome.failed << order
          end
        end
      end

      success(outcome)
    end
  end
end
