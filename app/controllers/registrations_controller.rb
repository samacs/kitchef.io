class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  layout "auth"

  def new
    # Renders app/views/registrations/new.html.erb under the auth layout.
  end

  # TODO(phase-6): actually create a User + Account pair, start a session
  # and redirect to the dashboard. For now the form POSTs into a stub so
  # we can review the design without half-built persistence logic.
  def create
    render_stub(title: t("registrations.title"), meta: "registrations#create")
  end
end
