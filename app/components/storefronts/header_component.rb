module Storefronts
  # Sticky top bar. Kitchen wordmark + live cart count + customer-facing
  # theme toggle. The logo links back to the storefront root so a customer
  # who navigated deep keeps their browsing context.
  #
  # Variables it reads are the storefront palette tokens (`--brand-1`,
  # `--brand-1-ink`, `--brand-1-soft`, `--brand-1-line`), injected inline
  # by the storefront layout via `Storefronts::Palette.css_vars_for`.
  class HeaderComponent < ApplicationComponent
    option :storefront

    def kitchen_name
      storefront.name
    end

    def instagram_handle
      storefront.public_profile.instagram.to_s.strip.sub(/\A@/, "")
    end

    def show_editor_chip?
      # Signed-in operators visiting their own storefront see a subtle chip
      # linking them back to the operator app — so Elena can QA her page in
      # a second tab without signing out. Non-owners don't see the chip.
      Current.user.present? && Current.user.owned_account&.id == storefront.id
    end
  end
end
