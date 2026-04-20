module Onboarding
  class AttachCover < ApplicationCommand
    option :account
    option :file

    def call
      return failure(base: [ :cover_missing ]) if file.blank?

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
