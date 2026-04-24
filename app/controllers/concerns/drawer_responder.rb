module DrawerResponder
  extend ActiveSupport::Concern

  private

  # Canonical Turbo Stream response for a successful action that lives
  # inside the shared right drawer. Returns two actions:
  #
  #   1. Empty the drawer_content frame — the `right-drawer` Stimulus
  #      controller watches for an empty frame and slides the panel
  #      shut on its own.
  #   2. Refresh the submitter's page — morph-refreshes the underlying
  #      surface (kanban / table / etc.) so the change the operator
  #      just made shows up immediately.
  #
  # Request-id override: `turbo_stream.refresh` with no args inherits
  # `Turbo.current_request_id`, which the browser then recognises as
  # "a request I already sent" (it's in Turbo's `recentRequests` set)
  # and skips the refresh — the dedup mechanism built for
  # `broadcasts_refreshes_to` to prevent the initiating tab from
  # double-refreshing. That's exactly the wrong behavior here: the
  # submitting tab IS the one that needs the refresh on a direct
  # POST/PATCH response. We pass a fresh UUID so the refresh always
  # fires locally. Other tabs listening via `turbo_stream_from`
  # subscriptions still receive their own (deduped) broadcast refresh
  # through the normal channel.
  def close_drawer_and_refresh
    [
      turbo_stream.update("drawer_content", ""),
      turbo_stream.refresh(request_id: SecureRandom.uuid)
    ]
  end
end
