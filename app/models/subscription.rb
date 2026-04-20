# == Schema Information
#
# Table name: subscriptions
#
#  id                     :bigint           not null, primary key
#  cancel_at_period_end   :boolean          default(FALSE), not null
#  current_period_end     :datetime
#  plan                   :integer          default("free"), not null
#  status                 :integer          default("trialing"), not null
#  trial_ends_at          :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  stripe_customer_id     :string
#  stripe_subscription_id :string
#
# Indexes
#
#  index_subscriptions_on_account_id              (account_id) UNIQUE
#  index_subscriptions_on_stripe_customer_id      (stripe_customer_id) UNIQUE WHERE (stripe_customer_id IS NOT NULL)
#  index_subscriptions_on_stripe_subscription_id  (stripe_subscription_id) UNIQUE WHERE (stripe_subscription_id IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class Subscription < ApplicationRecord
  # Two-tier product: a free entry point and a single paid plan.
  # Internal keys are English (`free`, `pro`); operator-facing labels
  # ("Gratis" / "Pro") are rendered via I18n under
  # `t("subscription.plans.*")` so copy tweaks don't need a deploy.
  PLANS = {
    free: 0,   # "Gratis" — entry tier, capped pedidos/month
    pro:  1    # "Pro"    — $150 MXN/mes, uncapped
  }.freeze

  STATUSES = {
    trialing:    0,
    active:      1,
    past_due:    2,
    canceled:    3,
    incomplete:  4
  }.freeze

  enum :plan,   PLANS,    prefix: true
  enum :status, STATUSES, prefix: true

  belongs_to :account

  validates :account_id, uniqueness: true
  validates :plan,       presence: true
  validates :status,     presence: true

  def on_trial?
    status_trialing? && trial_ends_at&.future?
  end

  def active?
    status_active? || on_trial?
  end
end
