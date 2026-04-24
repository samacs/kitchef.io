# Compatibility shim — forwards to the polymorphic `GeocodeJob`.
#
# We renamed the per-model geocode jobs to a single shared class in
# Phase 9 (see `Geocodable` concern), but Sidekiq's retry queue held
# onto jobs that were enqueued under the old `GeocodeOrderJob` name
# with integer id args. Those would otherwise fail forever with
# `ActiveJob::UnknownJobClassError`.
#
# Safe to delete this file once the retry + dead queues have drained
# (Sidekiq's default retry schedule maxes out around 21 days; faster if
# you clear the Retries tab manually).
class GeocodeOrderJob < ApplicationJob
  queue_as :low

  def perform(order_id)
    order = Order.kept.find_by(id: order_id)
    return unless order

    GeocodeJob.perform_later(order)
  end
end
