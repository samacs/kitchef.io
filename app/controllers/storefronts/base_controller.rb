module Storefronts
  # Public-facing, unauthenticated storefront surface. The slug comes from
  # the root-level path constraint in config/routes.rb, which already
  # rejects Account::RESERVED_SLUGS — by the time we resolve here the slug
  # is guaranteed not to collide with an app route.
  class BaseController < ApplicationController
    allow_unauthenticated_access

    layout "storefront"

    before_action :set_storefront
    rescue_from ActiveRecord::RecordNotFound, with: :storefront_not_found

    private

    def set_storefront
      @storefront = Account.friendly.kept.find(params[:slug])
      @promo_badges = Promotions::StorefrontBadges.call(account: @storefront)
      @auto_promotions_json = build_auto_promotions_json
    end

    def build_auto_promotions_json
      promos = @storefront.promotions.active_now.automatic
                          .includes(:promotion_recipes, :promotion_categories)
      promos.map do |p|
        {
          id:             p.id,
          discount_type:  p.discount_type,
          discount_value: p.discount_value,
          scope_type:     p.scope_type,
          label:          promotion_badge_label(p),
          recipe_ids:     p.scope_type_recipe? ? p.promotion_recipes.pluck(:recipe_id) : [],
          category_ids:   p.scope_type_category? ? p.promotion_categories.pluck(:category_id) : [],
          bogo_buy:       p.bogo_buy_quantity,
          bogo_get:       p.bogo_get_quantity,
          max_discount_cents: p.max_discount_cents
        }
      end.to_json
    end

    def promotion_badge_label(promo)
      case promo.discount_type
      when "percentage"   then "#{promo.discount_value}% desc."
      when "fixed_amount" then "-#{Money.new(promo.discount_value, 'MXN').format}"
      when "bogo"         then "#{promo.bogo_buy_quantity}×#{promo.bogo_buy_quantity + promo.bogo_get_quantity}"
      end
    end

    def storefront_not_found
      render "storefronts/not_found", status: :not_found
    end
  end
end
