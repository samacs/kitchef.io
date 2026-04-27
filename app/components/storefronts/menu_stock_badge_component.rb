module Storefronts
  # Tiny chip that hangs over the storefront menu card and tells the
  # customer how many units of this dish are still available for the
  # day she's selected — silent abundance for plenty of stock,
  # "Quedan N" for low, "Última pieza" / "Agotado" at the floor.
  #
  # Renders only when the kitchen has inventory enabled. For accounts
  # without inventory the menu stays exactly as Phase 12 had it.
  class MenuStockBadgeComponent < ApplicationComponent
    option :recipe
    option :on_date, default: -> { Date.current }

    def render?
      return false unless account.inventory_enabled?
      label.present?
    end

    def state
      return :out_of_stock if available_units <= 0
      return :last_one     if available_units <= 1
      return :limited      if available_units <= 5
      :abundant
    end

    def label
      case state
      when :out_of_stock
        block_oversells? ? t("storefronts.menu.stock.sold_out") : t("storefronts.menu.stock.special_order")
      when :last_one
        t("storefronts.menu.stock.last_one")
      when :limited
        t("storefronts.menu.stock.remaining", count: available_units.to_i)
      else
        nil
      end
    end

    def block_oversells?
      account.inventory_settings.block_oversells?
    end

    def available_units
      @available_units ||= Orders::BatchPicker.available_units(
        account:  account,
        recipe:   recipe,
        on_date:  on_date
      )
    end

    def chip_classes
      case state
      when :out_of_stock
        "border-warn/40 bg-[color-mix(in_oklab,var(--color-warn)_10%,var(--color-surface))] text-warn"
      when :last_one, :limited
        "border-line bg-bg-2 text-ink-2"
      else
        ""
      end
    end

    private

    def account
      recipe.account
    end
  end
end
