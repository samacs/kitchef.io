module Storefronts
  # Public-storefront counterpart to `Orders::Place`. The storefront form
  # captures first_name + last_name + phone and a cart payload; this command
  # resolves (or creates) a Client via phone dedup, then defers to
  # `Orders::Place` for the actual order + items build. Keeping the pricing
  # invariant (server-side snapshot from account-scoped recipes) inside the
  # shared command means a tampered storefront submission can never post a
  # discounted price.
  #
  # On failure, returns an invalid Order as `result.object` so the controller
  # can re-render the checkout form with submitted values intact. On success,
  # the order is persisted with `source: :storefront`, geocoding is enqueued
  # if applicable, and the customer redirects to the confirmation page.
  class PlaceOrder < ApplicationCommand
    option :storefront      # Account
    option :customer_params # hash with first_name, last_name, phone, (email)
    option :order_params    # hash with delivery_type, delivery_date, windows, address, notes, items_attributes…

    def call
      client = resolve_client
      return Result.new(success: false, object: nil, errors: { phone: [ :blank ] }) if client.nil?

      order_payload = order_params.to_h.deep_symbolize_keys.merge(
        client_id: client.id,
        source:    :storefront
      )

      Orders::Place.call(account: storefront, params: order_payload)
    end

    private

    def resolve_client
      phone = customer_params[:phone].to_s.strip
      return nil if phone.blank?

      Client.find_or_create_by_phone!(
        account: storefront,
        phone:   phone,
        attrs: {
          first_name: customer_params[:first_name].to_s.strip.presence,
          last_name:  customer_params[:last_name].to_s.strip.presence,
          email:      customer_params[:email].to_s.strip.presence
        }
      )
    rescue ArgumentError
      # Normalizer couldn't shape the phone into MX E.164 — return nil so
      # the controller surfaces a phone-format error.
      nil
    end
  end
end
