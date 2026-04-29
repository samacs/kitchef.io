module Promotions
  class StackingResolver < ApplicationService
    StackingResult = Data.define(
      :auto_promotion, :auto_discount_cents, :auto_label,
      :coupon_promotion, :coupon_discount_cents, :coupon_label,
      :total_discount_cents, :combined_label
    ) do
      def any_discount? = total_discount_cents.positive?
    end

    EMPTY = StackingResult.new(
      auto_promotion: nil, auto_discount_cents: 0, auto_label: nil,
      coupon_promotion: nil, coupon_discount_cents: 0, coupon_label: nil,
      total_discount_cents: 0, combined_label: nil
    ).freeze

    option :account
    option :items
    option :subtotal_cents
    option :client, default: -> { nil }
    option :coupon_code, default: -> { nil }

    def call
      return EMPTY if items.empty? || subtotal_cents <= 0

      auto   = resolve_auto
      coupon = resolve_coupon

      total = [ auto[:cents] + coupon[:cents], subtotal_cents ].min
      label = [ auto[:label], coupon[:label] ].compact.join(" · ").presence

      StackingResult.new(
        auto_promotion:       auto[:promotion],
        auto_discount_cents:  auto[:cents],
        auto_label:           auto[:label],
        coupon_promotion:     coupon[:promotion],
        coupon_discount_cents: coupon[:cents],
        coupon_label:         coupon[:label],
        total_discount_cents: total,
        combined_label:       label
      )
    end

    private

    def resolve_auto
      eligible = EligibilityChecker.call(
        account: account,
        subtotal_cents: subtotal_cents,
        client: client,
        kind: :automatic
      )

      best = nil
      best_cents = 0

      eligible.each do |promo|
        cents = DiscountCalculator.call(promotion: promo, items: items)
        if cents > best_cents
          best = promo
          best_cents = cents
        end
      end

      if best
        { promotion: best, cents: best_cents, label: discount_label(best, best_cents) }
      else
        { promotion: nil, cents: 0, label: nil }
      end
    end

    def resolve_coupon
      return { promotion: nil, cents: 0, label: nil } if coupon_code.blank?

      promo = account.promotions.coupons.active_now
                     .find_by("UPPER(code) = ?", coupon_code.strip.upcase)

      return { promotion: nil, cents: 0, label: nil } if promo.nil?
      return { promotion: nil, cents: 0, label: nil } unless promo.eligible?(subtotal_cents: subtotal_cents, client: client)

      cents = DiscountCalculator.call(promotion: promo, items: items)
      if cents.positive?
        { promotion: promo, cents: cents, label: discount_label(promo, cents) }
      else
        { promotion: nil, cents: 0, label: nil }
      end
    end

    def discount_label(promo, _cents)
      type_part = case promo.discount_type
      when "percentage"   then "#{promo.discount_value}% desc."
      when "fixed_amount" then promo.name
      when "bogo"         then "#{promo.bogo_buy_quantity}×#{promo.bogo_buy_quantity + promo.bogo_get_quantity}"
      end

      if promo.kind_coupon? && promo.code.present?
        "#{promo.code} · #{type_part}"
      else
        type_part
      end
    end
  end
end
