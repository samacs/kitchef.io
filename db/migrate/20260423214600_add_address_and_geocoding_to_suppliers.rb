class AddAddressAndGeocodingToSuppliers < ActiveRecord::Migration[8.1]
  # `street_address` + lat/lng mirrors the Order geocoding shape so the
  # same `MapsHelper` helpers can render the supplier's static map +
  # Google Maps deep link with minimal code duplication.
  def change
    add_column :suppliers, :street_address,      :string
    add_column :suppliers, :latitude,            :decimal, precision: 10, scale: 6
    add_column :suppliers, :longitude,           :decimal, precision: 10, scale: 6
    add_column :suppliers, :geocoded_at,         :datetime
    add_column :suppliers, :geocoding_failed_at, :datetime
  end
end
