module Subscriptions
  # Drop-in controller concern that gates whole pages behind a Pro
  # feature. When the current account lacks the entitlement, renders
  # the locked landing page (with copy specific to the feature) and
  # halts the controller chain so the underlying action never runs.
  #
  # Usage:
  #   class Reports::FinanceController < AuthenticatedController
  #     include Subscriptions::FeatureGated
  #     gate_feature :finance_reports
  #   end
  #
  # The locked view at `app/views/subscriptions/locked/show.html.erb`
  # is the single fallback template — it renders
  # `Subscriptions::LockedComponent` with locale-driven copy keyed by
  # the feature symbol, so adding a new gated controller is one line.
  module FeatureGated
    extend ActiveSupport::Concern

    class_methods do
      def gate_feature(key, only: nil, except: nil)
        opts = { only: only, except: except }.compact
        before_action -> { enforce_feature_gate!(key) }, **opts
      end
    end

    private

    def enforce_feature_gate!(key)
      return if Entitlements.for(Current.account).allows?(key)

      @gated_feature = key
      render template: "subscriptions/locked/show",
             status:   :payment_required
    end
  end
end
