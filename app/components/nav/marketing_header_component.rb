module Nav
  # Sticky marketing top nav — DESIGN.md §5 + landing prototype lines 353-375.
  # Glassy surface, logo + nav links + auth-aware right rail (either the
  # Iniciar sesión / Empezar gratis pair, or the user menu dropdown).
  #
  # Rendered from app/views/layouts/marketing.html.erb:
  #   <%= render Nav::MarketingHeaderComponent.new(
  #         current_user: Current.user,
  #         current_account: Current.account
  #       ) %>
  #
  # At <768px the horizontal nav collapses into a dropdown-menu attached
  # to a hamburger IconButton so we don't need a second Stimulus controller.
  class MarketingHeaderComponent < ApplicationComponent
    option :current_user,    optional: true
    option :current_account, optional: true
    option :transparent,     default: -> { false }

    def nav_links
      [
        { label: t("marketing.nav.product"),      href: how_it_works_path, anchor: true },
        { label: t("marketing.nav.how_it_works"), href: how_it_works_path },
        { label: t("marketing.nav.pricing"),      href: pricing_path },
        { label: t("marketing.nav.stories"),      href: faq_path }
      ]
    end

    def signed_in? = current_user.present?

    private

    # URL helpers — ViewComponent exposes `helpers` for runtime, but for
    # readability we delegate a few at class level.
    def how_it_works_path = helpers.how_it_works_path
    def pricing_path      = helpers.pricing_path
    def faq_path          = helpers.faq_path
  end
end
