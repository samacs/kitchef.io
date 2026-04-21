module Storefronts
  # Storefront footer. Shows the kitchen's mini-card + a "Hecha con Kitchef"
  # attribution link. Pro-tier operators can hide the attribution via
  # `branding.hide_kitchef_branding` (still shipped as `false` in this
  # phase — flipping it requires Pro, enforced at the billing layer).
  class FooterComponent < ApplicationComponent
    option :storefront

    def handle
      storefront.public_profile.instagram.to_s.strip.sub(/\A@/, "")
    end

    def show_attribution?
      !storefront.branding.hide_kitchef_branding
    end
  end
end
