module Schedules
  # Daily sweep that clears `vacation_until` from any Schedule whose
  # pause window has already ended (vacation_until < today). Runs via
  # sidekiq-cron at 03:00 server time so the storefront auto-recovers
  # before the operator wakes up. The validation on `Schedule` allows
  # legacy past dates to pass — meaning this job can clear them
  # without bouncing on the "must be today or future" check.
  class ClearExpiredVacationsJob < ApplicationJob
    queue_as :low

    def perform
      Schedule
        .where.not(vacation_until: nil)
        .where("vacation_until < ?", Date.current)
        .find_each do |schedule|
          schedule.update_columns(vacation_until: nil, vacation_message: nil)
        end
    end
  end
end
