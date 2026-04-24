require "open-uri"

# Fetches a static map PNG from Google and attaches it to the record's
# `:static_map` ActiveStorage attachment. Polymorphic — any model that
# `include Geocodable` qualifies.
#
# Why cache at all: the operator app renders maps in several spots
# (orders kanban, supplier drawer, runner handoff list). The live
# Static Maps URL would bill Google once per page view — N maps × M
# visits = real money on a free-tier operator. Attaching a single
# source tile and serving resized variants amortizes a single API hit
# across every subsequent render.
class StaticMapJob < ApplicationJob
  queue_as :low

  # Source image size (pre-variant). Large enough that the `:card`
  # variant doesn't have to upscale. Scale 2 for retina.
  WIDTH  = 640
  HEIGHT = 260
  ZOOM   = 15

  def perform(record)
    return unless record
    return if record.respond_to?(:discarded?) && record.discarded?
    return unless record.respond_to?(:static_map) && record.respond_to?(:geocoded?)
    return unless record.geocoded?

    url = static_map_url(record)
    return if url.blank?

    URI.open(url, open_timeout: 5, read_timeout: 15) do |io|
      record.static_map.attach(
        io:           io,
        filename:     filename_for(record),
        content_type: "image/png"
      )
    end
  rescue OpenURI::HTTPError, Net::ReadTimeout, Net::OpenTimeout,
         Errno::ECONNRESET, SocketError => e
    Rails.error.report(e, context: { record_gid: record&.to_global_id&.to_s })
  end

  private

  def static_map_url(record)
    key = ENV["GOOGLE_API_KEY"].to_s.strip
    return nil if key.blank?

    "https://maps.googleapis.com/maps/api/staticmap?" + {
      center:  "#{record.latitude},#{record.longitude}",
      zoom:    ZOOM,
      size:    "#{WIDTH}x#{HEIGHT}",
      scale:   2,
      markers: "color:0x0A5A3C|#{record.latitude},#{record.longitude}",
      key:     key
    }.to_query
  end

  def filename_for(record)
    "#{record.class.name.underscore}-#{record.id}-map.png"
  end
end
