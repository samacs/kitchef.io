module MapsHelper
  # Static Maps URL for the tiny card thumbnail. Google's free tier
  # covers the first 100k loads/month; the URL exposes the API key in
  # HTML which is the product's documented pattern — tighten with HTTP
  # referrer restrictions on the key in production.
  def static_map_url_for(order, width: 560, height: 200, zoom: 15)
    return nil unless order&.geocoded?

    key = ENV["GOOGLE_API_KEY"].to_s.strip
    return nil if key.blank?

    params = {
      center:  "#{order.latitude},#{order.longitude}",
      zoom:    zoom,
      size:    "#{width}x#{height}",
      scale:   2, # retina-friendly
      markers: "color:0x0A5A3C|#{order.latitude},#{order.longitude}",
      key:     key
    }
    "https://maps.googleapis.com/maps/api/staticmap?" + params.to_query
  end

  # Deep link to Google Maps directions. The documented
  # `google.com/maps/dir/?api=1` intent works in both the web app and
  # the iOS/Android apps (browser intercepts when installed), and uses
  # the device's current location as the origin automatically — perfect
  # for a runner who just got handed a pedido.
  def directions_url_for(order)
    return nil unless order&.geocoded?

    base = "https://www.google.com/maps/dir/?api=1"
    "#{base}&destination=#{order.latitude},#{order.longitude}&travelmode=driving"
  end
end
