module Onboarding
  class AttachLogo < ApplicationCommand
    option :account
    option :file

    def call
      if file.blank?
        account.errors.add(:base, :logo_missing)
        return failure(account.errors)
      end

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
