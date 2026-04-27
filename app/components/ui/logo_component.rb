module Ui
  # Wordmark used in the marketing nav, panel sidebar, auth and
  # onboarding layouts, and any place we need a Kitchef brand mark.
  #
  # Inlines the SVG from `app/assets/images/logo.svg` (mark only) or
  # `logo-horizontal.svg` (mark + wordmark) so the colors can flip
  # with the `.dark` theme via CSS variables — `var(--color-accent)`,
  # `var(--color-bg)`, `currentColor`. An <img> tag would lose that
  # because the SVG'd render in its own document context.
  #
  #   <%= render Ui::LogoComponent.new %>                    # horizontal lockup
  #   <%= render Ui::LogoComponent.new(size: :sm, href: "/") %>
  #   <%= render Ui::LogoComponent.new(wordmark: false) %>   # mark only
  class LogoComponent < ApplicationComponent
    SIZES = %i[sm md lg].freeze

    option :size,     default: -> { :md }
    option :href,     optional: true
    option :wordmark, default: -> { true }
    option :label,    optional: true

    def call
      tag_name = href.present? ? :a : :span
      attrs = { class: wrapper_classes, "aria-label": label || t("marketing.brand.name") }
      attrs[:href] = href if tag_name == :a

      content_tag(tag_name, svg_markup.html_safe, **attrs)
    end

    private

    def wrapper_classes
      [
        "inline-flex items-center text-ink no-underline",
        wrapper_height
      ].join(" ")
    end

    # Pick the SVG file based on the wordmark flag and load it from
    # disk. Cached at class level so we don't re-read on every render.
    def svg_markup
      key = wordmark ? :horizontal : :mark
      self.class.svg_cache[key] ||= File.read(svg_path).strip
    end

    def svg_path
      filename = wordmark ? "logo-horizontal.svg" : "logo.svg"
      Rails.root.join("app/assets/images", filename)
    end

    # Set height via a Tailwind utility on the wrapper; the inlined
    # SVG inherits the height because we strip its width/height attrs
    # in the file (it only has viewBox, so it scales to fit). The
    # wordmark variant scales 184×64 → ~75×26 at sm; the mark
    # variant scales 64×64 → 26×26.
    def wrapper_height
      case size
      when :sm then "[&>svg]:h-[26px] [&>svg]:w-auto h-[26px]"
      when :lg then "[&>svg]:h-[40px] [&>svg]:w-auto h-[40px]"
      else "[&>svg]:h-[32px] [&>svg]:w-auto h-[32px]"
      end
    end

    def self.svg_cache
      @svg_cache ||= {}
    end
  end
end
