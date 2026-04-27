module Subscriptions
  # POST /subscription/downgrade — drop the operator immediately
  # back to Free. Used both as the alternative to hard cancel in the
  # save flow AND as a standalone "I just want Free" action from
  # the dashboard.
  class DowngradesController < AuthenticatedController
    def create
      result = Subscriptions::DowngradeToFree.call(
        subscription: Current.account.subscription,
        reason:       params[:reason]
      )

      if result.success?
        redirect_to subscription_path(downgraded: 1),
                    notice: t(".success")
      else
        redirect_to subscription_path,
                    alert:  t(".failure", message: result.errors.to_a.first)
      end
    end
  end
end
