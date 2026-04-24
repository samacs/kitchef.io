module Geocodable
  extend ActiveSupport::Concern

  # Retry cooldown after a failed geocode so a typo'd address doesn't
  # keep burning billable Google quota. Applies across both the
  # GeocodeJob (primary) and any caller that inspects
  # `geocoding_on_cooldown?` before enqueueing.
  GEOCODING_RETRY_COOLDOWN = 1.hour

  # Static map variants sized for each surface they're rendered on:
  #   :thumb — kanban cards, list rows, any compact inline context
  #   :card  — drawer banners, show pages, "hero" treatment
  # Both resize the source tile (fetched once per coord change by
  # StaticMapJob) so we don't re-hit Google on every page view.
  STATIC_MAP_VARIANTS = {
    thumb: { resize_to_limit: [ 400, 160 ] },
    card:  { resize_to_limit: [ 640, 260 ] }
  }.freeze

  included do
    has_one_attached :static_map do |attachable|
      STATIC_MAP_VARIANTS.each do |name, transforms|
        attachable.variant(name, **transforms)
      end
    end

    after_commit :enqueue_geocode_if_needed, on: [ :create, :update ]
    after_update_commit :refresh_static_map_if_location_changed
  end

  class_methods do
    # Subclasses declare which columns compose the geocoding address.
    # Changes to any of these columns invalidate the cached coords +
    # attached map and re-enqueue the background geocode.
    #
    #   class Supplier < ApplicationRecord
    #     include Geocodable
    #     geocodable_by :street_address, :colonia, :city
    #   end
    #
    #   class Order < ApplicationRecord
    #     include Geocodable
    #     geocodable_by :delivery_address, :colonia, :city
    #     def geocodable? = delivery? && !canceled?
    #   end
    def geocodable_by(*attrs)
      @geocodable_attrs = attrs.map(&:to_s).freeze
    end

    def geocodable_attrs
      @geocodable_attrs || []
    end
  end

  # Default implementation — joins the declared geocodable attrs with
  # ", " and appends ", México" so Google resolves to the right country.
  # Subclasses can override for domain-specific assembly.
  def geocoding_address
    parts = self.class.geocodable_attrs.map { |attr| public_send(attr).presence }.compact
    return nil if parts.empty?
    (parts + [ "México" ]).join(", ")
  end

  # Extra gate beyond "has an address, no coords yet". Defaults to true;
  # override when the record only geocodes under certain conditions
  # (e.g. Order only geocodes delivery-type pedidos that aren't canceled).
  def geocodable?
    true
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def needs_geocoding?
    geocodable? && geocoding_address.present? && !geocoded?
  end

  def geocoding_on_cooldown?
    return false if geocoding_failed_at.blank?
    geocoding_failed_at > GEOCODING_RETRY_COOLDOWN.ago
  end

  private

  # Runs after every create/update. Clears stale coords on address
  # changes and enqueues a fresh geocode when the record is eligible.
  # No-ops cheaply when the relevant columns didn't move.
  def enqueue_geocode_if_needed
    attrs = self.class.geocodable_attrs
    return if attrs.empty?

    addr_changed = (saved_changes.keys & attrs).any?
    is_new = saved_change_to_id?

    return unless addr_changed || is_new

    # Address moved — invalidate the previous geocode so the UI falls
    # back to the "aún sin ubicar" state until the new fetch lands,
    # instead of showing a stale pin.
    if addr_changed && !is_new
      update_columns(
        latitude:            nil,
        longitude:           nil,
        geocoded_at:         nil,
        geocoding_failed_at: nil
      )
      static_map.purge_later if static_map.attached?
    end

    return unless needs_geocoding?
    return if geocoding_on_cooldown?

    GeocodeJob.perform_later(self)
  end

  # Any lat/lng change triggers a fresh static-map fetch. The job purges
  # the previous attachment, so we always end up with a single
  # up-to-date PNG in ActiveStorage.
  def refresh_static_map_if_location_changed
    return unless saved_change_to_latitude? || saved_change_to_longitude?
    return unless geocoded?

    StaticMapJob.perform_later(self)
  end
end
