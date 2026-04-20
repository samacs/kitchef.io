class CreateDeliverySlots < ActiveRecord::Migration[8.1]
  def change
    create_table :delivery_slots do |t|
      t.references :account, null: false, foreign_key: true, index: true

      t.integer :day_of_week, null: false               # 0 = Sunday … 6 = Saturday
      t.integer :start_time,  null: false               # minutes from midnight (0..1440)
      t.integer :end_time,    null: false
      t.integer :max_orders,  null: false, default: 10

      t.jsonb   :colonias, null: false, default: []
      t.integer :position

      t.timestamps

      t.check_constraint "start_time < end_time",
        name: "chk_delivery_slots_start_before_end"
      t.check_constraint "start_time >= 0 AND end_time <= 1440",
        name: "chk_delivery_slots_time_in_day"
      t.check_constraint "day_of_week BETWEEN 0 AND 6",
        name: "chk_delivery_slots_day_of_week"
    end

    add_index :delivery_slots, [ :account_id, :day_of_week, :position ]
  end
end
