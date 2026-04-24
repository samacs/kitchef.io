# Polymorphic geocoder job — works against any model that
# `include Geocodable`. Receives the AR record via GlobalID so one
# shared code path serves Order, Supplier, and anything Phase 10+ adds.
#
# Failures short-circuit onto `geocoding_failed_at` instead of retrying
# indefinitely — a typo'd address shouldn't keep hitting Google's
# billable API.
class GeocodeJob < ApplicationJob
  queue_as :low

  # Transient network blips retry a couple times. Everything else is
  # recorded on the record as a failure and skipped until cooldown.
  retry_on Geocoder::NetworkError, wait: :polynomially_longer, attempts: 3

  def perform(record)
    return unless record
    return if record.respond_to?(:discarded?) && record.discarded?
    return unless record.respond_to?(:needs_geocoding?) && record.needs_geocoding?
    return if record.geocoding_on_cooldown?

    result = Geocoder.search(record.geocoding_address).first

    if result&.latitude.present? && result&.longitude.present?
      # Use update! so the after_update_commit on Geocodable fires and
      # kicks off StaticMapJob. update_columns would skip the callback.
      record.update!(
        latitude:            result.latitude,
        longitude:           result.longitude,
        geocoded_at:         Time.current,
        geocoding_failed_at: nil
      )
    else
      record.update_column(:geocoding_failed_at, Time.current)
    end
  rescue Geocoder::OverQueryLimitError, Geocoder::RequestDenied,
         Geocoder::InvalidApiKey, Geocoder::InvalidRequest => e
    Rails.error.report(e, context: { record_gid: record&.to_global_id&.to_s })
    record&.update_column(:geocoding_failed_at, Time.current)
  end
end
