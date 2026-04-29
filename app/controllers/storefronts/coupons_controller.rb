module Storefronts
  class CouponsController < BaseController
    def validate
      result = Promotions::CouponValidator.call(
        account:        @storefront,
        code:           params[:code],
        subtotal_cents: params[:subtotal_cents].to_i
      )

      render json: {
        valid:          result.valid?,
        label:          result.label,
        discount_label: result.label,
        error:          result.error
      }
    end
  end
end
