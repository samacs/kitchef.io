class NormalizePaidStateToDelivered < ActiveRecord::Migration[8.1]
  # Payment is no longer an AASM state — it's a property on the Order
  # (`paid_at`). Any historical rows still carrying `state='paid'` get
  # rewritten so they land in the new world:
  #   - state                   → 'delivered'
  #   - paid_at (if null)       → COALESCE(delivered_at, updated_at)
  #   - delivered_at (if null)  → paid_at OR updated_at  (so the timeline
  #                               shows a "Entregado" timestamp)
  #   - balance_cents           → 0 (paid means settled)
  #
  # The sequence of COALESCEs matters — we stamp `paid_at` from the
  # existing delivered_at when possible, then backfill delivered_at so
  # both stamps are populated. Rails' whodunnit/papertrail column is
  # intentionally skipped; this is a data shape migration, not a user
  # action worth attributing.
  def up
    execute <<~SQL
      UPDATE orders
      SET
        paid_at       = COALESCE(paid_at, delivered_at, updated_at),
        delivered_at  = COALESCE(delivered_at, paid_at, updated_at),
        balance_cents = 0,
        state         = 'delivered',
        updated_at    = NOW()
      WHERE state = 'paid';
    SQL
  end

  def down
    # Best-effort reverse: rows that have a `paid_at` but are in
    # `delivered` today could have been either (a) delivered-and-paid
    # (this migration) or (b) genuinely delivered-then-paid in the new
    # model. We can't distinguish, so `down` is a no-op rather than a
    # destructive restore.
    say "Skipping reverse — cannot distinguish migrated rows from new paid orders."
  end
end
