class Entitlements
  # Single source of truth for "what does this account's plan let her
  # do right now?" Every gated controller, view, component, and job
  # should read through `Entitlements.for(account).allows?(:feature)`
  # rather than checking `account.subscription` shapes directly. The
  # service collapses all the variation (paid Stripe, ongoing trial,
  # admin-donated comp, demo accounts) into a single boolean per
  # feature.
  #
  # The PLAN_FEATURES catalog below is the canonical free-vs-pro split
  # documented in ROADMAP.md Phase 14. Adding a new gated capability
  # means adding a key here AND wiring the relevant controller/view
  # to `entitlements.allows?(:that_key)`. There is no "soft-gate" tier
  # in the catalog — soft-gating (warnings, partial access) is a
  # rendering decision in the LockedComponent or HintBanner, not a
  # plan distinction.

  # Keys that every Free + Pro account can use unconditionally.
  # Listed for documentation: `Entitlements#allows?` returns true for
  # these regardless of plan.
  CORE_FEATURES = %i[
    storefront
    recipes
    clients
    orders
    kanban
    schedule
    suppliers
    purchases
    payment_instructions
    vacation_mode
    notifications
  ].to_set.freeze

  # Pro-only capabilities. The literal feature key is what
  # `entitlements.allows?(:composable_recipes)` tests against.
  PRO_ONLY_FEATURES = %i[
    composable_recipes
    finance_reports
    menu_engineering_reports
    fixed_costs
    recipe_customization
    inventory
    kds
    custom_domain
    hide_kitchef_branding
    priority_support
    unlimited_orders
    multi_photos
  ].to_set.freeze

  ALL_FEATURES = (CORE_FEATURES + PRO_ONLY_FEATURES).freeze

  # Numeric quotas keyed by tier. `nil` means unlimited. The Free
  # cap of 40 pedidos/mes is enforced by Slice 7's pre-warning + hard
  # block on `Storefronts::PlaceOrder`.
  TIER_LIMITS = {
    free: { monthly_orders_limit: 40 }.freeze,
    pro:  { monthly_orders_limit: nil }.freeze
  }.freeze

  PLAN_FEATURES = {
    free: { features: CORE_FEATURES, **TIER_LIMITS[:free] }.freeze,
    pro:  { features: ALL_FEATURES,  **TIER_LIMITS[:pro]  }.freeze
  }.freeze

  def self.for(account)
    new(account)
  end

  def initialize(account)
    @account = account
  end

  # True when this account's plan allows the named feature. Unknown
  # keys raise — every gate must reference a feature that exists, so
  # typos surface immediately rather than silently locking a surface.
  def allows?(feature)
    feature = feature.to_sym
    raise ArgumentError, "Unknown feature: #{feature.inspect}" unless ALL_FEATURES.include?(feature)
    plan_features.include?(feature)
  end

  # Numeric quota, or nil for unlimited. Mostly used by the
  # pedidos-remaining pill on `/orders`.
  def monthly_orders_limit
    PLAN_FEATURES[effective_tier][:monthly_orders_limit]
  end

  # True when there's no monthly limit (Pro tier).
  def unlimited_orders?
    monthly_orders_limit.nil?
  end

  def pro?
    effective_tier == :pro
  end

  def free?
    effective_tier == :free
  end

  # Where does the Pro entitlement come from? Reads through to the
  # subscription so callers can render "Pro · Cortesía" for comp
  # accounts vs "Pro · Mensual / Anual" for paying customers.
  def source
    return :free unless pro?
    account.subscription&.source&.to_sym || :free
  end

  private

  attr_reader :account

  def plan_features
    PLAN_FEATURES[effective_tier][:features]
  end

  def effective_tier
    account&.pro? ? :pro : :free
  end
end
