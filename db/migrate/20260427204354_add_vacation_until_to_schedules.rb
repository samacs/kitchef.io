class AddVacationUntilToSchedules < ActiveRecord::Migration[8.1]
  # Phase 14, Slice 8 — vacation mode (cocina pausada).
  # `vacation_until` is the inclusive last day of the pause; while
  # the date is today-or-future the storefront morphs to "Volvemos
  # pronto" and refuses new pedidos. A daily cron clears expired
  # rows (vacation_until < today) automatically.
  #
  # `vacation_message` lets the operator override the default copy
  # ("Volvemos el [fecha]") with something specific — "Cerramos por
  # mudanza", "Embarazo, regreso en agosto", etc.
  def change
    change_table :schedules, bulk: true do |t|
      t.date :vacation_until
      t.text :vacation_message
    end

    add_index :schedules, :vacation_until,
              where: "vacation_until IS NOT NULL",
              name:  "idx_schedules_vacation_until"
  end
end
