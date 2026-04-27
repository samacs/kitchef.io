module Subscriptions
  # POST /subscription/plan-switch — flips a paying operator between
  # Pro Mensual and Pro Anual via Stripe with proration. Stripe
  # webhook handles the local Subscription update; we re-sync here
  # too so the immediate redirect lands on a fresh dashboard.
  class PlanSwitchesController < AuthenticatedController
    def create
      result = Subscriptions::ChangeBillingPeriod.call(
        subscription:   Current.account.subscription,
        billing_period: params[:billing_period]
      )

      if result.success?
        redirect_to subscription_path(switched: params[:billing_period]),
                    notice: t(".success", period: t("subscription.plans.pro_#{params[:billing_period]}"))
      else
        redirect_to subscription_path,
                    alert:  t(".failure", message: result.errors.to_a.first)
      end
    end
  end
end
