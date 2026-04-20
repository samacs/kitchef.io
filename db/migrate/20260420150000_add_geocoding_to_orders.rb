# Delivery-type pedidos get geocoded in the background so the kanban
# card can show a small map thumbnail + a one-tap Google Maps
# directions link for the runner. `geocoded_at` stamps the last
# successful geocode; `geocoding_failed_at` stamps the most recent
# failure so GeocodeOrderJob can back off instead of hammering Google.
class AddGeocodingToOrders < ActiveRecord::Migration[8.1]
  def change
    change_table :orders, bulk: true do |t|
      t.decimal :latitude,  precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.datetime :geocoded_at
      t.datetime :geocoding_failed_at
    end

    add_index :orders, %i[latitude longitude]
  end
end
