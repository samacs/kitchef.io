module Orders
  # Wraps a single AASM event call. Returns failure when the event isn't
  # permitted from the current state (e.g. confirming a canceled order),
  # so the controller can flash an alert instead of redirecting silently.
  class Transition < ApplicationCommand
    # Cancel is NOT listed here — it requires a reason and flows through
    # Orders::Cancel via /orders/:id/cancellation. These events are
    # one-click forward transitions only.
    # Forward-flow fulfillment events. `mark_paid` is NOT here — it's
    # a property update (see Order#mark_paid!), not a state transition.
    EVENTS = %i[confirm start_production mark_ready ship deliver].freeze

    option :order
    option :event

    def call
      sym = event.to_sym
      return failure([ "unsupported_event" ]) unless EVENTS.include?(sym)
      return failure([ "transition_not_allowed" ]) unless order.aasm.may_fire_event?(sym)

      if order.public_send("#{sym}!")
        success(order)
      else
        Result.new(success: false, object: order, errors: order.errors)
      end
    end
  end
end
