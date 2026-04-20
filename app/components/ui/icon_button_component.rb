module Ui
  # Square icon button used across navs and top bars (DESIGN.md §2.1 — the
  # 34–36px surface/line/rounded-input chip with a 14–16px icon inside).
  #
  #   <%= render Ui::IconButtonComponent.new(icon: :bell, label: t("panel.top_bar.notifications")) %>
  #   <%= render Ui::IconButtonComponent.new(icon: :menu, label: "Abrir menú", size: :lg, href: "#") %>
  #
  # `label` is required and becomes aria-label — the visual is icon-only so
  # the assistive label must always be present.
  class IconButtonComponent < ApplicationComponent
    SIZES = %i[sm md lg].freeze

    option :icon
    option :label
    option :size,    default: -> { :md }
    option :href,    optional: true
    option :badge,   default: -> { false }
    option :type,    default: -> { "button" }
    option :data,    default: -> { {} }

    def call
      tag_name = href.present? ? :a : :button
      attrs = {
        class: classes,
        aria: { label: label },
        title: label,
        data: data
      }
      attrs[:href] = href  if tag_name == :a
      attrs[:type] = type  if tag_name == :button

      content_tag(tag_name, **attrs) do
        [ helpers.icon(icon, size: icon_size), (badge_tag if badge) ].compact.reduce(:+)
      end
    end

    private

    def classes
      [
        "relative inline-flex items-center justify-center shrink-0",
        "bg-surface text-ink-2 border border-line rounded-[8px]",
        "transition-[border-color,color] hover:border-line-2 hover:text-ink",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 focus-visible:ring-offset-bg",
        dimension
      ].join(" ")
    end

    def dimension
      case size
      when :sm then "w-[32px] h-[32px]"
      when :lg then "w-[40px] h-[40px]"
      else "w-[36px] h-[36px]"
      end
    end

    def icon_size
      case size
      when :sm then :xs
      when :lg then :sm
      else :sm
      end
    end

    def badge_tag
      content_tag(
        :span, "",
        class: "absolute top-[7px] right-[8px] w-[7px] h-[7px] rounded-pill bg-accent ring-2 ring-surface",
        aria: { hidden: true }
      )
    end
  end
end
