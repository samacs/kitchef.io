module Promotions
  class Create < ApplicationCommand
    option :account
    option :params

    def call
      attrs = params.to_h.deep_symbolize_keys
      recipe_ids   = Array(attrs.delete(:recipe_ids)).compact_blank
      category_ids = Array(attrs.delete(:category_ids)).compact_blank

      promotion = account.promotions.new(attrs)
      promotion.code = nil if promotion.kind_automatic?

      recipe_ids.each { |id| promotion.promotion_recipes.build(recipe_id: id) }
      category_ids.each { |id| promotion.promotion_categories.build(category_id: id) }

      if promotion.save
        success(promotion)
      else
        Result.new(success: false, object: promotion, errors: promotion.errors)
      end
    end
  end
end
