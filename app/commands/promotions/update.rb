module Promotions
  class Update < ApplicationCommand
    option :promotion
    option :params

    def call
      attrs = params.to_h.deep_symbolize_keys
      recipe_ids   = Array(attrs.delete(:recipe_ids)).compact_blank
      category_ids = Array(attrs.delete(:category_ids)).compact_blank

      promotion.assign_attributes(attrs)
      promotion.code = nil if promotion.kind_automatic?

      sync_scope_records(promotion, :promotion_recipes, :recipe_id, recipe_ids)
      sync_scope_records(promotion, :promotion_categories, :category_id, category_ids)

      if promotion.save
        success(promotion)
      else
        Result.new(success: false, object: promotion, errors: promotion.errors)
      end
    end

    private

    def sync_scope_records(promotion, association, foreign_key, new_ids)
      existing = promotion.public_send(association)
      existing_ids = existing.map(&foreign_key)

      (existing_ids - new_ids).each do |id|
        existing.find { |r| r.public_send(foreign_key) == id }&.mark_for_destruction
      end

      (new_ids - existing_ids).each do |id|
        promotion.public_send(association).build(foreign_key => id)
      end
    end
  end
end
