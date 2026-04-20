module Onboarding
  # Flips the onboarding_completed flag so subsequent visits to
  # /onboarding/* bounce to the dashboard. Idempotent — hitting the done
  # screen twice doesn't re-stamp the time.
  class Complete < ApplicationCommand
    option :account

    def call
      settings = account.settings
      return success(account) if settings.onboarding_completed

      settings.onboarding_completed = true
      account.settings = settings

      if account.save
        success(account)
      else
        failure(account.errors)
      end
    end
  end
end
