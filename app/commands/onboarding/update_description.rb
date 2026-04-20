module Onboarding
  class UpdateDescription < ApplicationCommand
    option :account
    option :description

    def call
      profile = account.public_profile
      profile.description = description.to_s.strip
      account.public_profile = profile

      if account.save
        success(account)
      else
        failure(account.errors)
      end
    end
  end
end
