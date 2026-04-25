class StorefrontsController < Storefronts::BaseController
  # Storefront root — hero + full menu grouped by category + about + info
  # strip + cart drawer. Everything the customer needs on a single page.
  #
  # When the operator is signed-in AND visiting her own storefront, the
  # empty-state card turns into a gentle nudge toward `/recipes` with the
  # count of draft recipes waiting to be published — so the first-time
  # "¿por qué mi menú está vacío?" question has an answer in-page.
  def show
    @ordering_hours = Storefronts::OrderingHours.for(@storefront)
    @recipes_by_category = @storefront
      .recipes.kept.published
      .includes(:category, :option_groups, components: :componentable)
      .order(category_id: :asc, position: :asc)
      .group_by(&:category)
    @viewing_own_storefront = Current.user.present? && Current.user.owned_account&.id == @storefront.id
    @draft_count = @viewing_own_storefront ? @storefront.recipes.kept.saleable.where(is_published: false).count : 0
  end
end
