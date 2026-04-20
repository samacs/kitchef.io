# == Schema Information
#
# Table name: orders
#
#  id                  :bigint           not null, primary key
#  balance_cents       :bigint           default(0), not null
#  city                :string
#  colonia             :string
#  delivery_address    :string
#  delivery_date       :date             not null
#  delivery_end_time   :integer
#  delivery_notes      :text
#  delivery_start_time :integer
#  delivery_type       :integer          default("delivery"), not null
#  deposit_cents       :bigint           default(0), not null
#  discarded_at        :datetime
#  notes               :text
#  position            :integer
#  source              :integer          default("storefront"), not null
#  state               :string           default("placed"), not null
#  subtotal_cents      :bigint           default(0), not null
#  tax_cents           :bigint           default(0), not null
#  total_cents         :bigint           default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  client_id           :bigint
#
# Indexes
#
#  index_orders_on_account_id                         (account_id)
#  index_orders_on_account_id_and_delivery_date       (account_id,delivery_date)
#  index_orders_on_account_id_and_state_and_position  (account_id,state,position)
#  index_orders_on_client_id                          (client_id)
#  index_orders_on_discarded_at                       (discarded_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (client_id => clients.id)
#
class Order < ApplicationRecord
  include AccountScoped
  include HasPrefixedId.new(prefix: "ord")
  include HasSoftDelete

  include AASM
  has_paper_trail
  positioned on: [ :account, :state ]

  monetize :subtotal_cents
  monetize :tax_cents
  monetize :total_cents
  monetize :deposit_cents
  monetize :balance_cents

  DELIVERY_TYPES = { delivery: 0, pickup: 1 }.freeze
  SOURCES        = {
    storefront: 0,
    manual:     1,
    whatsapp:   2,
    instagram:  3,
    other:     99
  }.freeze

  enum :delivery_type, DELIVERY_TYPES, prefix: true
  enum :source,        SOURCES,        prefix: true

  belongs_to :client, optional: true
  has_many :items,    class_name: "OrderItem", dependent: :destroy, inverse_of: :order
  has_many :payments, dependent: :destroy

  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  validates :delivery_date, presence: true
  validates :subtotal_cents, :total_cents, :deposit_cents, :balance_cents,
    numericality: { greater_than_or_equal_to: 0 }
  validates :delivery_start_time, :delivery_end_time,
    numericality: { only_integer: true, in: 0..TimeOfDay::MAX },
    allow_nil: true
  validate :delivery_end_time_after_start_time

  # "11:00"/"12:00" accessors — map to the underlying integer columns.
  def delivery_start_time_hhmm = TimeOfDay.to_string(delivery_start_time)
  def delivery_end_time_hhmm   = TimeOfDay.to_string(delivery_end_time)

  def delivery_start_time_hhmm=(str)
    self.delivery_start_time = TimeOfDay.from_string(str)
  end

  def delivery_end_time_hhmm=(str)
    self.delivery_end_time = TimeOfDay.from_string(str)
  end

  scope :for_week, ->(start_on) { where(delivery_date: start_on..start_on + 6.days) }

  # AASM state machine. State identifiers are English; operator-facing
  # labels live under `t("order.state.*")` in the es-MX locale.
  # `column: :state` is a string; enum usage here would conflict with AASM's
  # own persistence.
  aasm column: :state, whiny_transitions: false do
    state :placed, initial: true
    state :confirmed
    state :in_production
    state :ready
    state :delivered
    state :paid
    state :canceled

    event :confirm do
      transitions from: :placed, to: :confirmed
    end

    event :start_production do
      transitions from: :confirmed, to: :in_production
    end

    event :mark_ready do
      transitions from: :in_production, to: :ready
    end

    event :deliver do
      transitions from: :ready, to: :delivered
    end

    event :mark_paid do
      transitions from: %i[delivered ready in_production confirmed], to: :paid
    end

    event :cancel do
      transitions from: %i[placed confirmed in_production ready], to: :canceled
    end
  end

  def paid?
    state == "paid"
  end

  def balance
    Money.new(total_cents - deposit_cents - payments.sum(:amount_cents), "MXN")
  end

  private

  def delivery_end_time_after_start_time
    return if delivery_start_time.blank? || delivery_end_time.blank?
    return if delivery_end_time > delivery_start_time

    errors.add(:delivery_end_time, :after_start_time)
  end
end
