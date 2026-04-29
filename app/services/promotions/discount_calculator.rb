module Promotions
  class DiscountCalculator < ApplicationService
    option :promotion
    option :items

    def call
      return 0 if items.empty?

      raw = case promotion.discount_type
      when "percentage"  then calculate_percentage
      when "fixed_amount" then calculate_fixed_amount
      when "bogo"         then calculate_bogo
      else 0
      end

      raw = [ raw, promotion.max_discount_cents ].min if promotion.max_discount_cents.present?
      [ raw, subtotal_cents ].min
    end

    private

    def calculate_percentage
      base = qualifying_line_total_cents
      (base * promotion.discount_value / 100.0).floor
    end

    def calculate_fixed_amount
      if promotion.scope_type_order?
        promotion.discount_value
      else
        qualifying_items.any? ? promotion.discount_value : 0
      end
    end

    def calculate_bogo
      buy = promotion.bogo_buy_quantity
      get = promotion.bogo_get_quantity
      cycle = buy + get

      qualifying_items.sum do |item|
        qty = item.quantity.to_i
        next 0 if qty < cycle

        free_units = (qty / cycle) * get
        free_units * item.unit_price_cents.to_i
      end
    end

    def qualifying_items
      @qualifying_items ||= case promotion.scope_type
      when "order"    then items
      when "recipe"   then items_matching_recipes
      when "category" then items_matching_categories
      else []
      end
    end

    def qualifying_line_total_cents
      qualifying_items.sum { |i| (i.unit_price_cents.to_i * i.quantity.to_d).to_i }
    end

    def subtotal_cents
      items.sum { |i| (i.unit_price_cents.to_i * i.quantity.to_d).to_i }
    end

    def items_matching_recipes
      promo_recipe_ids = promotion.promotion_recipes.pluck(:recipe_id).to_set
      items.select { |i| promo_recipe_ids.include?(i.recipe_id) }
    end

    def items_matching_categories
      promo_category_ids = promotion.promotion_categories.pluck(:category_id).to_set
      items.select { |i| promo_category_ids.include?(i.recipe&.category_id) }
    end
  end
end
