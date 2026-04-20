# Resolves a delivery-type pedido's address into lat/lng via Geocoder
# (Google primary + ipinfo fallback) so the kanban card can render a
# Static Maps thumbnail and a one-tap Google Maps directions deep link.
#
# Enqueued from Orders::Place / Orders::Update whenever a delivery
# pedido's address fields meaningfully change. No-ops quickly when the
# pedido isn't a delivery, is canceled, already has coordinates, or is
# within the post-failure cooldown window.
#
# Failures are swallowed (stamped on `geocoding_failed_at`) instead of
# raised — a missing map is a soft degradation, not a reason to retry
# indefinitely. ActiveJob's built-in retry would otherwise keep hitting
# Google's billable API for a pedido with a typo the operator may
# never fix.
class GeocodeOrderJob < ApplicationJob
  queue_as :low

  # Transient network blips retry a couple times. Everything else is
  # recorded on the pedido as a failure and skipped until cooldown.
  retry_on Geocoder::NetworkError, wait: :polynomially_longer, attempts: 3

  def perform(order_id)
    order = Order.kept.find_by(id: order_id)
    return unless order
    return unless order.needs_geocoding?
    return if order.geocoding_on_cooldown?

    result = Geocoder.search(order.geocoding_address).first

    if result&.latitude.present? && result&.longitude.present?
      order.update_columns(
        latitude:            result.latitude,
        longitude:           result.longitude,
        geocoded_at:         Time.current,
        geocoding_failed_at: nil
      )
    else
      order.update_column(:geocoding_failed_at, Time.current)
    end
  rescue Geocoder::OverQueryLimitError, Geocoder::RequestDenied,
         Geocoder::InvalidApiKey, Geocoder::InvalidRequest => e
    # Hard API errors: don't retry this job, just record the failure
    # so the cooldown kicks in. Sentry will still see the exception.
    Rails.error.report(e, context: { order_id: order_id })
    order&.update_column(:geocoding_failed_at, Time.current)
  end
end
