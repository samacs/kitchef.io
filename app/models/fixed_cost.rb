# == Schema Information
#
# Table name: fixed_costs
#
#  id                     :bigint           not null, primary key
#  amount_cents           :bigint           default(0), not null
#  cost_per_pedido_cents  :bigint
#  currency               :string           default("MXN"), not null
#  discarded_at           :datetime
#  end_date               :date
#  notes                  :text
#  recurrence             :integer          default("monthly"), not null
#  start_date             :date             not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  fixed_cost_category_id :bigint           not null
#
# Indexes
#
#  index_fixed_costs_on_account_id                 (account_id)
#  index_fixed_costs_on_account_id_and_start_date  (account_id,start_date)
#  index_fixed_costs_on_discarded_at               (discarded_at)
#  index_fixed_costs_on_fixed_cost_category_id     (fixed_cost_category_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (fixed_cost_category_id => fixed_cost_categories.id)
#
class FixedCost < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "fc")
  include HasSoftDelete

  has_paper_trail

  RECURRENCES = { monthly: 0, weekly: 1, yearly: 2, one_time: 99 }.freeze

  enum :recurrence, RECURRENCES, prefix: true

  belongs_to :fixed_cost_category

  monetize :amount_cents
  monetize :cost_per_pedido_cents, as: :cost_per_pedido, allow_nil: true

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :start_date, presence: true
  validate  :end_date_after_start_date
  validate  :category_belongs_to_same_account

  scope :active_on, ->(date) {
    where("start_date <= ?", date).where("end_date IS NULL OR end_date >= ?", date)
  }
  scope :overlapping, ->(from, to) {
    where("start_date <= ?", to).where("end_date IS NULL OR end_date >= ?", from)
  }
  scope :per_pedido,    -> { where.not(cost_per_pedido_cents: nil) }
  scope :prorated,      -> { where(cost_per_pedido_cents: nil) }

  def per_pedido?
    cost_per_pedido_cents.present?
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?
    return if end_date >= start_date
    errors.add(:end_date, :after_start_date)
  end

  def category_belongs_to_same_account
    return if fixed_cost_category.blank? || account_id.blank?
    return if fixed_cost_category.account_id == account_id
    errors.add(:fixed_cost_category, :wrong_account)
  end
end
