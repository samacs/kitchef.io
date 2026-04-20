class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :account, null: false, foreign_key: true, index: { unique: true }

      t.string :stripe_customer_id
      t.string :stripe_subscription_id

      t.integer :plan,   null: false, default: 0  # enum
      t.integer :status, null: false, default: 0  # enum

      t.datetime :trial_ends_at
      t.datetime :current_period_end
      t.boolean  :cancel_at_period_end, null: false, default: false

      t.timestamps
    end

    add_index :subscriptions, :stripe_customer_id, unique: true, where: "stripe_customer_id IS NOT NULL"
    add_index :subscriptions, :stripe_subscription_id, unique: true, where: "stripe_subscription_id IS NOT NULL"
  end
end
