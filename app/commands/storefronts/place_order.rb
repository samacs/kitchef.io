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

      if phone.blank? && email.blank?
        order = storefront.orders.new(order_params.to_h.deep_symbolize_keys)
        order.errors.add(:base, :contact_required)
        return Result.new(success: false, object: order, errors: order.errors)
      end

      client = resolve_client(phone: phone, email: email)
      if client.nil?
        order = storefront.orders.new(order_params.to_h.deep_symbolize_keys)
        order.errors.add(:base, phone.present? ? :invalid_phone : :invalid_email)
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

    # Resolve a client record from the submitted contact details.
    # Preference order: phone (the canonical dedup key) → email. At
    # least one must be present; the call-site validates that before
    # reaching here.
    def resolve_client(phone:, email:)
      attrs = {
        first_name: customer_params[:first_name].to_s.strip.presence,
        last_name:  customer_params[:last_name].to_s.strip.presence,
        email:      email.presence
      }

      if phone.present?
        Client.find_or_create_by_phone!(account: storefront, phone: phone, attrs: attrs)
      else
        Client.find_or_create_by_email!(account: storefront, email: email, attrs: attrs)
      end
    rescue ArgumentError
      # Phone normalizer couldn't shape the input into MX E.164, or the
      # email was blank by the time we got here — return nil so the
      # controller surfaces a contact-format error.
      nil
    end
  end
end
