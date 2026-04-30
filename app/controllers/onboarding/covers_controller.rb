module Onboarding
  class CoversController < BaseController
    before_action :require_account_step

    def edit
    end

    def update
      result = AttachCover.call(
        account: current_onboarding_account,
        file:    params.dig(:account, :cover_photo)
      )

      if result.success?
        redirect_to onboarding_done_path
      else
        @errors = result.errors
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      current_onboarding_account.cover_photo.purge if current_onboarding_account.cover_photo.attached?
      redirect_to onboarding_cover_path
    end
  end
end
