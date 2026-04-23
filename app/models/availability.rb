# == Schema Information
#
# Table name: availabilities
#
#  id          :bigint           not null, primary key
#  available   :boolean          default(TRUE), not null
#  date        :date
#  from_time   :integer          not null
#  note        :string
#  to_time     :integer          not null
#  wday        :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  schedule_id :bigint           not null
#
# Indexes
#
#  index_availabilities_on_schedule_id           (schedule_id)
#  index_availabilities_on_schedule_id_and_date  (schedule_id,date) WHERE (date IS NOT NULL)
#  index_availabilities_on_schedule_id_and_wday  (schedule_id,wday) WHERE (wday IS NOT NULL)
#
# Foreign Keys
#
#  fk_rails_...  (schedule_id => schedules.id)
#
# The XOR invariant is enforced at the DB level (`chk_availabilities_wday_xor_date`)
# AND here in application code so the form layer can surface a field-level
# error before hitting the DB.
class Availability < ApplicationRecord
  belongs_to :schedule, inverse_of: :availabilities

  validates :from_time, :to_time,
    presence: true,
    numericality: { only_integer: true, in: 0..TimeOfDay::MAX }
  validates :wday, inclusion: { in: 0..6 }, allow_nil: true
  validate  :wday_xor_date
  validate  :from_time_before_to_time

  scope :recurring, -> { where.not(wday: nil) }
  scope :overrides, -> { where.not(date: nil) }
  scope :for_wday,  ->(wday) { where(wday: wday) }
  scope :for_date,  ->(date) { where(date: date) }
  scope :active,    -> { where(available: true) }

  # "HH:MM" accessors — match the pattern used on DeliverySlot + Order.
  def from_time_hhmm = TimeOfDay.to_string(from_time)
  def to_time_hhmm   = TimeOfDay.to_string(to_time)

  def from_time_hhmm=(str)
    self.from_time = TimeOfDay.from_string(str) if str.present?
  end

  def to_time_hhmm=(str)
    self.to_time = TimeOfDay.from_string(str) if str.present?
  end

  def recurring? = wday.present?
  def override?  = date.present?

  private

  def wday_xor_date
    if wday.present? && date.present?
      errors.add(:base, :wday_and_date_exclusive)
    elsif wday.blank? && date.blank?
      errors.add(:base, :wday_or_date_required)
    end
  end

  def from_time_before_to_time
    return if from_time.blank? || to_time.blank?
    return if to_time > from_time

    errors.add(:to_time, :must_be_after_from_time)
  end
end
