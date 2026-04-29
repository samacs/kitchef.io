module Storefronts
  # Single recipe card on the public menu. Large photo, serif name, price,
  # "Agregar" CTA wired to `storefront_cart_controller#add`.
  #
  # The "Agregar" button carries the recipe payload as `data-*` attributes
  # so the cart controller can push the item into sessionStorage without
  # a network round-trip. Prices re-snapshot on the server in
  # `Orders::Place` — the client never holds authoritative pricing.
  class MenuCardComponent < ApplicationComponent
    option :recipe
    option :promo_badge, default: -> { nil }

    delegate :name, :description, :sale_price, :display_photo, to: :recipe

    def photo_variant
      recipe.photos.first&.variant(resize_to_fill: [ 600, 420 ])
    end

    def price_display
      helpers.humanized_money_with_symbol(sale_price)
    end

    def customizable?
      recipe.customizable?
    end

    def requires_advance_notice?
      recipe.requires_advance_notice?
    end

    def lead_time_badge
      return unless requires_advance_notice?
      I18n.t("storefronts.recipe.lead_time.badge", label: recipe.lead_time_label)
    end

    # Phase 13 — when the kitchen has inventory enabled AND the
    # oversell policy is :block AND no batch has stock for today, the
    # add-to-cart button is disabled. Off-accounts never hit this path.
    def stock_blocked?
      return false unless recipe.account.inventory_enabled?
      return false unless recipe.account.inventory_settings.block_oversells?

      Storefronts::MenuStockBadgeComponent.new(recipe: recipe).available_units <= 0
    end

    # Subtle border emphasis when the dish is sold out — red ring under
    # :block policy (truly unavailable), neutral under :warn (customer
    # can still order, badge already says "Por encargo"). Returns ""
    # for everything that's available or for inventory-off accounts.
    def card_emphasis_classes
      return "" unless recipe.account.inventory_enabled?
      available = Storefronts::MenuStockBadgeComponent.new(recipe: recipe).available_units
      return "" if available.to_i.positive?
      recipe.account.inventory_settings.block_oversells? ? "border-err/30 ring-1 ring-err/15" : ""
    end

    def payload
      {
        recipe_id:       recipe.prefix_id,
        recipe_slug:     recipe.slug,
        name:            recipe.name,
        price_cents:     recipe.sale_price_cents.to_i,
        category_id:     recipe.category_id,
        lead_time_hours: recipe.lead_time_hours.to_i,
        photo:           (helpers.url_for(photo_variant) if photo_variant)
      }.compact.to_json
    end
  end
end
