class DashboardsController < AuthenticatedController
  expose :recipes,     -> { Current.account.recipes.kept.saleable.order(:position).limit(6) }
  expose :total_count, -> { Current.account.recipes.kept.saleable.count }

  def show; end
end
