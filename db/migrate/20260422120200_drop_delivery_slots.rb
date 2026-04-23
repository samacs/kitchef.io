class DropDeliverySlots < ActiveRecord::Migration[8.1]
  # `delivery_slots` is superseded by `schedules` + `availabilities` as of
  # Phase 6. The table had no production data (pre-launch), so we drop it
  # rather than maintaining a stale unused surface. `Account#delivery_slots`
  # was removed alongside.
  def change
    drop_table :delivery_slots do |t|
      t.references :account, null: false, foreign_key: true, index: true

      t.integer :day_of_week, null: false
      t.integer :start_time,  null: false
      t.integer :end_time,    null: false
      t.integer :max_orders,  null: false, default: 10
      t.integer :capacity

      t.jsonb   :colonias, null: false, default: []
      t.integer :position

      t.timestamps

      t.check_constraint "start_time < end_time", name: "chk_delivery_slots_start_before_end"
      t.check_constraint "start_time >= 0 AND end_time <= 1440", name: "chk_delivery_slots_time_in_day"
      t.check_constraint "day_of_week BETWEEN 0 AND 6", name: "chk_delivery_slots_day_of_week"
    end
  end
end
