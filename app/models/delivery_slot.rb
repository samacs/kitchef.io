# == Schema Information
#
# Table name: delivery_slots
#
#  id          :bigint           not null, primary key
#  colonias    :jsonb            not null
#  day_of_week :integer          not null
#  end_time    :integer          not null
#  max_orders  :integer          default(10), not null
#  position    :integer
#  start_time  :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  idx_on_account_id_day_of_week_position_d8830b082a  (account_id,day_of_week,position)
#  index_delivery_slots_on_account_id                 (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class DeliverySlot < ApplicationRecord
  include AccountScoped
  positioned on: :account

  DAYS_OF_WEEK = (0..6).to_a.freeze

  validates :day_of_week, inclusion: { in: DAYS_OF_WEEK }
  validates :start_time, :end_time,
    presence: true,
    numericality: { only_integer: true, in: 0..TimeOfDay::MAX }
  validates :max_orders, numericality: { greater_than: 0 }
  validate  :end_time_after_start_time

  scope :for_day, ->(day_of_week) { where(day_of_week: day_of_week).order(:position) }

  # Display helpers — convert minutes-from-midnight to "HH:MM" strings.
  def start_time_hhmm = TimeOfDay.to_string(start_time)
  def end_time_hhmm   = TimeOfDay.to_string(end_time)

  def start_time_hhmm=(str)
    self.start_time = TimeOfDay.from_string(str)
  end

  def end_time_hhmm=(str)
    self.end_time = TimeOfDay.from_string(str)
  end

  def duration_minutes
    return nil if start_time.nil? || end_time.nil?

    end_time - start_time
  end

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time

    errors.add(:end_time, :after_start_time)
  end
end
