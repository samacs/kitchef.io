module Storefronts
  class OrdersController < BaseController
    def new
      @order = @storefront.orders.new(
        delivery_type: default_delivery_type,
        delivery_date: Date.current + 1
      )
      @order.items.build
      @available_days = Schedules::AvailableWindows.for(account: @storefront)
      @schedule_open  = @available_days.any? { |day| day.windows.any? }
    end

    def create
      unless @storefront.public_profile.any_fulfillment?
        redirect_to new_storefront_order_path(slug: @storefront.slug),
          alert: t("storefronts.checkout.no_fulfillment.blocked")
        return
      end

      payload = order_params.to_h.merge(items_attributes: items_from_cart_payload)
      payload = apply_delivery_window(payload)
      payload = normalize_cash_amount(payload)

      result = Storefronts::PlaceOrder.call(
        storefront:      @storefront,
        customer_params: customer_params.to_h,
        order_params:    payload
      )

      if result.success?
        redirect_to storefront_order_path(slug: @storefront.slug, id: result.object.prefix_id),
          notice: t("storefronts.orders.created_flash")
      else
        @order = result.object || @storefront.orders.new(order_params)
        @order.delivery_window_id = params.dig(:order, :delivery_window_id)
        @available_days = Schedules::AvailableWindows.for(account: @storefront)
        @schedule_open  = @available_days.any? { |day| day.windows.any? }
        flash.now[:alert] = t("storefronts.orders.create_error")
        render :new, status: :unprocessable_content
      end
    end

    def show
      # `/:slug/orders/:id` is the customer-shareable URL. The prefixed_id
      # form (`ord_xyz`) is the only accepted id — a raw integer would let
      # a customer enumerate /1, /2, /3, which defeats the "URL is the
      # secret" model. rack-attack + a 404 on miss handle guessing pressure.
      @order = Order.find_by_prefix_id(params[:id])
      return render "storefronts/not_found", status: :not_found if @order.nil?
      return render "storefronts/not_found", status: :not_found if @order.account_id != @storefront.id

      @status_timeline = Storefronts::StatusTimeline.for(@order)
      # Review/confirm block is gated on the signed email token. The email
      # CTA URL includes `?t=…`; the direct post-submit redirect does not.
      # That asymmetry is the identity gate — the block is only exposed to
      # someone who received (and opened) the confirmation email.
      @email_verified = @order.state == "placed" &&
                        params[:t].present? &&
                        Order.decode_review_token(params[:t])&.id == @order.id
    end

    # Customer self-confirmation — the review page's "Confirmar mi pedido"
    # button posts here. Before the AASM transition fires, we persist any
    # last-minute tweaks the customer made to the delivery address and
    # notes — that's the "last chance to review" the plan calls for.
    #
    # Idempotent: a replay on an already-confirmed order skips the address
    # update (the order is immutable() once out of `placed`) and silently
    # redirects back. Email clients can safely prefetch the page GET; only
    # the explicit POST mutates anything.
    def confirm
      @order = Order.find_by_prefix_id(params[:id])
      return render "storefronts/not_found", status: :not_found if @order.nil?
      return render "storefronts/not_found", status: :not_found if @order.account_id != @storefront.id

      # The email link posts with `?t=…`; the review form re-submits the
      # token as a hidden field. Without a valid token we refuse — the
      # page never should have rendered the confirm button in that case,
      # but we belt-and-suspenders it here against direct POSTs.
      token_order = Order.decode_review_token(params[:t])
      unless token_order && token_order.id == @order.id
        return redirect_to storefront_order_path(slug: @storefront.slug, id: @order.prefix_id),
          alert: t("storefronts.orders.review_gate_required")
      end

      if @order.aasm.may_fire_event?(:confirm)
        update_review_fields(@order)
        Orders::Transition.call(order: @order, event: :confirm)
        sweep_operator_notifications(@order)
        flash[:notice] = t("storefronts.orders.self_confirmed")
      end

      redirect_to storefront_order_path(slug: @storefront.slug, id: @order.prefix_id)
    end

    private

    # The review page lets the customer edit her delivery_address,
    # colonia, city and delivery_notes before confirming. Strong-params
    # whitelist is scoped to `review` so a tampered POST can't reach
    # anything stateful (price, items, state, etc.).
    def update_review_fields(order)
      review = params[:review]
      return if review.blank?

      attrs = review.permit(:delivery_address, :colonia, :city, :delivery_notes).to_h

      # Pickup orders don't have an address to edit; don't force-write blank
      # strings onto them. Delivery orders use `delivery_address: required`
      # so Order's own validations surface a missing value on failed save.
      attrs.delete("delivery_address") if order.delivery_type_pickup?
      order.update(attrs) if attrs.any?
    end

    # Mirror the operator-side sweep from OrdersController#mark_related_notifications_read
    # — when the customer self-confirms, drop the unread bell badge
    # for the kitchen owner so she doesn't see a stale "nuevo pedido"
    # alert for an order she now knows is confirmed.
    def sweep_operator_notifications(order)
      owner = order.account&.owner
      return unless owner

      owner.notifications
           .joins(:event)
           .where("noticed_events.params @> ?", { order_id: order.id }.to_json)
           .where(read_at: nil)
           .find_each(&:mark_as_read!)
    rescue StandardError => e
      Rails.logger.warn "[storefronts/orders#confirm] notification sweep failed: #{e.message}"
    end

    def default_delivery_type
      profile = @storefront.public_profile
      return "delivery" if profile.offers_delivery?
      return "pickup"   if profile.offers_pickup?

      "delivery"
    end

    def customer_params
      params.require(:customer).permit(:first_name, :last_name, :phone, :email)
    rescue ActionController::ParameterMissing
      ActionController::Parameters.new
    end

    # The storefront cart lives entirely in sessionStorage; the checkout
    # form posts a single `cart_payload` hidden field with a JSON blob
    # (see storefront_cart_controller.js#updatePayload). Parse it into
    # the `items_attributes` shape Orders::Place already expects. Any
    # parse error or malformed row just drops out — Orders::Place will
    # reject an empty-items order with a clear error.
    def items_from_cart_payload
      raw = params[:cart_payload].presence
      return [] if raw.blank?

      decoded = JSON.parse(raw)
      Array(decoded["items"]).each_with_index.map do |item, idx|
        attrs = {
          recipe_id: item["recipe_id"].to_s,
          quantity:  (item["quantity"].presence || 1),
          notes:     item["notes"].to_s
        }
        attrs[:selected_options]    = item["selected_options"]    if item["selected_options"].present?
        attrs[:removed_components]  = item["removed_components"]  if item["removed_components"].present?
        [ idx.to_s, attrs ]
      end.to_h
    rescue JSON::ParserError
      []
    end

    def order_params
      params.require(:order).permit(
        :delivery_type,
        :delivery_window_id,
        :delivery_address,
        :colonia,
        :city,
        :delivery_notes,
        :notes,
        :payment_method,
        :tip_cents,
        :cash_payment_amount_cents,
        :coupon_code,
        items_attributes: [ :recipe_id, :quantity, :notes ]
      )
    end

    # The form's `$` input collects pesos ("500", "500.50") regardless
    # of whether the value contains a decimal, so always convert to
    # cents on the way in. Mirrors the operator-side `normalize_packaging`.
    def normalize_cash_amount(attrs)
      raw = attrs[:cash_payment_amount_cents]
      return attrs if raw.blank?
      attrs[:cash_payment_amount_cents] = (raw.to_s.gsub(",", ".").to_d * 100).to_i
      attrs
    end

    # Decode the picker's window id into the canonical attributes Order
    # actually stores. ASAP → dispatch_asap + delivery_date = today, times
    # blank. Scheduled → dispatch_scheduled + the matching time range.
    # Invalid/stale ids (operator deleted the window between render and
    # submit) fall through as nil and Order validations surface the error.
    def apply_delivery_window(attrs)
      window_id = attrs.delete(:delivery_window_id)
      return attrs if window_id.blank?

      window = Schedules::AvailableWindows.decode(account: @storefront, id: window_id)
      return attrs if window.nil?

      if window.kind == :asap
        attrs.merge(
          delivery_mode:       :asap,
          delivery_date:       window.date,
          delivery_start_time: nil,
          delivery_end_time:   nil
        )
      else
        attrs.merge(
          delivery_mode:       :scheduled,
          delivery_date:       window.date,
          delivery_start_time: window.from_time,
          delivery_end_time:   window.to_time
        )
      end
    end
  end
end
