module Subscriptions
  # GET /subscription/invoices — the operator's billing history.
  # Reads live from Stripe (`Subscriptions::FetchInvoices`); never
  # caches locally so cancellations / refunds / reissues that happen
  # on the Stripe side surface immediately on her next page load.
  class InvoicesController < AuthenticatedController
    def index
      @invoices = Subscriptions::FetchInvoices.call(account: Current.account)
    end
  end
end
