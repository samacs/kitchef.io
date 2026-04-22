class AddCapacityToDeliverySlots < ActiveRecord::Migration[8.1]
  def change
    # Nullable integer — nil = unlimited, >0 = cap. v1 is display-only:
    # we don't gate storefront submissions on fill level, so there's no
    # backfill from `max_orders` either. Operators set capacity as they
    # learn their real ceiling; `max_orders` (non-null, default 10) stays
    # as a legacy column for now.
    add_column :delivery_slots, :capacity, :integer
  end
end
