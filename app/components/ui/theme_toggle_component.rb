module Ui
  # Three-state theme toggle (auto → light → dark). Visual matches the
  # 36×36 icon button used in the landing nav and dashboard top bar. The
  # underlying Stimulus controller (theme_controller.js) cycles modes,
  # persists to localStorage under `kitchef_theme`, and syncs tabs.
  #
  #   <%= render Ui::ThemeToggleComponent.new %>
  #   <%= render Ui::ThemeToggleComponent.new(size: :sm) %>
  class ThemeToggleComponent < ApplicationComponent
    SIZES = %i[sm md lg].freeze

    option :size, default: -> { :md }

    def call
      content_tag(
        :button,
        body,
        type: "button",
        class: button_classes,
        title: t("theme.toggle_label"),
        aria: { label: t("theme.toggle_label") },
        data: {
          controller: "theme",
          action: "click->theme#cycle",
          theme_target: "button",
          theme_storage_key_value: "kitchef_theme",
          theme_auto_label_value:  t("theme.auto"),
          theme_light_label_value: t("theme.light"),
          theme_dark_label_value:  t("theme.dark")
        }
      )
    end

    private

    # Three stacked icons; CSS selects the one whose [data-mode] matches
    # the button's [data-theme-mode], so we don't need to re-render when
    # the mode flips client-side.
    def body
      helpers.safe_join(
        [
          icon_slot(:auto,  :monitor),
          icon_slot(:light, :sun),
          icon_slot(:dark,  :moon)
        ]
      )
    end

    def icon_slot(mode, name)
      content_tag(
        :span,
        helpers.icon(name, size: icon_size),
        class: "kc-theme-glyph",
        data: { mode: mode },
        aria: { hidden: true }
      )
    end

    def button_classes
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
      size == :sm ? :xs : :sm
    end
  end
end
