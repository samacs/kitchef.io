module Accounts
  # Per-account feature flags and behavioral preferences, persisted as a
  # JSONB column on accounts.settings and typed via the `store_model` gem.
  #
  # Each attribute has a default so existing accounts pick up new flags
  # without a migration.
  class Settings
    include StoreModel::Model

    # Composable recipes — see TRD §6. Operators start in simple mode (flat
    # recipes with name/price/photo). The flag flips to true either (a)
    # when Onboarding::CompleteFirstDecomposition runs, or (b) when the
    # operator opts into advanced mode during signup.
    attribute :use_composable_recipes,          :boolean, default: false
    attribute :composable_recipes_unlocked_at,  :datetime

    # Daily operations digest — sent each morning by a Sidekiq cron job.
    attribute :digest_enabled, :boolean, default: true
    attribute :digest_time,    :string,  default: "07:00"

    # Per-order email notifications to the operator when a storefront
    # order lands. Default-on; opt-out only. No UI yet — toggled via
    # console for the handful of operators who ask.
    attribute :notify_new_orders, :boolean, default: true

    # Onboarding state.
    attribute :onboarding_completed,              :boolean, default: false
    attribute :onboarding_advanced_mode_choice,   :string   # "yes" | "no" | "skip"

    # Dashboard affordances for newer operators — dismissed after first week.
    attribute :show_cost_hints, :boolean, default: true

    # Phase 10 — per-pedido packaging baseline. Hydrated onto every new
    # Order at place/update time so the cost sits in the variable bucket
    # with ingredientes instead of disappearing into "margen bruto" math.
    # Override per-pedido in the order drawer.
    attribute :default_packaging_cents, :integer, default: 0

    validates :digest_time,
      format: { with: /\A([01]\d|2[0-3]):[0-5]\d\z/ },
      allow_nil: true

    validates :onboarding_advanced_mode_choice,
      inclusion: { in: %w[yes no skip], allow_nil: true }

    validates :default_packaging_cents,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 },
      allow_nil: true
  end
end
