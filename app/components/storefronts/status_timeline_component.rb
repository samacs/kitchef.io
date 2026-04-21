module Storefronts
  # Customer-facing progress timeline on the order confirmation page.
  # Wraps `Storefronts::StatusTimeline` output into rendered DOM; the page
  # subscribes to the per-order Turbo stream so the component rerenders
  # whenever the operator advances state.
  class StatusTimelineComponent < ApplicationComponent
    option :steps  # Array<Storefronts::StatusTimeline::Step>
  end
end
