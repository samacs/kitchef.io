module Registrations
  # Creates a fresh User record for an operator who just filled the sign-up
  # form. The Account + Subscription are NOT created here — the interactive
  # onboarding flow (Onboarding::CreateAccount) handles that once the
  # operator has chosen her kitchen name and storefront slug. This keeps
  # sign-up to the five truly universal fields (name, email, password,
  # terms) and the kitchen profile out of the way until the chrome can
  # render live previews.
  class CreateUser < ApplicationCommand
    option :params

    def call
      user = User.new(permitted_attributes)
      user.terms_accepted_at = Time.current if truthy?(params[:terms_accepted])

      if user.save
        success(user)
      else
        failure(user.errors)
      end
    end

    private

    def permitted_attributes
      params.slice(
        :first_name,
        :last_name,
        :email_address,
        :password,
        :password_confirmation,
        :terms_accepted
      )
    end

    def truthy?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
