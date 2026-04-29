module Promotions
  class StorefrontBadges < ApplicationService
    option :account

    BadgeInfo = Data.define(:label, :discount_type, :discount_value,
                            :bogo_buy, :bogo_get)

    def call
      badges = {}

      account.promotions.active_now.automatic
             .includes(:promotion_recipes, :promotion_categories).find_each do |promo|
        badge = build_badge(promo)
        recipe_ids_for(promo).each { |rid| badges[rid] ||= badge }
      end

      badges
    end

    private

    def build_badge(promo)
      label = case promo.discount_type
      when "percentage"   then "#{promo.discount_value}% desc."
      when "fixed_amount" then "-#{Money.new(promo.discount_value, 'MXN').format}"
      when "bogo"         then "#{promo.bogo_buy_quantity}×#{promo.bogo_buy_quantity + promo.bogo_get_quantity}"
      end

      BadgeInfo.new(
        label:         label,
        discount_type: promo.discount_type,
        discount_value: promo.discount_value,
        bogo_buy:      promo.bogo_buy_quantity,
        bogo_get:      promo.bogo_get_quantity
      )
    end

    def recipe_ids_for(promo)
      case promo.scope_type
      when "order"
        account.recipes.kept.published.pluck(:id)
      when "recipe"
        promo.promotion_recipes.pluck(:recipe_id)
      when "category"
        cat_ids = promo.promotion_categories.pluck(:category_id)
        account.recipes.kept.published.where(category_id: cat_ids).pluck(:id)
      else
        []
      end
    end
  end
end
