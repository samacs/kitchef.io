module Accounts
  # Post-onboarding kitchen configuration update. Reached from `/account`.
  #
  # Handles three chunks together so the operator can save the whole page
  # at once: the top-level name, the branding StoreModel (palettes +
  # theme), and the public-profile StoreModel (contact + description).
  # Logo and cover attachments are optional and purged cleanly if the
  # operator submits empty file fields (we purge later via active storage
  # to keep the request fast).
  #
  # Returns the Account on success; on failure returns an AR-invalid
  # Account so the controller can re-render the form with submitted
  # values intact.
  class Update < ApplicationCommand
    option :account
    option :attributes  # top-level + :branding + :public_profile keys
    option :logo,        optional: true
    option :cover_photo, optional: true

    def call
      attrs = attributes.to_h.deep_symbolize_keys
      branding_attrs = attrs.delete(:branding) || {}
      profile_attrs  = attrs.delete(:public_profile) || {}

      account.assign_attributes(attrs.slice(:name))

      # Merge into the existing StoreModel instance instead of replacing
      # it so fields not in the form submission (partial updates from
      # autosave, for instance) keep their existing value.
      branding = account.branding
      branding.assign_attributes(branding_attrs.compact)
      account.branding = branding

      profile = account.public_profile
      profile.assign_attributes(profile_attrs.compact)
      account.public_profile = profile

      account.logo.attach(logo) if logo.present?
      account.cover_photo.attach(cover_photo) if cover_photo.present?

      if account.save
        success(account)
      else
        Result.new(success: false, object: account, errors: account.errors)
      end
    end
  end
end
