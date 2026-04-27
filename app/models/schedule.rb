# == Schema Information
#
# Table name: schedules
#
#  id                :bigint           not null, primary key
#  lead_time_minutes :integer          default(0), not null
#  order_mode        :integer          default("advance"), not null
#  vacation_message  :text
#  vacation_until    :date
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#
# Indexes
#
#  idx_schedules_vacation_until   (vacation_until) WHERE (vacation_until IS NOT NULL)
#  index_schedules_on_account_id  (account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
#   * `both` — both options live side-by-side in the checkout. A kitchen
#     that takes reservations for the weekend AND drop-ins at lunch.
class Schedule < ApplicationRecord
  include HasPrefixedId.new(prefix: "sch")

  ORDER_MODES = { advance: 0, same_day: 1, both: 2 }.freeze

  belongs_to :account, inverse_of: :schedule

  has_many :availabilities, dependent: :destroy, inverse_of: :schedule

  accepts_nested_attributes_for :availabilities,
    allow_destroy: true,
    reject_if:     :blank_availability?

  enum :order_mode, ORDER_MODES, prefix: true

  validates :lead_time_minutes,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :vacation_message, length: { maximum: 280 }, allow_blank: true
  validate  :vacation_until_not_in_the_past_on_set

  # --- Vacation mode (Phase 14, Slice 8) ---------------------------
  #
  # `vacation_until` is the inclusive last day of the pause. While
  # today is on or before that date, the storefront morphs to
  # "Volvemos pronto" + refuses checkout, and the operator's dashboard
  # surfaces a banner that the kitchen is paused. A daily cron clears
  # expired rows so the surface auto-recovers without operator action.
  def on_vacation?(date = Date.current)
    vacation_until.present? && vacation_until >= date
  end

  def vacation_resumes_on
    return nil unless vacation_until
    vacation_until + 1
  end

  # --- Lead time accessor ------------------------------------------
  #
  # The UI lets the operator enter lead time in HOURS because "720
  # minutos" is an impossible mental-math task. We keep the DB column
  # in minutes so future-fine-grained lead times (15, 30, 45 min) stay
  # possible without another migration — the conversion lives here.
  def lead_time_hours
    lead_time_minutes.to_i / 60
  end

  def lead_time_hours=(value)
    # Clamp to 30 days of notice — anything beyond that is almost
    # certainly a fat-finger and the storefront picker wouldn't surface
    # windows far enough out to be useful anyway.
    self.lead_time_minutes = (value.to_i * 60).clamp(0, 30 * 24 * 60)
  end

  # --- Convenience scopes used by the storefront picker -------------
  #
  # Recurring = weekly windows that fire every week on the matching wday.
  # Overrides = date-specific exceptions that supersede the recurring
  # window on that specific calendar day.
  def recurring_availabilities
    availabilities.where.not(wday: nil).order(:wday, :from_time)
  end

  def overrides_for(date)
    availabilities.where(date: date).order(:from_time)
  end

  def windows_for(date)
    overrides = overrides_for(date).to_a
    return overrides.select(&:available?) if overrides.any?

    # No override → fall back to the recurring weekly schedule. An override
    # with `available: false` IS still treated as "closed that day" because
    # the `.select(&:available?)` above filters it out.
    availabilities.where(wday: date.wday).order(:from_time).select(&:available?)
  end

  # True when the kitchen is open to take orders RIGHT NOW. Used by the
  # "Aceptando pedidos" chip on the storefront hero.
  def open_at?(moment)
    minutes = moment.hour * 60 + moment.min
    windows_for(moment.to_date).any? do |w|
      minutes >= w.from_time && minutes < w.to_time
    end
  end

  private

  # Nested-attributes helper: treat a row with neither wday nor date
  # (user clicked "add slot" and left both empty) as "nothing to save".
  # The XOR validation on Availability still catches explicit corruption.
  def blank_availability?(attrs)
    attrs["wday"].blank? && attrs["date"].blank?
  end

  # Reject only on CHANGE — existing rows whose vacation_until has
  # since become "today or yesterday" still pass through validation
  # so the auto-clear cron can do its job without bouncing on this
  # check. New / edited rows must set a future-or-today date.
  def vacation_until_not_in_the_past_on_set
    return unless will_save_change_to_vacation_until? && vacation_until.present?
    return if vacation_until >= Date.current
    errors.add(:vacation_until, :must_be_today_or_future)
  end
end
