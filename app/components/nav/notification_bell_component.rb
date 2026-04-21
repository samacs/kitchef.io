module Nav
  # Top-bar notification bell — a link to `/notifications` with an unread
  # badge that updates live via the per-user Turbo Stream. The
  # `turbo_stream_from` tag is rendered as a sibling so Turbo morphs the
  # bell in place whenever a new Noticed event lands for this user.
  #
  # Count + styling come from the current user's unread notifications.
  # Renders nothing interesting when no user is signed in (the panel
  # layout already gates this, but we stay defensive).
  class NotificationBellComponent < ApplicationComponent
    option :current_user, optional: true
    option :size, default: -> { :sm }

    def unread_count
      return 0 if current_user.nil?

      current_user.notifications.unread.count
    end

    def badge?
      unread_count.positive?
    end

    def stream_name
      [ current_user, :notifications ]
    end
  end
end
