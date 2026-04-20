class DashboardsController < AuthenticatedController
  expose :recipes,       -> { Current.account.recipes.kept.saleable.order(:position).limit(6) }
  expose :total_count,   -> { Current.account.recipes.kept.saleable.count }
  expose :today_orders,  -> { Current.account.orders.kept.where(delivery_date: Date.current).includes(:client).order(:created_at).limit(5) }
  expose :today_count,   -> { Current.account.orders.kept.where(delivery_date: Date.current).count }

  def show; end
end
