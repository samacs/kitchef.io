module Promotions
  class Redeem < ApplicationCommand
    option :promotion
    option :order
    option :discount_cents
    option :discount_label
    option :kind

    def call
      return failure("no discount") unless discount_cents.positive?

      redemption = PromotionRedemption.create!(
        promotion:      promotion,
        order:          order,
        client:         order.client,
        discount_cents: discount_cents,
        discount_label: discount_label,
        kind:           kind
      )

      promotion.class.where(id: promotion.id)
                     .update_all("total_usage_count = total_usage_count + 1")

      success(redemption)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, object: e.record, errors: e.record.errors)
    rescue ActiveRecord::RecordNotUnique
      Result.new(success: false, object: nil, errors: [ "already redeemed" ])
    end
  end
end
