module Dashboards
  class UpcomingWorkComponent < ApplicationComponent
    option :account
    option :weekly_list            # Production::WeeklyShoppingList::Result
    option :low_stock_ingredients  # Array<Ingredient> (empty for Free)

    def advanced?       = weekly_list.advanced?
    def empty?          = weekly_list.empty?
    def rows            = weekly_list.rows.first(5)
    def remaining_count = [ weekly_list.rows.size - 5, 0 ].max
    def has_alerts?     = low_stock_ingredients.any?

    def estimated_cost_cents
      return nil unless advanced?

      weekly_list.rows.sum do |row|
        ing = row.ingredient
        next 0 unless ing&.unit_cost_cents&.positive?
        qty = Recipes::UnitConverter.convert(quantity: row.total_qty, from: row.unit, to: ing.unit)
        (qty * ing.unit_cost_cents).to_i
      rescue Recipes::UnitConverter::IncompatibleUnits
        0
      end
    end

    def cta_path
      helpers.production_shopping_list_path
    end
  end
end
