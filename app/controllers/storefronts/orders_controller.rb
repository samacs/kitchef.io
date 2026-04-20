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
      result = Storefronts::PlaceOrder.call(
        storefront:      @storefront,
        customer_params: customer_params.to_h,
        order_params:    order_params.to_h
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

    private

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
