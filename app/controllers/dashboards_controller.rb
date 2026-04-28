class DashboardsController < AuthenticatedController
  def show
    @account = Current.account
    @recipe_count = @account.recipes.kept.saleable.count

    return if @recipe_count.zero?

    @today = Date.current
    @today_plan = Production::DailyPlan.for(account: @account, on: @today)
    @weekly_list = Production::WeeklyShoppingList.for(account: @account, starting: @today)
    @recent_orders = @account.orders.kept
      .includes(:client)
      .order(created_at: :desc)
      .limit(5)
    @published_count = @account.recipes.kept.where(is_saleable: true, is_published: true).count
    @draft_count = @account.recipes.kept.where(is_saleable: true, is_published: false).count

    if @account.inventory_enabled?
      @low_stock_ingredients = @account.ingredients.kept.select(&:low_stock?)
    end
  end
end
