module Storefronts
  # Renders the kitchen's pickup address + cached static map + a deep
  # link to Google Maps directions. Used in two surfaces:
  #
  #   * Kitchen homepage (storefronts/show) — at the bottom, when the
  #     operator has opted in via `public_profile.show_pickup_address`.
  #
  #   * Order confirmation (storefronts/orders/show) — when the
  #     customer chose pickup at checkout, regardless of the public
  #     opt-in (you bought it, you get the address).
  #
  # The static map is fetched once by `StaticMapJob` and served from
  # ActiveStorage; the live Google URL is the fallback only during the
  # brief window after a fresh geocode. Either way: zero billable hits
  # on every customer page view.
  class PickupAddressComponent < ApplicationComponent
    option :account
    option :variant, default: -> { :card }   # :card on confirmation, :hero on homepage

    delegate :public_profile, to: :account

    def render?
      account.street_address.present? && account.geocoded?
    end

    def address_lines
      [
        account.street_address,
        [ public_profile.colonia.presence, public_profile.city.presence ].compact.join(", ").presence
      ].compact
    end

    def directions_url
      helpers.directions_url_for(account)
    end

    def static_map_src
      helpers.static_map_src_for(account, variant: :card)
    end
  end
end
