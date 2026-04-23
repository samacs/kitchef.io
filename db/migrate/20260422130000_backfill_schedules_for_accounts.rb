class BackfillSchedulesForAccounts < ActiveRecord::Migration[8.1]
  # Every account created before Phase 6 needs an empty Schedule so the
  # storefront picker has something to read. New accounts get this for
  # free via Account's `after_create :ensure_schedule` callback.
  def up
    Account.reset_column_information
    Account.find_each do |account|
      next if account.schedule.present?

      account.create_schedule!(order_mode: :advance, lead_time_minutes: 0)
    rescue ActiveRecord::RecordNotUnique
      next
    end
  end

  def down
    # No-op: we'd rather keep the schedules around than drop them.
  end
end
