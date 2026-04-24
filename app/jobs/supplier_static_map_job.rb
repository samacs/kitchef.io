# Compatibility shim — see GeocodeOrderJob. Remove once Sidekiq's
# retry + dead queues no longer hold jobs enqueued under this name.
class SupplierStaticMapJob < ApplicationJob
  queue_as :low

  def perform(supplier_id)
    supplier = Supplier.kept.find_by(id: supplier_id)
    return unless supplier

    StaticMapJob.perform_later(supplier)
  end
end
