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
      phone = customer_params[:phone].to_s.strip
      email = customer_params[:email].to_s.strip

      # Both phone and email are required at checkout:
      #   * Phone is the kitchen ↔ customer channel of record (WhatsApp).
      #   * Email is our identity-verification gate — the order stays
      #     dormant in `placed` until the customer clicks the signed link
      #     we send to their inbox. Without an email there's no way to
      #     prove ownership, so we reject at this layer rather than
      #     accepting a ghost order.
      if phone.blank?
        order = storefront.orders.new(order_params.to_h.deep_symbolize_keys)
        order.errors.add(:base, :phone_required)
        return Result.new(success: false, object: order, errors: order.errors)
      end

      if email.blank?
        order = storefront.orders.new(order_params.to_h.deep_symbolize_keys)
        order.errors.add(:base, :email_required)
        return Result.new(success: false, object: order, errors: order.errors)
      end

      client = resolve_client(phone: phone, email: email)
      if client.nil?
        order = storefront.orders.new(order_params.to_h.deep_symbolize_keys)
        order.errors.add(:base, :invalid_phone)
        return Result.new(success: false, object: order, errors: order.errors)
      end

      order_payload = order_params.to_h.deep_symbolize_keys.merge(
        client_id: client.id,
        source:    :storefront
      )

      result = Orders::Place.call(account: storefront, params: order_payload)
      notify_operator(result.object) if result.success?
      send_confirmation_email(result.object, client) if result.success?
      result
    end

    private

    # Fire-and-forget — the storefront confirmation response should never
    # stall on a notification enqueue. `deliver_later` pushes the Noticed
    # event to Sidekiq; rescue because Valkey being down must not break
    # the pedido placement path.
    def notify_operator(order)
      return if storefront.owner.nil?

      StorefrontOrderPlacedNotification
        .with(order_id: order.id, record: order)
        .deliver_later(storefront.owner)
    rescue StandardError => e
      Rails.logger.error "[PlaceOrder] operator notification failed for order #{order.id}: #{e.message}"
    end

    def send_confirmation_email(order, client)
      return if storefront.discarded_at.present?
      return if client.email.blank?

      StorefrontOrdersMailer.with(order: order).placed.deliver_later
    rescue StandardError => e
      Rails.logger.error "[PlaceOrder] confirmation email failed for order #{order.id}: #{e.message}"
    end

    # Resolve a client record from the submitted phone + optional
    # email. Phone is the canonical dedup key — the call-site
    # guarantees it's present before we get here.
    def resolve_client(phone:, email:)
      attrs = {
        first_name: customer_params[:first_name].to_s.strip.presence,
        last_name:  customer_params[:last_name].to_s.strip.presence,
        email:      email.presence
      }

      Client.find_or_create_by_phone!(account: storefront, phone: phone, attrs: attrs)
    rescue ArgumentError
      # Phone normalizer couldn't shape the input into MX E.164 —
      # return nil so the controller surfaces a phone-format error.
      nil
    end
  end
end
