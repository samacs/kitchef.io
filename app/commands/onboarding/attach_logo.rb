module Onboarding
  class AttachLogo < ApplicationCommand
    option :account
    option :file

    def call
      return failure(base: [ :logo_missing ]) if file.blank?

      account.logo.attach(file)

      if account.valid?
        success(account)
      else
        account.logo.detach
        failure(account.errors)
      end
    end
  end
end
