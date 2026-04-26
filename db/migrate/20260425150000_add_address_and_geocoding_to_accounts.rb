class AddAddressAndGeocodingToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :street_address,      :string
    add_column :accounts, :latitude,            :decimal, precision: 10, scale: 6
    add_column :accounts, :longitude,           :decimal, precision: 10, scale: 6
    add_column :accounts, :geocoded_at,         :datetime
    add_column :accounts, :geocoding_failed_at, :datetime

    add_index :accounts, [ :latitude, :longitude ]
  end
end
