module Recipes
  # Phase-2B recipe card for the recipes index and dashboard grid. Links to
  # the edit page (simple mode has no dedicated show surface yet).
  class CardComponent < ApplicationComponent
    option :recipe

    def category_label
      I18n.t("recipe.categories.#{recipe.category}")
    end

    def price_label
      helpers.humanized_money_with_symbol(recipe.sale_price)
    end

    def photo_url
      return nil unless recipe.photos.attached?

      helpers.url_for(recipe.photos.first.variant(:card))
    end
  end
end
