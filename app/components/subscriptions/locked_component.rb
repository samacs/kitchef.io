module Subscriptions
  # Renders a locked-feature card on every Pro-gated surface. The
  # idea: instead of redirecting away or showing a 403, we render the
  # surface with this card mounted in place of the gated content. The
  # operator sees what the feature *is* — short headline + 2-3
  # bullets + a CTA — without losing her place in the app.
  #
  # Usage:
  #   <%= render Subscriptions::LockedComponent.new(
  #         feature_key: :composable_recipes,
  #         title:       t("recipes.locked.title"),
  #         lede:        t("recipes.locked.lede"),
  #         bullets:     [t("recipes.locked.b1"), t("recipes.locked.b2")]
  #       ) %>
  #
  # `feature_key` is the symbol Entitlements gates on; the component
  # reads it back to inform the CTA copy ("Activa Pro para descomponer
  # tus recetas") and to build the upgrade URL with a prefilled
  # context param so the pricing page can highlight the right feature.
  class LockedComponent < ApplicationComponent
    option :feature_key
    option :title
    option :lede
    option :bullets,    default: -> { [] }
    option :cta_label,  default: -> { I18n.t("subscriptions.locked.cta") }
    option :compact,    default: -> { false }

    def render?
      true
    end

    def cta_path
      if helpers.authenticated?
        helpers.subscription_path(highlight: feature_key)
      else
        helpers.pricing_path(highlight: feature_key)
      end
    end

    def container_classes
      base = "rounded-card border border-line bg-bg-2 p-5 sm:p-6 flex flex-col gap-3"
      base += " items-start" unless compact
      base += " items-center text-center" if compact
      base
    end

    def lock_icon
      :lock
    end
  end
end
