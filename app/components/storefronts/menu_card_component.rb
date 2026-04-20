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

    delegate :name, :description, :sale_price, :display_photo, to: :recipe

    def photo_variant
      recipe.photos.first&.variant(resize_to_fill: [ 600, 420 ])
    end

    def price_display
      helpers.humanized_money_with_symbol(sale_price)
    end

    def payload
      {
        recipe_id: recipe.prefix_id,
        name:      recipe.name,
        price_cents: recipe.sale_price_cents.to_i,
        photo:     (helpers.url_for(photo_variant) if photo_variant)
      }.compact.to_json
    end
  end
end
