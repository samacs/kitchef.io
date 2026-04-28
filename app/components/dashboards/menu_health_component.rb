module Dashboards
  class MenuHealthComponent < ApplicationComponent
    option :account
    option :published_count
    option :draft_count

    def top_sellers
      @top_sellers ||= account.orders.kept
        .joins(:items)
        .where(delivery_date: 7.days.ago..Date.current)
        .where.not(state: "canceled")
        .group("order_items.recipe_id")
        .order(Arel.sql("SUM(order_items.quantity) DESC"))
        .limit(4)
        .pluck(Arel.sql("order_items.recipe_id, SUM(order_items.quantity)"))
        .then { |pairs| load_recipes(pairs) }
    end

    private

    def load_recipes(pairs)
      return [] if pairs.empty?

      ids = pairs.map(&:first)
      recipes_by_id = account.recipes.where(id: ids).index_by(&:id)
      pairs.filter_map { |id, qty| recipes_by_id[id] && [ recipes_by_id[id], qty.to_i ] }
    end
  end
end
