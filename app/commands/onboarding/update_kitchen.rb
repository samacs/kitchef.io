module Onboarding
  # Edits an existing account's kitchen name and/or slug during the
  # onboarding kitchen step. The operator arrives here when she hits
  # "back" after already creating her account — the form POSTs back to
  # the same endpoint and this command takes over from CreateAccount.
  class UpdateKitchen < ApplicationCommand
    option :account
    option :name
    option :slug, optional: true

    def call
      if name.present?
        account.name = name.to_s.strip
        provided    = slug.to_s.strip
        # If the operator left the slug field blank after renaming the
        # kitchen, mirror the sign-up path: regenerate from the name.
        # Otherwise an empty slug trips the presence validator.
        account.slug = provided.presence || Account.slugify(name)
      elsif slug.present?
        account.slug = slug.to_s.strip
      end

      if account.save
        success(account)
      else
        failure(account.errors)
      end
    end
  end
end
