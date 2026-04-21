module Recipes
  # Phase-2B recipe card for the recipes index and dashboard grid. Links to
  # the edit page (simple mode has no dedicated show surface yet), shows a
  # publish-state badge ("Publicada" / "Borrador"), and carries a quick-
  # toggle button the operator can use to flip publication without
  # opening the form.
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

    def publishable?
      recipe.photos.attached?
    end

    def published?
      recipe.is_published?
    end
  end
end
