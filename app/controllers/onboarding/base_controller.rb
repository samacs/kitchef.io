module Onboarding
  # Base for every step of the post-signup onboarding wizard. Sits between
  # ApplicationController and the per-step controllers so we can share the
  # auth guard, the "already done" bounce, and the account lookup without
  # inheriting from AuthenticatedController (which requires an account to
  # already exist — the first two steps don't).
  class BaseController < ApplicationController
    layout "onboarding"

    before_action :require_authentication
    before_action :redirect_if_onboarded

    helper_method :current_onboarding_account

    private

    def current_onboarding_account
      @current_onboarding_account ||= Current.user&.owned_account
    end

    def redirect_if_onboarded
      return unless current_onboarding_account&.settings&.onboarding_completed

      redirect_to authenticated_root_path
    end

    # Steps after "kitchen" need an existing account. If the operator
    # navigates there directly (deep link, back button after sign-out)
    # we send her back to the kitchen step.
    def require_account_step
      return if current_onboarding_account

      redirect_to onboarding_kitchen_path
    end
  end
end
