class AddBadgeFieldsToPromotions < ActiveRecord::Migration[8.1]
  def change
    add_column :promotions, :badge_label, :string
    add_column :promotions, :badge_color, :string
  end
end
