# Pings the operator when a pickup pedido has been sitting in `ready`
# longer than her configured threshold (`public_profile.pickup_reminder_hours`,
# default 4h). A cold tamal because the customer forgot is the outcome
# we're preventing.
#
# The job stamps `pickup_reminder_sent_at` on the order so a second scan
# doesn't re-ping, and currently writes to Rails.logger — we'll swap in
# Noticed + WhatsApp deep-link copy once the operator's notification
# center lands. The important invariant is the dedup stamp.
class PickupReminderJob < ApplicationJob
  queue_as :notifications

  def perform(order_id)
    order = Order.kept.find_by(id: order_id)
    return unless order
    return unless order.state == "ready"
    return unless order.pickup?
    return if order.pickup_reminder_sent_at.present?

    # Stamp first so a concurrent job doesn't ping twice. Notifying after
    # the stamp is safer than before — the worst case is a missing ping,
    # not a double ping that annoys the operator + customer.
    order.update_column(:pickup_reminder_sent_at, Time.current)

    Rails.logger.info(
      "[PickupReminderJob] order=#{order.prefix_id} account=#{order.account_id} " \
      "client=#{order.client&.prefix_id} ready_for=#{Time.current - order.ready_at}s"
    )

    # Future: Noticed::NotificationMailer + operator push. Keeping the
    # integration seam here so wiring is one file to touch.
  end
end
