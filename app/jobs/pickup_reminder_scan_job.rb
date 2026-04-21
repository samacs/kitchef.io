# Cron-driven scan for pickup pedidos that have overstayed the operator's
# pickup_reminder_hours threshold. Runs every 15 minutes (see
# config/schedule.yml). Each account's threshold lives on
# `public_profile.pickup_reminder_hours`, so the scan iterates accounts
# and queries each with its own cutoff.
#
# Kept cheap: the partial index `idx_orders_pickup_reminder_pending`
# (see migrations) is exactly-shaped for the `Order.awaiting_pickup_reminder`
# scope, so PostgreSQL index-onlys the whole lookup.
class PickupReminderScanJob < ApplicationJob
  queue_as :low

  def perform
    Account.kept.find_each do |account|
      hours = account.public_profile.pickup_reminder_hours.to_i
      next if hours <= 0

      cutoff = hours.hours.ago
      account.orders.awaiting_pickup_reminder(cutoff).pluck(:id).each do |id|
        PickupReminderJob.perform_later(id)
      end
    end
  end
end
