# == Schema Information
#
# Table name: orders
#
#  id                      :bigint           not null, primary key
#  balance_cents           :bigint           default(0), not null
#  cancel_reason_code      :string
#  cancel_reason_note      :text
#  canceled_at             :datetime
#  city                    :string
#  colonia                 :string
#  confirmed_at            :datetime
#  delivered_at            :datetime
#  delivery_address        :string
#  delivery_date           :date             not null
#  delivery_end_time       :integer
#  delivery_notes          :text
#  delivery_start_time     :integer
#  delivery_type           :integer          default("delivery"), not null
#  deposit_cents           :bigint           default(0), not null
#  discarded_at            :datetime
#  en_route_started_at     :datetime
#  geocoded_at             :datetime
#  geocoding_failed_at     :datetime
#  latitude                :decimal(10, 6)
#  longitude               :decimal(10, 6)
#  notes                   :text
#  paid_at                 :datetime
#  pickup_reminder_sent_at :datetime
#  position                :integer
#  production_started_at   :datetime
#  ready_at                :datetime
#  source                  :integer          default("storefront"), not null
#  state                   :string           default("placed"), not null
#  subtotal_cents          :bigint           default(0), not null
#  tax_cents               :bigint           default(0), not null
#  total_cents             :bigint           default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  client_id               :bigint
#
# Indexes
#
#  idx_orders_pickup_reminder_pending                 (ready_at) WHERE (((state)::text = 'ready'::text) AND (delivery_type = 1) AND (pickup_reminder_sent_at IS NULL))
#  index_orders_on_account_id                         (account_id)
#  index_orders_on_account_id_and_delivery_date       (account_id,delivery_date)
#  index_orders_on_account_id_and_state_and_position  (account_id,state,position)
#  index_orders_on_canceled_at                        (canceled_at)
#  index_orders_on_client_id                          (client_id)
#  index_orders_on_discarded_at                       (discarded_at)
#  index_orders_on_latitude_and_longitude             (latitude,longitude)
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

  # Preset cancellation reasons. Codes are English identifiers; Spanish
  # labels live under `t("order.cancel_reasons.*")` in domain.yml. "other"
  # unlocks the free-text note and requires it to be filled.
  CANCEL_REASON_CODES = %w[
    client_canceled
    didnt_confirm
    out_of_stock
    delivery_issue
    other
  ].freeze

  # Terminal fulfillment states. `delivered` is the end of the
  # fulfillment axis (handoff is complete); payment is a separate
  # property tracked via `paid_at` and the `payments` association, so
  # it never becomes a state here.
  TERMINAL_STATES = %w[delivered canceled].freeze

  enum :delivery_type, DELIVERY_TYPES, prefix: true
  enum :source,        SOURCES,        prefix: true

  belongs_to :client, optional: true
  has_many :items,    class_name: "OrderItem", dependent: :destroy, inverse_of: :order
  has_many :payments, dependent: :destroy

  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  # Operator kanban — refreshes every open dashboard tab for this account
  # when any order in it mutates.
  broadcasts_refreshes_to ->(order) { [ order.account, :orders ] }

  # Customer-facing per-order stream — the storefront confirmation page
  # subscribes to this narrower channel so the customer sees state
  # changes (Pedido → Confirmado → En producción → Listo → En camino →
  # Entregado) morph live without also receiving unrelated orders from
  # the same kitchen. Privacy + bandwidth.
  broadcasts_refreshes_to ->(order) { [ order, :status ] }

  before_save :recompute_totals

  validates :delivery_date, presence: true
  validates :subtotal_cents, :total_cents, :deposit_cents, :balance_cents,
    numericality: { greater_than_or_equal_to: 0 }
  validates :delivery_start_time, :delivery_end_time,
    numericality: { only_integer: true, in: 0..TimeOfDay::MAX },
    allow_nil: true
  validates :delivery_address, presence: true, if: :delivery_type_delivery?
  validate :delivery_end_time_after_start_time
  validate :cancellation_reason_is_complete

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
    state :en_route
    state :delivered
    state :canceled

    # `after` callbacks stamp the matching lifecycle column so duration
    # reports (time-in-production, avg-time-to-deliver) are a single
    # SQL subtraction away. PaperTrail keeps the forensic trail.
    event :confirm, after: :stamp_confirmed_at do
      transitions from: :placed, to: :confirmed
    end

    event :start_production, after: :stamp_production_started_at do
      transitions from: :confirmed, to: :in_production
    end

    event :mark_ready, after: :stamp_ready_at do
      transitions from: :in_production, to: :ready
    end

    # `ship` is guarded to delivery-type only — pickup pedidos stay in
    # `ready` until the customer walks in (they skip `en_route`). If an
    # operator wants to mark a pickup as "in transit" anyway, they can
    # do it in a console; the UI won't surface the button.
    event :ship, after: :stamp_en_route_started_at do
      transitions from: :ready, to: :en_route, guard: :delivery?
    end

    event :deliver, after: :stamp_delivered_at do
      transitions from: %i[ready en_route], to: :delivered
    end

    event :cancel, after: :stamp_canceled_at do
      transitions from: %i[placed confirmed in_production ready en_route], to: :canceled
    end
  end

  # Payment. Deliberately NOT an AASM event — capturing payment is a
  # separate axis from fulfillment (a customer can pay on order, on
  # delivery, or days later with a transfer receipt). `mark_paid!`
  # stamps `paid_at` + zeros out the balance; `unmark_paid!` undoes a
  # mis-stamp. Both are idempotent and safe from any state except
  # `canceled`.
  def mark_paid!
    return false if canceled?
    return true  if paid?

    update!(paid_at: Time.current, balance_cents: 0)
  end

  def unmark_paid!
    return true unless paid?

    update!(paid_at: nil, balance_cents: [ total_cents - deposit_cents, 0 ].max)
  end

  def paid?
    paid_at.present?
  end

  # AASM guard — ship makes no semantic sense for pickup pedidos (the
  # customer walks in at `ready`), so `ready.may_fire_event?(:ship)`
  # returns false on pickup pedidos and the primary-button helper falls
  # through to `:deliver` for them.
  def delivery? = delivery_type_delivery?
  def pickup?   = delivery_type_pickup?

  # Geocoding helpers. Only delivery-type pedidos with a usable address
  # participate — pickup orders never need a runner-facing map, shipping
  # orders are routed by the courier (DiDi/Rappi/Estafeta), and an order
  # without any street detail would just geocode to a broad city centroid
  # (misleading for the runner's directions).
  def geocoding_address
    parts = [ delivery_address, colonia, city ].compact_blank
    return nil if parts.empty?

    (parts + [ "México" ]).join(", ")
  end

  def geocoded?
    latitude.present? && longitude.present?
  end

  def needs_geocoding?
    delivery? && !canceled? && geocoding_address.present? && !geocoded?
  end

  # Scope used by `PickupReminderScanJob` — pickup pedidos in `ready`
  # whose `ready_at` timestamp is older than `cutoff_time` and that have
  # not already been pinged. The scan is cheap because the partial index
  # `idx_orders_pickup_reminder_pending` backs this exact predicate.
  scope :awaiting_pickup_reminder, ->(cutoff_time) {
    where(state: "ready", delivery_type: DELIVERY_TYPES[:pickup], pickup_reminder_sent_at: nil)
      .where("ready_at < ?", cutoff_time)
  }

  # Cooldown between failed attempts so GeocodeOrderJob doesn't hammer
  # Google on a permanently-bad address. After the cooldown the job
  # can retry (e.g. the operator fixed a typo).
  GEOCODING_RETRY_COOLDOWN = 1.hour

  def geocoding_on_cooldown?
    return false if geocoding_failed_at.blank?

    geocoding_failed_at > GEOCODING_RETRY_COOLDOWN.ago
  end

  def canceled?
    state == "canceled"
  end

  # Delivered + canceled pedidos are read-only to preserve the audit
  # trail and reporting integrity — fulfillment has run its course and
  # the operator recovers any edit need by duplicating into a fresh
  # draft. Payment state is orthogonal; `paid?` does NOT gate edits.
  def immutable?
    TERMINAL_STATES.include?(state)
  end

  def balance
    Money.new(total_cents - deposit_cents - payments.sum(:amount_cents), "MXN")
  end

  # Duration helpers. Each returns a Float of seconds between two
  # lifecycle timestamps, or nil when either end is missing. Designed
  # for reporting queries (`orders.average(&:time_in_production)`);
  # finance/menu-engineering views will wrap these in aggregates.
  def time_to_confirm          = duration(created_at, confirmed_at)
  def time_in_production       = duration(production_started_at, ready_at)
  def time_waiting_for_runner  = duration(ready_at, en_route_started_at)
  def time_in_transit          = duration(en_route_started_at, delivered_at)
  def time_to_deliver          = duration(ready_at, delivered_at)
  def time_to_pay              = duration(delivered_at, paid_at)
  def fulfillment_time         = duration(created_at, delivered_at || paid_at)
  def time_to_cancel           = duration(created_at, canceled_at)

  private

  def recompute_totals
    subtotal = items.reject(&:marked_for_destruction?).sum do |item|
      (item.unit_price_cents.to_i * item.quantity.to_d).to_i
    end
    self.subtotal_cents = subtotal
    self.tax_cents      = 0
    self.total_cents    = subtotal
    self.balance_cents  = [ total_cents - deposit_cents.to_i, 0 ].max
  end

  def delivery_end_time_after_start_time
    return if delivery_start_time.blank? || delivery_end_time.blank?
    return if delivery_end_time > delivery_start_time

    errors.add(:delivery_end_time, :after_start_time)
  end

  def cancellation_reason_is_complete
    return unless canceled?
    if cancel_reason_code.blank?
      errors.add(:cancel_reason_code, :blank)
    elsif !CANCEL_REASON_CODES.include?(cancel_reason_code)
      errors.add(:cancel_reason_code, :invalid)
    elsif cancel_reason_code == "other" && cancel_reason_note.blank?
      errors.add(:cancel_reason_note, :blank)
    end
  end

  # AASM after-transition stampers. Using update_columns skips the
  # recompute_totals before_save + validations — the transition itself
  # has already been validated by AASM. Guarded: only write when nil so
  # a manual backfill (console work, history import) isn't clobbered.
  def stamp_confirmed_at          = stamp(:confirmed_at)
  def stamp_production_started_at = stamp(:production_started_at)
  def stamp_ready_at              = stamp(:ready_at)
  def stamp_en_route_started_at   = stamp(:en_route_started_at)
  def stamp_delivered_at          = stamp(:delivered_at)
  def stamp_paid_at               = stamp(:paid_at)
  def stamp_canceled_at           = stamp(:canceled_at)

  def stamp(column)
    return if self[column].present?
    update_column(column, Time.current)
  end

  def duration(start_time, end_time)
    return nil if start_time.blank? || end_time.blank?
    end_time - start_time
  end
end
