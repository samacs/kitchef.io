module Promotions
  class CouponValidator < ApplicationService
    CouponResult = Data.define(:valid, :promotion, :label, :error) do
      def valid? = valid
    end

    option :account
    option :code
    option :subtotal_cents, default: -> { 0 }
    option :client, default: -> { nil }

    def call
      return error_result(:blank) if code.blank?

      promo = account.promotions.coupons.active_now
                     .find_by("UPPER(code) = ?", code.strip.upcase)

      return error_result(:not_found) if promo.nil?
      return error_result(:expired) if promo.expired?
      return error_result(:usage_limit) if promo.usage_limit_reached?
      return error_result(:client_limit) if promo.client_limit_reached?(client)
      return error_result(:min_order) if subtotal_cents < promo.min_order_cents

      label = discount_label(promo)
      CouponResult.new(valid: true, promotion: promo, label: label, error: nil)
    end

    private

    def error_result(key)
      CouponResult.new(
        valid: false, promotion: nil, label: nil,
        error: I18n.t("storefronts.checkout.coupon.errors.#{key}")
      )
    end

    def discount_label(promo)
      case promo.discount_type
      when "percentage"   then "#{promo.discount_value}% desc."
      when "fixed_amount" then "-#{Money.new(promo.discount_value, 'MXN').format}"
      when "bogo"         then "#{promo.bogo_buy_quantity}×#{promo.bogo_buy_quantity + promo.bogo_get_quantity}"
      end
    end
  end
end
