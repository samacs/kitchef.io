module Onboarding
  class CompletionsController < BaseController
    before_action :require_account_step

    def show
    end

    def create
      Complete.call(account: current_onboarding_account)
      redirect_to authenticated_root_path
    end
  end
end
