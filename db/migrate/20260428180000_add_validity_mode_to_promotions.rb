class AddValidityModeToPromotions < ActiveRecord::Migration[8.1]
  def change
    add_column :promotions, :validity_mode, :integer, null: false, default: 0
    add_column :promotions, :valid_weekdays, :integer, array: true, default: [], null: false
  end
end
