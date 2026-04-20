namespace :orders do
  desc "Enqueue GeocodeOrderJob for every delivery pedido that still needs coordinates"
  task backfill_geocoding: :environment do
    scope = Order.kept.where(delivery_type: Order::DELIVERY_TYPES[:delivery], latitude: nil)
    total = scope.count
    enqueued = 0
    skipped  = 0

    scope.find_each do |order|
      if order.needs_geocoding? && !order.geocoding_on_cooldown?
        GeocodeOrderJob.perform_later(order.id)
        enqueued += 1
      else
        skipped += 1
      end
    end

    puts "Scanned #{total} delivery pedido(s): enqueued #{enqueued}, skipped #{skipped}"
  end
end
