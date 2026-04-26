module Ingredients
  # Single table-cell renderer for the "En existencia" column on
  # /ingredients (only mounted when account.inventory_enabled?). Shows
  # the formatted quantity + a "bajo stock" chip when the ingredient is
  # below the operator's configured threshold.
  class StockCellComponent < ApplicationComponent
    option :ingredient

    def stock_label
      qty = ingredient.stock_quantity.to_d
      "#{format_qty(qty)} #{ingredient.unit}"
    end

    def low_stock?
      ingredient.low_stock?
    end

    def out_of_stock?
      ingredient.stock_quantity.to_d <= 0
    end

    private

    # Drop trailing zeros so "0.500 kg" reads as "0.5 kg" but "1.250"
    # stays as "1.25" — hides decimal noise while keeping precision
    # the operator entered.
    def format_qty(qty)
      formatted = format("%.3f", qty)
      formatted.sub(/\.?0+$/, "").presence || "0"
    end
  end
end
