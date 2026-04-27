class CreateSubscriptionsDismissedHints < ActiveRecord::Migration[8.1]
  # Phase 14, Slice 1.
  #
  # Per-account, per-hint-key dismissal record so an operator who
  # closes an upgrade-hint banner doesn't see it again on every
  # device-switch. Hints with a `redismiss_at` future timestamp
  # resurface monthly (set by Slice 7's banner controller); without
  # it, dismissal is permanent.
  def change
    create_table :subscriptions_dismissed_hints do |t|
      t.references :account, null: false, foreign_key: true
      t.string     :hint_key, null: false
      t.datetime   :dismissed_at, null: false
      t.datetime   :redismiss_at
      t.timestamps
    end

    add_index :subscriptions_dismissed_hints,
              %i[account_id hint_key],
              unique: true,
              name:   "idx_dismissed_hints_account_key"
  end
end
