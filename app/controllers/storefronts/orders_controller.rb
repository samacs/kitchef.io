module Storefronts
  class OrdersController < BaseController
    def new
      @order = @storefront.orders.new(
        delivery_type: default_delivery_type,
        delivery_date: Date.current + 1
      )
      @order.items.build
    end

    def create
      payload = order_params.to_h.merge(items_attributes: items_from_cart_payload)

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
    end

    # Customer self-confirmation from the email CTA. GET + auto-confirm
    # is deliberate: email clients may pre-fetch links, but the
    # prefixed_id is already the URL secret and replays (confirming an
    # already-confirmed order) are idempotent — AASM's guard returns
    # false without mutating state.
    #
    # The operator-app confirm action lives at `/orders/:id/confirm`
    # (authenticated); this public mirror accepts GET so one tap from
    # the inbox moves the order forward.
    def confirm
      @order = Order.find_by_prefix_id(params[:id])
      return render "storefronts/not_found", status: :not_found if @order.nil?
      return render "storefronts/not_found", status: :not_found if @order.account_id != @storefront.id

      if @order.aasm.may_fire_event?(:confirm)
        Orders::Transition.call(order: @order, event: :confirm)
        sweep_operator_notifications(@order)
        flash[:notice] = t("storefronts.orders.self_confirmed")
      end

      redirect_to storefront_order_path(slug: @storefront.slug, id: @order.prefix_id)
    end

    private

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
        [
          idx.to_s,
          {
            recipe_id: item["recipe_id"].to_s,
            quantity:  (item["quantity"].presence || 1),
            notes:     item["notes"].to_s
          }
        ]
      end.to_h
    rescue JSON::ParserError
      []
    end

    def order_params
      params.require(:order).permit(
        :delivery_type,
        :delivery_date,
        :delivery_start_time_hhmm,
        :delivery_end_time_hhmm,
        :delivery_address,
        :colonia,
        :city,
        :delivery_notes,
        :notes,
        items_attributes: [ :recipe_id, :quantity, :notes ]
      )
    end
  end
end
