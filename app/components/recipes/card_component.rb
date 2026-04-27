module Recipes
  # Phase-2B recipe card for the recipes index and dashboard grid. Links to
  # the edit page (simple mode has no dedicated show surface yet), shows a
  # publish-state badge ("Publicada" / "Borrador"), and carries a quick-
  # toggle button the operator can use to flip publication without
  # opening the form.
  class CardComponent < ApplicationComponent
    option :recipe

    def category_label
      recipe.category&.name
    end

    def price_label
      helpers.humanized_money_with_symbol(recipe.sale_price)
    end

    def photo_url
      return nil unless recipe.photos.attached?

      helpers.url_for(recipe.photos.first.variant(:card))
    end

    def publishable?
      recipe.photos.attached?
    end

    def published?
      recipe.is_published?
    end

    # Phase 13C — when inventory is enabled and this saleable recipe has
    # no batches available today, mark the card so the operator can
    # spot it from the index. Severity follows the account's oversell
    # policy: :block ⇒ red (you can't sell it), :warn ⇒ amber (you'll
    # sell oversold).
    def stock_alert
      return :none unless inventory_visible?
      return :none if stock_summary.any?
      recipe.account.inventory_settings.block_oversells? ? :block : :warn
    end

    def stock_alert_classes
      case stock_alert
      when :block then "border-err/40 bg-[color-mix(in_oklab,var(--color-err)_5%,var(--color-surface))]"
      when :warn  then "border-warn/40 bg-[color-mix(in_oklab,var(--color-warn)_5%,var(--color-surface))]"
      else "border-line bg-surface"
      end
    end

    def stock_alert_message
      return nil if stock_alert == :none
      I18n.t("recipes.card.stock_alert.#{stock_alert}")
    end

    # Live availability projection for the operator, shown when the
    # recipe has any batches covering today. Splits "completed → ready
    # to sell" from "in progress → on the comal right now" so the
    # operator can tell whether a unit count is fridge stock or work in
    # flight. Returns nil when inventory is disabled, the recipe isn't
    # saleable, or there's no covering batch (the alert message handles
    # that case).
    def stock_summary
      @stock_summary ||= Recipes::StockSummary.call(
        account: recipe.account,
        recipe:  recipe
      )
    end

    def stock_summary_visible?
      inventory_visible? && stock_summary.any?
    end

    def inventory_visible?
      recipe.account.inventory_enabled? && recipe.is_saleable?
    end
  end
end
