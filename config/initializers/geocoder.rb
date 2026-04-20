require "geocoder"

# Geocoder config for Phase-2C order geocoding. Delivery-type pedidos
# with a usable address get coordinates filled in the background (see
# GeocodeOrderJob) so the kanban card can show a small map thumbnail
# and a one-tap deep link to Google Maps directions.
#
# Two providers:
#   1. Google Geocoding (primary) — accurate street-address resolution
#      when colonia + calle + ciudad are all present.
#   2. ipinfo (fallback) — "at least a city-level pin" when Google
#      returns ZERO_RESULTS. Used sparingly; most pedidos have enough
#      address data for Google to hit.
#
# Results cache in Valkey via Rails.cache (the same connection Sidekiq
# and Rails.cache already share) so two pedidos to the same address
# cost one API call. 30-day TTL amortizes Google pricing across a
# month and stays fresh enough that client-address corrections
# re-geocode within a reasonable window.

google_key = ENV["GOOGLE_API_KEY"].to_s.strip
ipinfo_key = ENV["IP_INFO_API_KEY"].to_s.strip

Geocoder.configure(
  lookup:        google_key.present? ? :google : :nominatim,
  ip_lookup:     ipinfo_key.present? ? :ipinfo_io : :freegeoip,
  api_key:       google_key.presence,
  timeout:       5,
  language:      :es,
  units:         :km,
  use_https:     true,
  always_raise:  [ Geocoder::OverQueryLimitError, Geocoder::RequestDenied,
                   Geocoder::InvalidRequest, Geocoder::InvalidApiKey ],
  cache:         Rails.cache,
  cache_options: { expiration: 30.days, prefix: "geocoder:" }
)

# ipinfo's key lives on its own adapter, merged in on top of the main
# config above so a single Geocoder.search(ip) call finds it.
if ipinfo_key.present?
  Geocoder::Lookup::IpinfoIo.instance.instance_variable_set(:@api_key, ipinfo_key) rescue nil
end
