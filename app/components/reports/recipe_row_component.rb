module Reports
  # One row in the /reports/menu ranked lists. Keeps the information tight:
  # platillo name, units sold, margin contribution, margin %. Clicks through
  # to /recipes/:slug so the operator can drop from "why is this slow?" to
  # "what's its cost tree?" in one tap.
  class RecipeRowComponent < ApplicationComponent
    option :row
    option :variant, default: -> { :default } # :star | :steady | :review

    def recipe       = row.recipe
    def revenue      = Money.new(row.revenue_cents, "MXN")
    def margin_money = Money.new(row.margin_cents, "MXN")
    def margin_pct   = row.margin_pct

    def idle? = row.idle?

    def star? = variant == :star

    def review_tag
      return :no_sales if idle?

      target = recipe.target_margin_percent
      pct = row.margin_pct
      return :low_margin if pct && target && pct < target

      nil
    end

    def days_since_last_sale
      return nil if row.last_sold_on.nil?
      (Date.current - row.last_sold_on).to_i
    end
  end
end
