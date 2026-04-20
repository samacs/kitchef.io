module Ui
  # Wordmark used in the marketing nav, panel sidebar and auth layout.
  # The `k` mark is the italic serif glyph on the accent square; the
  # wordmark itself is sans bold.
  #
  #   <%= render Ui::LogoComponent.new %>
  #   <%= render Ui::LogoComponent.new(size: :sm, href: root_path) %>
  #   <%= render Ui::LogoComponent.new(wordmark: false) %>  # mark only
  class LogoComponent < ApplicationComponent
    SIZES = %i[sm md lg].freeze

    option :size,     default: -> { :md }
    option :href,     optional: true
    option :wordmark, default: -> { true }
    option :label,    optional: true

    def call
      tag_name = href.present? ? :a : :span
      attrs = { class: wrapper_classes }
      attrs[:href] = href if tag_name == :a

      content_tag(tag_name, **attrs) do
        [ mark_tag, (wordmark_tag if wordmark) ].compact.reduce(:+)
      end
    end

    private

    def wrapper_classes
      [ "inline-flex items-center gap-2 text-ink", "font-bold tracking-[-0.02em] leading-none", text_size ].join(" ")
    end

    def mark_tag
      content_tag(
        :span,
        mark_glyph,
        class: [
          "inline-flex items-center justify-center shrink-0",
          "bg-accent text-bg rounded-[7px]",
          "font-serif italic font-normal leading-none",
          mark_size
        ].join(" "),
        aria: { hidden: true }
      )
    end

    def wordmark_tag
      content_tag(:span, label || t("marketing.brand.name"))
    end

    def mark_glyph = t("marketing.brand.mark")

    def text_size
      case size
      when :sm then "text-[15px]"
      when :lg then "text-[22px]"
      else "text-[17px]"
      end
    end

    def mark_size
      case size
      when :sm then "w-[22px] h-[22px] text-[15px]"
      when :lg then "w-[34px] h-[34px] text-[22px]"
      else "w-[26px] h-[26px] text-[18px]"
      end
    end
  end
end
