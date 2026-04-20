module Recipes
  # Zero-state surface shared between /recipes (when the kitchen has no
  # recipes yet) and the dashboard (first-run experience). Serif headline +
  # muted sub-copy + primary CTA button, sized for a full-width hero.
  class EmptyStateComponent < ApplicationComponent
    option :headline_key
    option :sub_key
    option :cta_label_key
    option :cta_href

    def headline
      I18n.t(headline_key)
    end

    def sub
      I18n.t(sub_key)
    end

    def cta_label
      I18n.t(cta_label_key)
    end
  end
end
