module Accounts
  # Resolves an IANA timezone from lat/lng coordinates. Mexico-focused:
  # uses the four official Mexican time zones based on state boundaries
  # approximated by longitude bands. Falls back to America/Mexico_City
  # for coordinates outside Mexico or when lat/lng is missing.
  #
  # The four zones (as of 2022 reform, no more DST):
  #   • America/Tijuana      — Baja California (west of -114°)
  #   • America/Mazatlan     — Sinaloa, BCS, Nayarit, Sonora fringe
  #   • America/Hermosillo   — Sonora (no DST, same offset as Mazatlan but distinct)
  #   • America/Mexico_City  — everything else (vast majority)
  #
  # Sonora is the tricky one: it doesn't observe DST (like Arizona),
  # so it gets its own zone even though it's geographically between
  # Mazatlan and Chihuahua.
  class TimezoneResolver < ApplicationService
    option :latitude
    option :longitude

    SONORA_BOUNDS = {
      lat_min: 26.3, lat_max: 32.5,
      lon_min: -115.0, lon_max: -108.8
    }.freeze

    def call
      return "America/Mexico_City" if latitude.blank? || longitude.blank?

      lat = latitude.to_f
      lon = longitude.to_f

      return "America/Mexico_City" unless mexican_coordinates?(lat, lon)

      if baja_california?(lat, lon)
        "America/Tijuana"
      elsif sonora?(lat, lon)
        "America/Hermosillo"
      elsif baja_california_sur_sinaloa?(lat, lon)
        "America/Mazatlan"
      else
        "America/Mexico_City"
      end
    end

    private

    def mexican_coordinates?(lat, lon)
      lat.between?(14.5, 32.8) && lon.between?(-118.5, -86.5)
    end

    def baja_california?(lat, lon)
      lat > 28.0 && lon < -114.5
    end

    def sonora?(lat, lon)
      lat.between?(SONORA_BOUNDS[:lat_min], SONORA_BOUNDS[:lat_max]) &&
        lon.between?(SONORA_BOUNDS[:lon_min], SONORA_BOUNDS[:lon_max])
    end

    def baja_california_sur_sinaloa?(lat, lon)
      lon < -106.5 && lat < 28.0
    end
  end
end
