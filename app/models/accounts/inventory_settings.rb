module Accounts
  # Per-account toggles for the optional inventory + production-runs
  # surface (Phase 13). When `enabled` is false the operator app behaves
  # exactly like Phase 12 — no production page, no menu stock badges, no
  # ingredient on-hand columns. Flipping it to true is reversible at any
  # time; the underlying tables exist regardless.
  #
  # Defaults are deliberately conservative: a brand-new operator should
  # not have to think about inventory for her first three weeks. She
  # opts in via /account/edit when she's ready.
  class InventorySettings
    include StoreModel::Model

    OVERSELL_POLICIES = %w[warn block].freeze

    # Master switch. Off by default for every account. The operator opts
    # in from /account/edit; flipping this redirects her to the
    # /production/onboarding primer.
    attribute :enabled, :boolean, default: false

    # When the storefront menu surface a recipe whose runs are exhausted
    # for the customer's selected delivery date:
    #   - `warn`  (default) — order proceeds, kanban chip flags it
    #   - `block` — add-to-cart disables, checkout submit is rejected
    # `waitlist` is reserved for Phase 13.5.
    attribute :oversell_policy, :string, default: "warn"

    # Highlight an ingredient in the list when its on-hand quantity is
    # below this percentage of its last-purchase quantity. 20% is the
    # opinionated default — operators with chunkier weekly purchases will
    # tighten this; operators with daily mercado runs will loosen it.
    attribute :low_stock_threshold_pct, :integer, default: 20

    # Default availability window for a brand-new production run. A
    # value of 1 means "available today + tomorrow" — the typical home-
    # cook batch lifespan. Operators with shorter shelf life (helado,
    # mariscos) drop this to 0; bakery operators bump it to 2-3.
    attribute :default_run_window_days, :integer, default: 1

    # Stamps the moment the operator first flipped `enabled` on. Drives
    # the "show onboarding once" gate in Production::OnboardingController
    # and lets us tell first-week operators apart from veterans in
    # support conversations.
    attribute :enabled_at, :datetime

    validates :oversell_policy, inclusion: { in: OVERSELL_POLICIES, allow_nil: true }
    validates :low_stock_threshold_pct,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
      allow_nil: true
    validates :default_run_window_days,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 14 },
      allow_nil: true

    def block_oversells?
      oversell_policy.to_s == "block"
    end

    def warn_oversells?
      oversell_policy.to_s == "warn"
    end
  end
end
