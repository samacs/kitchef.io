module Subscriptions
  # 4-step cancel save-flow.
  #
  #   GET  /subscription/cancel        → exit survey (5 reasons)
  #   POST /subscription/cancel        → render save-offer matched to reason
  #   POST /subscription/cancel/save   → accept the save offer
  #   POST /subscription/cancel/confirm → hard cancel (sets cancel_at_period_end)
  #
  # The single-question exit survey is intentional — Churnkey 2025
  # data: every additional question after the first drops save rate
  # by ~7%.
  class CancellationsController < AuthenticatedController
    REASONS = %w[too_expensive not_using missing_feature closing_kitchen other].freeze

    before_action :require_pro_subscription, only: %i[new create save confirm]

    def new
      @subscription = Current.account.subscription
    end

    def create
      @subscription = Current.account.subscription
      @reason = sanitized_reason
      render :show
    end

    # Accept the matched save offer.
    def save
      @reason = sanitized_reason

      result = case @reason
      when "too_expensive"   then Subscriptions::ApplySaveCoupon.call(subscription: subscription)
      when "closing_kitchen" then nil # Slice 8 vacation pause; for v1, redirect to /schedule.
      end

      if @reason == "closing_kitchen"
        redirect_to schedule_path,
                    notice: t(".pause_redirect")
        return
      end

      if result&.success?
        redirect_to subscription_path(saved: 1),
                    notice: t(".success_too_expensive")
      else
        redirect_to cancel_subscription_path(reason: @reason),
                    alert:  t(".failure", message: result&.errors&.to_a&.first)
      end
    end

    # Hard cancel — Stripe `cancel_at_period_end = true`. Operator
    # keeps full Pro access through period end; webhook handles the
    # eventual flip to free when Stripe deletes the subscription.
    def confirm
      result = Subscriptions::Cancel.call(
        subscription: subscription,
        reason:       sanitized_reason
      )

      if result.success?
        redirect_to subscription_path(canceled: 1),
                    notice: t(".success_html", date: l(subscription.reload.current_period_end&.to_date || Date.current, format: :long)).html_safe
      else
        redirect_to cancel_subscription_path,
                    alert:  t(".failure", message: result.errors.to_a.first)
      end
    end

    private

    def subscription
      @subscription ||= Current.account.subscription
    end

    def require_pro_subscription
      return if subscription&.pro?

      redirect_to subscription_path,
                  alert: t(".not_pro")
    end

    def sanitized_reason
      raw = params[:reason].to_s.strip
      REASONS.include?(raw) ? raw : "other"
    end
  end
end
