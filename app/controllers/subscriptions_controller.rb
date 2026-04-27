class SubscriptionsController < AuthenticatedController
  # Operator-facing dashboard for plan + billing. Phase 14 builds it
  # over multiple slices:
  #   • Slice 3 (this file): Stripe Checkout entry + bare show page
  #   • Slice 5: full dashboard, monthly↔yearly switch, cancel flow,
  #              "Borrar mi cuenta" Zona peligrosa
  #   • Slice 6: invoice list

  expose :subscription, -> { Current.account.subscription || Current.account.create_subscription! }

  def show
    @entitlements = Entitlements.for(Current.account)
    @highlight    = sanitize_highlight(params[:highlight])
  end

  # GET /subscription/new — soft alias to /pricing for now. Slice 5 may
  # replace this with an in-app upgrade modal that reuses the pricing
  # cards component.
  def new
    redirect_to pricing_path(highlight: params[:highlight])
  end

  # POST /subscription — open a Stripe Checkout session and redirect
  # the operator into Stripe-hosted Checkout. Hands back to /subscription
  # on success, /pricing on cancel.
  def create
    if Current.account.demo?
      redirect_to subscription_path,
                  alert: t(".demo_blocked")
      return
    end

    period = (params[:billing_period].presence || "monthly").to_s
    result = Subscriptions::CreateCheckoutSession.call(
      account:        Current.account,
      user:           Current.user,
      billing_period: period,
      success_url:    subscription_url(checkout: "complete"),
      # Stripe-cancel returns the operator to where she was — the
      # subscription dashboard, not /pricing — so she can pick a
      # different plan or just keep using Free without confusion.
      cancel_url:     subscription_url(checkout: "canceled")
    )

    if result.success?
      redirect_to result.object.url, allow_other_host: true, status: :see_other
    else
      redirect_to pricing_path,
                  alert: t(".checkout_failed", message: result.errors.to_a.first)
    end
  end

  # DELETE /subscription — placeholder until Slice 5 ships the real
  # cancel save-flow. Renders a stub for now so a stray DELETE
  # doesn't 500.
  def destroy
    render_stub(title: t("subscription.title"), meta: "subscription#destroy")
  end

  private

  # Highlights are passed via `?highlight=composable_recipes` so the
  # show page can flash the right card. Filter to known feature keys
  # so we never echo arbitrary user input back into the DOM.
  def sanitize_highlight(raw)
    return nil if raw.blank?
    key = raw.to_s.to_sym
    Entitlements::ALL_FEATURES.include?(key) ? key : nil
  end
end
