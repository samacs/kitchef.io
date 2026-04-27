module Marketing
  # Two-card pricing UI with a Mensual / Anual toggle on Pro. Used on
  # the home page's `#precios` section and standalone on `/pricing`.
  # Reads pricing strictly from `Marketing::PricingCatalog` so changes
  # to the Stripe prices touch one file.
  #
  # Variants:
  #   :wide    — full-width cards with feature lists (default; /pricing)
  #   :compact — narrower cards on the home page; teaser feature list,
  #              "Ver todo en /pricing" link
  class PricingCardsComponent < ApplicationComponent
    option :variant,        default: -> { :wide }
    option :default_period, default: -> { :yearly }   # Pro starts with yearly highlighted

    delegate :catalog, to: :class

    def self.catalog
      @catalog ||= Marketing::PricingCatalog
    end

    def container_classes
      max_width = variant == :compact ? "max-w-[720px]" : "max-w-[920px]"
      "grid grid-cols-1 md:grid-cols-2 gap-3.5 #{max_width} mx-auto"
    end

    def free_features
      I18n.t("marketing.pricing_cards.free.features").to_a
    end

    def pro_features
      I18n.t("marketing.pricing_cards.pro.features").to_a
    end

    def free_cta_path
      helpers.new_registration_path
    end

    def pro_cta_path
      helpers.new_registration_path(plan: "pro_trial")
    end

    def show_compare_cta?
      variant == :compact
    end
  end
end
