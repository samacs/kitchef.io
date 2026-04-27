module Subscriptions
  # POST /subscription/portal — creates a Stripe Billing Portal
  # session and redirects the operator into Stripe's hosted card-
  # management UI. Used exclusively for "Administrar método de
  # pago"; everything else (plan switch, cancel, invoice list) stays
  # in-app on Kitchef.
  class PortalSessionsController < AuthenticatedController
    def create
      result = Subscriptions::CreatePortalSession.call(
        account:    Current.account,
        return_url: subscription_url(portal: "returned")
      )

      if result.success?
        redirect_to result.object.url, allow_other_host: true, status: :see_other
      else
        redirect_to subscription_path,
                    alert: t(".failure", message: result.errors.to_a.first)
      end
    end
  end
end
