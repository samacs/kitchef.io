module Storefronts
  # Customer-facing progress timeline. The operator kanban has seven
  # states (placed → confirmed → in_production → ready → en_route →
  # delivered → paid) but the customer only needs to see five meaningful
  # milestones, and `en_route` collapses into "En camino" so pickup
  # pedidos don't show an empty step they never pass through.
  #
  # Returns an array of Step structs in display order, each with:
  #   - key:        stable identifier for view rendering
  #   - label:      Spanish label (via I18n)
  #   - status:     :done | :current | :pending
  #   - timestamp:  the lifecycle stamp for done steps (nil otherwise)
  class StatusTimeline
    Step = Struct.new(:key, :label, :status, :timestamp, keyword_init: true)

    # Steps shown on the customer confirmation page, in order. Each entry
    # maps a display key to the AASM states it covers and the lifecycle
    # column that determines the "done" timestamp.
    STEPS = [
      { key: "placed",        covers: %w[placed],                          stamp: :created_at },
      { key: "confirmed",     covers: %w[confirmed],                        stamp: :confirmed_at },
      { key: "in_production", covers: %w[in_production],                    stamp: :production_started_at },
      { key: "ready",         covers: %w[ready],                            stamp: :ready_at },
      { key: "en_route",      covers: %w[en_route],                         stamp: :en_route_started_at },
      { key: "delivered",     covers: %w[delivered paid],                   stamp: :delivered_at }
    ].freeze

    def self.for(order)
      new(order).call
    end

    def initialize(order)
      @order = order
    end

    def call
      current_index = current_step_index
      STEPS.filter_map.with_index do |step, idx|
        next if skip_step?(step[:key])

        Step.new(
          key:       step[:key],
          label:     I18n.t("storefronts.status_timeline.steps.#{step[:key]}"),
          status:    status_for(idx, current_index),
          timestamp: @order.public_send(step[:stamp])
        )
      end
    end

    private

    def skip_step?(key)
      # Pickup + shipping pedidos skip the operator-internal `en_route`
      # step entirely. For pickup, there's no runner leg; for shipping,
      # the courier owns the transit and we only track handoff + delivery.
      key == "en_route" && !@order.delivery?
    end

    def current_step_index
      state = @order.state
      STEPS.index { |s| s[:covers].include?(state) } || (STEPS.length - 1)
    end

    def status_for(idx, current_idx)
      return :done    if idx < current_idx
      return :current if idx == current_idx
      :pending
    end
  end
end
