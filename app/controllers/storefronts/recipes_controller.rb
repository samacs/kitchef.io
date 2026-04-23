module Storefronts
  # Public dish detail page. Reads a single saleable recipe by its
  # account-scoped FriendlyId slug. Renders:
  #   - hero (photo + name + description + price)
  #   - add-to-cart (reuses `storefront_cart_controller` payload)
  #   - WhatsApp deep-link
  #   - related strip of other published recipes (deliberately excluding
  #     the current recipe's category, so the customer discovers something
  #     outside the bucket she was already browsing)
  class RecipesController < BaseController
    def show
      @recipe = @storefront.recipes.kept.published.friendly.find(params[:recipe_slug])
      @related = related_recipes(@recipe)
    rescue ActiveRecord::RecordNotFound
      render "storefronts/not_found", status: :not_found
    end

    private

    # Up to 6 other published recipes, prioritizing OTHER categories so
    # the strip reads as "more from this kitchen, different style" rather
    # than "more of the same." Falls back to any category when there
    # aren't enough candidates in the other-category pool.
    def related_recipes(recipe)
      published = @storefront.recipes.kept.published
      other_cats = published.where.not(category: recipe.category).where.not(id: recipe.id)
      same_cat   = published.where(category: recipe.category).where.not(id: recipe.id)

      (other_cats.order(position: :asc).limit(6).to_a +
       same_cat.order(position: :asc).limit(6).to_a).uniq.first(6)
    end
  end
end
