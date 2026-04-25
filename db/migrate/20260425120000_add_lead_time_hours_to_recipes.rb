class AddLeadTimeHoursToRecipes < ActiveRecord::Migration[8.1]
  def change
    add_column :recipes, :lead_time_hours, :integer, default: 0, null: false
  end
end
