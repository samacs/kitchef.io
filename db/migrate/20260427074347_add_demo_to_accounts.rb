class AddDemoToAccounts < ActiveRecord::Migration[8.1]
  # Phase 14, Slice 1.
  #
  # `demo` flags accounts whose side effects (mail, WhatsApp, Stripe,
  # geocoding, push-style notifications) should be silently skipped
  # at the service-boundary layer. The single shared public demo
  # account (`kitchef.mx/cocina-demo`) flips this on; admin tooling
  # in Slice 10 lets us mark any account demo for ad-hoc
  # demonstrations.
  def change
    add_column :accounts, :demo, :boolean, default: false, null: false
    add_index  :accounts, :demo,
               where: "demo = true",
               name:  "idx_accounts_demo_true"
  end
end
