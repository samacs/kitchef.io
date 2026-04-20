module Onboarding
  class DescriptionsController < BaseController
    before_action :require_account_step

    def edit
      @description = current_onboarding_account.public_profile.description
    end

    def update
      result = UpdateDescription.call(
        account:     current_onboarding_account,
        description: params.dig(:account, :description).to_s
      )

      if result.success?
        redirect_to onboarding_logo_path
      else
        @description = params.dig(:account, :description).to_s
        @errors      = result.errors
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
