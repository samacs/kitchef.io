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
  #      just made shows up immediately. `broadcasts_refreshes_to` is
  #      request-id-aware and SKIPS the submitter's own broadcast, so
  #      without this explicit refresh the source tab would see the
  #      drawer close but the page stay stale.
  #
  # Other tabs subscribed to the record's broadcast stream still receive
  # the normal broadcast refresh — this helper only fills the gap on
  # the submitting tab.
  def close_drawer_and_refresh
    [
      turbo_stream.update("drawer_content", ""),
      turbo_stream.refresh
    ]
  end
end
