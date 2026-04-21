class NotificationsController < AuthenticatedController
  before_action :set_notification, only: %i[mark_read]

  # Inbox — every Noticed notification the operator has received, newest
  # first. Small enough for a flat list at our scale; pagination lands
  # when a single operator crosses a few hundred events.
  def index
    @notifications = Current.user.notifications
                                 .includes(:event)
                                 .newest_first
                                 .limit(100)
  end

  # Flip one notification's `read_at`. Responds with a turbo_stream that
  # replaces just that row (so the badge of styling changes locally) and
  # updates the bell-badge count — no full-page reload.
  def mark_read
    @notification.mark_as_read!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: notifications_path }
    end
  end

  # Sweep every unread notification for the current user. Used by the
  # header "Marcar todas como leídas" button. Bulk SQL via `update_all`
  # — no need to materialize a few hundred records just to stamp one
  # timestamp each.
  def mark_all_read
    Current.user.notifications.unread.mark_as_read

    respond_to do |format|
      format.turbo_stream do
        @notifications = Current.user.notifications
                                     .includes(:event)
                                     .newest_first
                                     .limit(100)
      end
      format.html { redirect_to notifications_path }
    end
  end

  private

  def set_notification
    @notification = Current.user.notifications.find(params[:id])
  end
end
