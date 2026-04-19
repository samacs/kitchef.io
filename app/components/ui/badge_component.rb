module Ui
  # Status pill / badge primitive per DESIGN.md §5.2 and §2.2.
  #
  #   <%= render Ui::BadgeComponent.new(label: "Listo", status: :listo) %>
  #   <%= render Ui::BadgeComponent.new(label: "Nuevo", status: :nuevo) %>
  class BadgeComponent < ApplicationComponent
    # Each status maps to (background token, foreground token). Tokens live
    # in app/assets/tailwind/application.css and flip in dark mode
    # automatically.
    STATUSES = {
      default:        { bg: "bg-surface",                      fg: "text-ink-2",  border: "border-line" },
      listo:          { bg: "bg-accent-soft",                  fg: "text-accent", border: "border-transparent" },
      en_produccion:  { bg: "bg-[var(--color-status-en-produccion-bg)]", fg: "text-[var(--color-status-en-produccion-fg)]", border: "border-transparent" },
      nuevo:          { bg: "bg-[var(--color-status-nuevo-bg)]",          fg: "text-[var(--color-status-nuevo-fg)]",         border: "border-transparent" },
      atrasado:       { bg: "bg-[var(--color-status-atrasado-bg)]",       fg: "text-[var(--color-status-atrasado-fg)]",      border: "border-transparent" }
    }.freeze

    option :label
    option :status, default: -> { :default }
    option :dot,    default: -> { true }

    def call
      style = STATUSES.fetch(status, STATUSES[:default])
      classes = [
        "inline-flex items-center gap-1.5",
        "px-2.5 py-[2px] rounded-pill border",
        "text-[11px] font-medium leading-none",
        style[:bg], style[:fg], style[:border]
      ].join(" ")

      content_tag(:span, class: classes) do
        [
          (dot ? content_tag(:span, "", class: "w-[5px] h-[5px] rounded-pill bg-current") : nil),
          label
        ].compact.reduce(:+)
      end
    end
  end
end
