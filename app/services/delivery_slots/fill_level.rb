module DeliverySlots
  # Counts live orders that would belong to a given (account, day_of_week,
  # window) tuple for a specific week. Used by the slot editor to render
  # `"Sáb 11:00–13:00 · 4 de 8 pedidos"` fill indicators.
  #
  # Live = non-canceled, non-discarded. We include `placed` on purpose:
  # the operator wants to know what's committed to a window even before
  # confirming, because capacity is a demand signal, not a fulfillment
  # gate (v1 is display-only).
  class FillLevel < ApplicationService
    LIVE_STATES = %w[placed confirmed in_production ready en_route delivered].freeze

    option :account
    option :slot
    option :week_starting, default: -> { Date.current.beginning_of_week(:monday).to_date }

    def self.for(account:, slot:, week_starting: Date.current.beginning_of_week(:monday).to_date)
      call(account: account, slot: slot, week_starting: week_starting)
    end

    def call
      date = date_for_slot_this_week
      return 0 if date.nil?

      account.orders.kept
        .where(delivery_date: date)
        .where(state: LIVE_STATES)
        .where(delivery_start_time: slot.start_time, delivery_end_time: slot.end_time)
        .count
    end

    private

    # Ruby's `wday` is Sunday=0..Saturday=6, same as the enum stored on
    # DeliverySlot.day_of_week. Walk forward from the week's Monday until
    # we land on that wday.
    def date_for_slot_this_week
      base = week_starting
      (0..6).each do |offset|
        date = base + offset.days
        return date if date.wday == slot.day_of_week
      end
      nil
    end
  end
end
