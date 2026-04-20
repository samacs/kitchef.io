# Intermediate state between `ready` and `delivered`: the pedido has
# left the kitchen with a runner but hasn't yet been handed over.
# `en_route_started_at` captures when the `ship` event fired so reports
# can answer "how long does a pedido spend in reparto" alongside the
# other state-lifecycle timestamps.
class AddEnRouteStartedAtToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :en_route_started_at, :datetime
  end
end
