module Onboarding
  class AttachCover < ApplicationCommand
    option :account
    option :file

    def call
      if file.blank?
        account.errors.add(:base, :cover_missing)
        return failure(account.errors)
      end

      account.cover_photo.attach(file)

      if account.valid?
        success(account)
      else
        account.cover_photo.detach
        failure(account.errors)
      end
    end
  end
end
