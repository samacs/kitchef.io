# Minutes-from-midnight scheduling helpers.
#
# DeliverySlot and Order store time-of-day as integer minutes (0..1440)
# rather than Postgres `time` or `datetime`. This avoids timezone/DST
# drift for recurring schedules and keeps range queries trivial:
#
#   WHERE start_time <= ? AND end_time > ?
#
# Use this module for conversion between the integer storage format and
# user-facing strings.
module TimeOfDay
  MAX = 24 * 60

  # "09:30" → 570
  def self.from_string(str)
    return nil if str.blank?
    hour, minute = str.to_s.split(":").map(&:to_i)
    raise ArgumentError, "invalid time: #{str.inspect}" unless hour.between?(0, 24) && minute.between?(0, 59)

    total = hour * 60 + minute
    raise ArgumentError, "out of range: #{str.inspect}" if total > MAX

    total
  end

  # 570 → "09:30"
  def self.to_string(minutes)
    return nil if minutes.nil?
    raise ArgumentError, "out of range: #{minutes}" unless minutes.between?(0, MAX)

    format("%02d:%02d", minutes / 60, minutes % 60)
  end
end
