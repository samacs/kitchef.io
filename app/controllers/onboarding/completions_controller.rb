module Onboarding
  # Final onboarding step: a kitchen-summary review + Free/Pro plan
  # picker. Submitting the form completes onboarding (flips the flag)
  # and either lands the operator on her dashboard (Free) or hands
  # her off to Stripe Checkout (Pro).
  #
  # Why one combined step instead of two: 5 onboarding steps already
  # ask a lot. Tucking the plan picker onto the same card as the
  # summary keeps the wizard feel tight and lets the operator see
  # both at once — "here's what you built; here's how you continue".
  class CompletionsController < BaseController
    before_action :require_account_step

    def show
    end

    def create
      Complete.call(account: current_onboarding_account)

      case plan_choice
      when "pro"
        start_pro_checkout
      else
        redirect_to authenticated_root_path,
                    notice: t(".free_chosen")
      end
    end

    private

    def plan_choice
      raw = params[:plan_choice].to_s.strip
      %w[free pro].include?(raw) ? raw : "free"
    end

    def billing_period
      raw = params[:billing_period].to_s.strip
      %w[monthly yearly].include?(raw) ? raw : "yearly"
    end

    # Pro path: open a Stripe Checkout Session and redirect into it.
    # `Subscriptions::CreateCheckoutSession` enforces the demo guard +
    # one-trial-per-account; we mirror its failure modes back into a
    # gentle redirect to /pricing rather than blowing up the
    # onboarding flow.
    def start_pro_checkout
      result = Subscriptions::CreateCheckoutSession.call(
        account:        current_onboarding_account,
        user:           Current.user,
        billing_period: billing_period,
        success_url:    subscription_url(checkout: "complete"),
        # Cancel-from-Checkout lands on /subscription (not the
        # dashboard or /pricing) — she's already onboarded by the
        # time she reaches Stripe, so the dashboard is the right
        # place to re-pick or stay on Free.
        cancel_url:     subscription_url(checkout: "canceled")
      )

      if result.success?
        redirect_to result.object.url, allow_other_host: true, status: :see_other
      else
        redirect_to authenticated_root_path,
                    alert: t(".checkout_failed", message: result.errors.to_a.first)
      end
    end
  end
end
