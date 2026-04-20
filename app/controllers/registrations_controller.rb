class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  layout "auth"

  def new
  end

  # Sign-up creates the User only — kitchen name, slug, logo, and cover
  # come from the interactive onboarding flow (Onboarding::*). This keeps
  # the form to five universal fields (name, email, password, terms) and
  # defers the profile-building UX to a chrome that can render live
  # previews.
  def create
    result = Registrations::CreateUser.call(params: user_params)

    if result.success?
      start_new_session_for(result.object)
      redirect_to onboarding_root_path
    else
      @user_params     = user_params
      @errors          = result.errors
      @terms_accepted  = ActiveModel::Type::Boolean.new.cast(params[:terms_accepted])
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.permit(
      :first_name,
      :last_name,
      :email_address,
      :password,
      :password_confirmation,
      :terms_accepted
    )
  end
end
