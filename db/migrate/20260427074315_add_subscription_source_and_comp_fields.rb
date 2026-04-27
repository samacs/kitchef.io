class AddSubscriptionSourceAndCompFields < ActiveRecord::Migration[8.1]
  # Phase 14, Slice 1.
  #
  # Adds the entitlement-source enum and comp-grant audit fields to
  # `subscriptions`. `source` answers "where does this account's Pro
  # access come from?" — Stripe, a manual comp grant, or nothing
  # (Free). The comp_* triplet captures who/why/when admins donated
  # Pro access; paper_trail picks up the rest of the audit history.
  #
  # `pro_monthly` (2) and `pro_yearly` (3) are added as new plan enum
  # values; the legacy `pro` (1) stays as-is so any in-flight rows
  # keep working until we rename via Subscriptions::SyncFromStripe.
  def change
    change_table :subscriptions, bulk: true do |t|
      t.integer  :source, null: false, default: 0
      t.bigint   :comp_granted_by_id
      t.text     :comp_reason
      t.datetime :comp_expires_at
    end

    add_index :subscriptions, :source
    add_index :subscriptions, :comp_granted_by_id
    add_index :subscriptions,
              :comp_expires_at,
              where: "comp_expires_at IS NOT NULL",
              name: "idx_subscriptions_comp_expires_at"

    add_foreign_key :subscriptions, :users,
                    column: :comp_granted_by_id, on_delete: :nullify
  end
end
