# == Schema Information
#
# Table name: batches
#
#  id               :bigint           not null, primary key
#  actual_quantity  :decimal(12, 3)   default(0.0), not null
#  available_from   :date             not null
#  available_until  :date             not null
#  canceled_at      :datetime
#  completed_at     :datetime
#  cooked_on        :date             not null
#  discarded_at     :datetime
#  notes            :text
#  planned_quantity :decimal(12, 3)   default(0.0), not null
#  started_at       :datetime
#  state            :string           default("planned"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  recipe_id        :bigint           not null
#
# Indexes
#
#  idx_batches_account_window                               (account_id,available_from,available_until)
#  index_batches_on_account_id                              (account_id)
#  index_batches_on_account_id_and_cooked_on                (account_id,cooked_on)
#  index_batches_on_account_id_and_recipe_id_and_cooked_on  (account_id,recipe_id,cooked_on)
#  index_batches_on_discarded_at                            (discarded_at)
#  index_batches_on_recipe_id                               (recipe_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (recipe_id => recipes.id)
#
class Batch < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "btc")
  include HasSoftDelete

  include AASM
  has_paper_trail

  STATES = %w[planned in_progress completed canceled].freeze

  belongs_to :recipe

  has_many :consumptions,
    class_name: "BatchConsumption",
    dependent: :destroy,
    inverse_of: :batch
  has_many :order_items,
    foreign_key: :consumed_batch_id,
    dependent: :nullify,
    inverse_of: :consumed_batch

  validates :cooked_on, :available_from, :available_until, presence: true
  validates :planned_quantity, numericality: { greater_than: 0 }
  validates :actual_quantity,  numericality: { greater_than_or_equal_to: 0 }
  validate  :available_window_in_order
  validate  :recipe_belongs_to_account

  scope :for_date,    ->(date) { where(cooked_on: date) }
  scope :for_week,    ->(start_on) { where(cooked_on: start_on..start_on + 6.days) }
  scope :active,      -> { kept.where.not(state: "canceled") }
  scope :available_on, ->(date) {
    active.where("available_from <= ? AND available_until >= ?", date, date)
  }

  # AASM lifecycle. Mirrors Order's English-key approach; Spanish labels
  # for state badges live under `batches.state.*` in panels.yml.
  aasm column: :state, whiny_transitions: false do
    state :planned, initial: true
    state :in_progress
    state :completed
    state :canceled

    event :start, after: :stamp_started_at do
      transitions from: :planned, to: :in_progress
    end

    event :complete, after: :stamp_completed_at do
      transitions from: %i[planned in_progress], to: :completed
    end

    event :cancel, after: :stamp_canceled_at do
      transitions from: %i[planned in_progress completed], to: :canceled
    end
  end

  # Units actually available for sale right now. Subtracts everything
  # that's been consumed by orders from `actual_quantity`. Negative
  # values are clamped to zero in the UI but preserved in the DB so an
  # operator can see how oversold she got.
  def units_remaining
    consumed = order_items.where.not(order_id: nil).sum(:consumed_quantity).to_d
    actual_quantity.to_d - consumed
  end

  def units_consumed
    order_items.sum(:consumed_quantity).to_d
  end

  # True when this batch can fulfill an order on `date`. Cancelled
  # batches never qualify; future batches (cooked_on > date) qualify
  # too as long as their available window covers `date`.
  def available_for?(date)
    return false if canceled?
    available_from <= date && available_until >= date
  end

  def out_of_stock?
    units_remaining <= 0
  end

  private

  def available_window_in_order
    return if available_from.blank? || available_until.blank?
    return if available_until >= available_from
    errors.add(:available_until, :before_available_from)
  end

  def recipe_belongs_to_account
    return if recipe.blank? || account_id.blank?
    return if recipe.account_id == account_id
    errors.add(:recipe, :wrong_account)
  end

  def stamp_started_at
    update_column(:started_at, Time.current) if started_at.blank?
  end

  def stamp_completed_at
    update_column(:completed_at, Time.current) if completed_at.blank?
  end

  def stamp_canceled_at
    update_column(:canceled_at, Time.current) if canceled_at.blank?
  end
end
