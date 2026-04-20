module Onboarding
  # A miniature rendering of the operator's public storefront, used as the
  # live-preview panel next to every onboarding form. The markup is also
  # the contract for the Stimulus live-preview controller — targets
  # (`name`, `slug`, `description`, `logo`, `cover`) expose the elements
  # the JS updates as the operator types.
  class StorefrontPreviewComponent < ApplicationComponent
    option :account,     optional: true
    option :name,        optional: true
    option :slug,        optional: true
    option :description, optional: true

    def display_name
      (name.presence || account&.name).presence
    end

    def display_slug
      (slug.presence || account&.slug).presence
    end

    def display_description
      (description.presence || account&.public_profile&.description).presence
    end

    def logo_url
      return nil unless account&.logo&.attached?

      helpers.url_for(account.logo)
    end

    def cover_url
      return nil unless account&.cover_photo&.attached?

      helpers.url_for(account.cover_photo)
    end

    def empty_name_placeholder
      I18n.t("onboarding.kitchen.preview_empty_name")
    end

    def empty_description_placeholder
      I18n.t("onboarding.kitchen.preview_empty_description")
    end
  end
end
