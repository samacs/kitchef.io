module MapsHelper
  # Renders the cached static-map image for any Geocodable record
  # (Order, Supplier, …). Uses the attached `static_map` variant —
  # fetched once by `StaticMapJob` and served from our own storage —
  # so a page that renders N maps hits Google 0 times.
  #
  #   <%= static_map_image_tag(order, variant: :thumb,
  #         alt: t("orders.map.alt"), class: "w-full h-[100px] object-cover") %>
  #
  # Variants are defined on the Geocodable concern:
  #   :thumb — kanban cards, list rows, compact inline contexts
  #   :card  — drawer banners, show pages, "hero" treatment
  #
  # Fallback: when the record is geocoded but the StaticMapJob hasn't
  # attached the source tile yet (brief window right after the
  # geocode), we render the live Google URL so the UI doesn't flash
  # empty. The cache warms on the next page view.
  #
  # Returns nil when the record isn't geocoded — callers should guard
  # on `directions_url_for(record)` (which has the same nil semantics)
  # and skip rendering the map section entirely.
  def static_map_image_tag(record, variant: :thumb, **img_options)
    src = cached_static_map_url(record, variant: variant) ||
          live_static_map_url(record)
    return nil if src.blank?

    image_tag(src, **img_options)
  end

  # Direct URL helper for cases where caller needs the `src` as a
  # string (e.g. an <img> inside a component template that can't take
  # the tag helper). Honors the same cached-first-then-live priority.
  def static_map_src_for(record, variant: :thumb)
    cached_static_map_url(record, variant: variant) ||
      live_static_map_url(record)
  end

  # Deep link to Google Maps directions. The documented
  # `google.com/maps/dir/?api=1` intent works in both the web app and
  # the iOS/Android apps (browser intercepts when installed), and uses
  # the device's current location as the origin automatically — perfect
  # for a runner who just got handed a pedido.
  #
  # Accepts anything that responds to `geocoded?` + `latitude` +
  # `longitude` so the same helper serves orders, suppliers, etc.
  def directions_url_for(geocodable)
    return nil unless geocodable&.geocoded?

    base = "https://www.google.com/maps/dir/?api=1"
    "#{base}&destination=#{geocodable.latitude},#{geocodable.longitude}&travelmode=driving"
  end

  private

  def cached_static_map_url(record, variant:)
    return nil unless record&.geocoded?
    return nil unless record.respond_to?(:static_map) && record.static_map.attached?

    url_for(record.static_map.variant(variant))
  end

  # Fallback URL while the cache is still being generated. Billable —
  # kept strictly for the ~seconds-long window after a successful
  # geocode before StaticMapJob finishes its fetch. Production's HTTP
  # Referer restrictions on the key mitigate accidental scraping.
  def live_static_map_url(record)
    return nil unless record&.geocoded?

    key = ENV["GOOGLE_API_KEY"].to_s.strip
    return nil if key.blank?

    "https://maps.googleapis.com/maps/api/staticmap?" + {
      center:  "#{record.latitude},#{record.longitude}",
      zoom:    15,
      size:    "640x260",
      scale:   2,
      markers: "color:0x0A5A3C|#{record.latitude},#{record.longitude}",
      key:     key
    }.to_query
  end
end
