class StorefrontsController < Storefronts::BaseController
  # Storefront root — hero + full menu grouped by category + about + info
  # strip + cart drawer. Everything the customer needs on a single page;
  # the old `/:slug/menu` route is now a legacy redirect (see
  # `Storefronts::MenusController`). Decision: customers should reach
  # "Agregar" on first paint, not after a second click.
  def show
    @ordering_hours = Storefronts::OrderingHours.for(@storefront)
    @recipes_by_category = @storefront
      .recipes.kept.published
      .order(category: :asc, position: :asc)
      .group_by(&:category)
  end
end
