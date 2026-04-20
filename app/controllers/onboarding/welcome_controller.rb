module Onboarding
  class WelcomeController < BaseController
    def show
      # If the operator already has an account (signed up, started the
      # wizard, came back), skip the intro and drop her on the summary
      # page so she can finish or revisit any step. Brand-new operators
      # with no account yet still see the welcome card + CTA.
      redirect_to onboarding_done_path if current_onboarding_account
    end
  end
end
