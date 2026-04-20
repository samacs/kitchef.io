class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    redirect_to new_session_path, alert: I18n.t("sessions.create.rate_limited")
  }

  layout "auth", only: %i[ new ]

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to post_sign_in_destination_for(user)
    else
      redirect_to new_session_path, alert: t(".invalid_credentials")
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  # Route a freshly-signed-in operator to the right landing page. Mid-
  # onboarding users get dropped back into the wizard so they can pick up
  # where they left off — going to `/` would otherwise trip the
  # AuthenticatedController's `require_account` guard (no account yet) or
  # land them on a dashboard before they've chosen a kitchen name.
  def post_sign_in_destination_for(user)
    account = user.owned_account
    if account.nil?
      session.delete(:return_to_after_authenticating)
      onboarding_root_path
    elsif !account.settings.onboarding_completed
      session.delete(:return_to_after_authenticating)
      onboarding_done_path
    else
      after_authentication_url
    end
  end
end
