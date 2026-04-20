module Onboarding
  class LogosController < BaseController
    before_action :require_account_step

    def edit
    end

    def update
      result = AttachLogo.call(
        account: current_onboarding_account,
        file:    params.dig(:account, :logo)
      )

      if result.success?
        redirect_to onboarding_cover_path
      else
        @errors = result.errors
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      current_onboarding_account.logo.purge_later if current_onboarding_account.logo.attached?
      redirect_to onboarding_logo_path
    end
  end
end
