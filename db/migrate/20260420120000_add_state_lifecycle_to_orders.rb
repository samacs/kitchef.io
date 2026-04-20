# Stamps per-state timestamps on Order + captures why a pedido was
# canceled so reports can answer "average time in production", "how long
# did Lupita wait between confirmed and ready", and "which cancellation
# reasons are eating margin" without parsing PaperTrail object_changes.
#
# AASM `after` callbacks populate these on transition (see Order#state).
# `placed_at` is just `created_at` — a brand-new pedido is placed by
# definition — so it doesn't need its own column.
class AddStateLifecycleToOrders < ActiveRecord::Migration[8.1]
  def change
    change_table :orders, bulk: true do |t|
      t.datetime :confirmed_at
      t.datetime :production_started_at
      t.datetime :ready_at
      t.datetime :delivered_at
      t.datetime :paid_at
      t.datetime :canceled_at

      # Preset code from Order::CANCEL_REASON_CODES. Always required when
      # state = canceled; Spanish label resolved via domain.yml.
      t.string :cancel_reason_code

      # Optional free-text note. Required when cancel_reason_code = "other".
      t.text :cancel_reason_note
    end

    add_index :orders, :canceled_at
  end
end
