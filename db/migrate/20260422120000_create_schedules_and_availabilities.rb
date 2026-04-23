class CreateSchedulesAndAvailabilities < ActiveRecord::Migration[8.1]
  def change
    # One schedule per account in v1 — the UI never exposes a second one.
    # The table-level unique index on `account_id` enforces that model
    # invariant even if a future refactor forgets `has_one`.
    create_table :schedules do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }

      # `order_mode` governs what the storefront picker shows:
      #   - advance  → future windows only (respecting lead_time_minutes)
      #   - same_day → "ASAP" + remaining windows today
      #   - both     → a kitchen that offers both (Uber-style + pre-order)
      t.integer :order_mode,       null: false, default: 0
      # Minimum notice before a window becomes sellable. 0 means "anything
      # today + later", 60 means "anything at least an hour from now", etc.
      # Applies ONLY in advance mode — same_day's "ASAP" bypasses lead time.
      t.integer :lead_time_minutes, null: false, default: 0

      t.timestamps

      t.check_constraint "order_mode IN (0, 1, 2)",
        name: "chk_schedules_order_mode"
      t.check_constraint "lead_time_minutes >= 0",
        name: "chk_schedules_lead_time_nonnegative"
    end

    # Availabilities — one row per "window" on the schedule. Mirrors
    # Agendario's shape: either a recurring weekly slot (wday set, date
    # nil) or a date-specific override (date set, wday nil). The XOR
    # constraint is enforced at the model AND database layer so a stray
    # update can never produce a malformed row.
    #
    # `available:false` on a date-specific row = "the kitchen is closed
    # that day" and overrides any recurring window on the same date.
    # `available:true` on a date-specific row = "custom hours that day".
    create_table :availabilities do |t|
      t.references :schedule, null: false, foreign_key: true, index: true
      t.integer    :wday                              # 0 = Sunday … 6 = Saturday
      t.date       :date
      t.integer    :from_time, null: false            # minutes from midnight
      t.integer    :to_time,   null: false
      t.boolean    :available, null: false, default: true
      t.string     :note                              # e.g. "Día de la Independencia"

      t.timestamps

      t.check_constraint "wday BETWEEN 0 AND 6 OR wday IS NULL",
        name: "chk_availabilities_wday_range"
      t.check_constraint "from_time >= 0 AND to_time <= 1440",
        name: "chk_availabilities_in_day"
      t.check_constraint "from_time < to_time",
        name: "chk_availabilities_from_before_to"
      t.check_constraint "(wday IS NOT NULL AND date IS NULL) OR (wday IS NULL AND date IS NOT NULL)",
        name: "chk_availabilities_wday_xor_date"
    end

    add_index :availabilities, [ :schedule_id, :wday ], where: "wday IS NOT NULL"
    add_index :availabilities, [ :schedule_id, :date ], where: "date IS NOT NULL"
  end
end
