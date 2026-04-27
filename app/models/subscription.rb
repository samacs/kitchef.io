# == Schema Information
#
# Table name: subscriptions
#
#  id                     :bigint           not null, primary key
#  cancel_at_period_end   :boolean          default(FALSE), not null
#  comp_expires_at        :datetime
#  comp_reason            :text
#  current_period_end     :datetime
#  plan                   :integer          default("free"), not null
#  source                 :integer          default(0), not null
#  status                 :integer          default("trialing"), not null
#  trial_ends_at          :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  comp_granted_by_id     :bigint
#  stripe_customer_id     :string
#  stripe_subscription_id :string
#
# Indexes
#
#  idx_subscriptions_comp_expires_at              (comp_expires_at) WHERE (comp_expires_at IS NOT NULL)
#  index_subscriptions_on_account_id              (account_id) UNIQUE
#  index_subscriptions_on_comp_granted_by_id      (comp_granted_by_id)
#  index_subscriptions_on_source                  (source)
#  index_subscriptions_on_stripe_customer_id      (stripe_customer_id) UNIQUE WHERE (stripe_customer_id IS NOT NULL)
#  index_subscriptions_on_stripe_subscription_id  (stripe_subscription_id) UNIQUE WHERE (stripe_subscription_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (comp_granted_by_id => users.id) ON DELETE => nullify
#
class Subscription < ApplicationRecord
  # Two-tier product: a free entry point and a single paid plan,
  # billed monthly OR yearly. Internal keys are English (`free`,
  # `pro_monthly`, `pro_yearly`); operator-facing labels are rendered
  # via I18n under `t("subscription.plans.*")` so copy tweaks don't
  # need a deploy. The legacy `pro` value (1) stays in the enum as a
  # compatibility shim for any in-flight rows from before Phase 14;
  # `Entitlements` treats it as Pro identically to `pro_monthly`.
  PLANS = {
    free:        0,   # "Gratis"        — entry tier, 40 pedidos/mes
    pro:         1,   # legacy alias    — pre-Phase-14 rows, treated as Pro
    pro_monthly: 2,   # "Pro · Mensual" — $199 MXN/mes
    pro_yearly:  3    # "Pro · Anual"   — $1,990 MXN/año (2 meses gratis)
  }.freeze

  STATUSES = {
    trialing:    0,
    active:      1,
    past_due:    2,
    canceled:    3,
    incomplete:  4,
    paused:      5,   # Stripe pause_collection (vacation pause from save flow)
    ended:       6    # period closed out, no renewal
  }.freeze

  # Where this account's Pro entitlement comes from. `:free` means no
  # entitlement (Free tier). `:stripe` is a paying customer (active
  # subscription, possibly trialing). `:comp` is an admin-donated
  # grant (demo accounts, partner deals, founder cocineras).
  SOURCES = {
    free:   0,
    stripe: 1,
    comp:   2
  }.freeze

  PRO_PLAN_KEYS = %w[pro pro_monthly pro_yearly].freeze

  enum :plan,   PLANS,    prefix: true
  enum :status, STATUSES, prefix: true
  enum :source, SOURCES,  prefix: true

  belongs_to :account
  belongs_to :comp_granted_by,
             class_name:  "User",
             optional:    true,
             foreign_key: :comp_granted_by_id

  has_paper_trail

  validates :account_id, uniqueness: true
  validates :plan,       presence: true
  validates :status,     presence: true
  validates :source,     presence: true
  validate  :comp_fields_consistent_with_source

  def on_trial?
    status_trialing? && trial_ends_at&.future?
  end

  def active?
    status_active? || on_trial?
  end

  # Single read every gated surface relies on. True when the account
  # is entitled to Pro features RIGHT NOW, regardless of how the
  # entitlement was granted (paid Stripe subscription, ongoing trial,
  # or unexpired comp). The `Entitlements` service reads this and
  # never branches on `source` — every gated feature treats comp-Pro
  # identically to paid-Pro.
  def pro?
    case source
    when "stripe" then stripe_pro?
    when "comp"   then comp_active?
    else               false
    end
  end

  def comp_active?
    return false unless source_comp?
    comp_expires_at.nil? || comp_expires_at.future?
  end

  def stripe_pro?
    return false unless source_stripe?
    return false unless active?
    PRO_PLAN_KEYS.include?(plan)
  end

  private

  # Comp fields and source must agree. Stripe / Free rows shouldn't
  # carry a stray `comp_granted_by_id`; comp rows must have one.
  def comp_fields_consistent_with_source
    if source_comp?
      errors.add(:comp_granted_by_id, :required) if comp_granted_by_id.blank?
    elsif comp_granted_by_id.present? || comp_reason.present? || comp_expires_at.present?
      errors.add(:source, :inconsistent_with_comp_fields)
    end
  end
end
