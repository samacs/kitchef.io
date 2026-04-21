module Ui
  # Flash notice / alert banner — one per message. Sits above forms or at
  # the top of a section. Uses the accent-soft / err-soft palette
  # (DESIGN.md §2.2) with a matching status dot prefix.
  #
  # Auto-dismiss behavior is driven by `flash_dismiss_controller.js`:
  #   - Dismisses automatically after `dismiss_after_ms` (default 5000ms)
  #   - Hovering cancels the timer (so the user can read long messages)
  #   - Leaving restarts the timer from zero
  #   - The × button dismisses immediately
  #   - Pass `dismiss_after_ms: nil` to disable auto-dismiss entirely
  #     (e.g. for persistent critical alerts)
  #
  #   <%= render Ui::FlashComponent.new(kind: :notice, message: flash[:notice]) %>
  #   <%= render Ui::FlashComponent.new(kind: :alert,  message: flash[:alert]) %>
  #   <%= render Ui::FlashComponent.new(kind: :alert,  message: msg, dismiss_after_ms: nil) %>
  class FlashComponent < ApplicationComponent
    KINDS = %i[notice alert].freeze
    DEFAULT_DISMISS_MS = 5000

    option :kind
    option :message
    option :dismiss_after_ms, default: -> { DEFAULT_DISMISS_MS }

    def render?
      message.present?
    end

    def call
      content_tag(
        :div,
        safe_join([ dot_tag, message_tag, dismiss_button ]),
        role: (alert? ? "alert" : "status"),
        class: classes,
        data: controller_data
      )
    end

    private

    def alert? = kind == :alert

    def controller_data
      {
        controller: "flash-dismiss",
        flash_dismiss_delay_value: dismiss_after_ms.to_i,
        flash_dismiss_auto_value: auto_dismiss?,
        action: "mouseenter->flash-dismiss#pause mouseleave->flash-dismiss#resume"
      }
    end

    def auto_dismiss?
      dismiss_after_ms.present? && dismiss_after_ms.to_i.positive?
    end

    def classes
      base = "relative flex items-start gap-2.5 px-4 py-3 pr-10 rounded-[10px] text-[13px] font-medium leading-[1.4] " \
             "transition-opacity duration-200 data-[leaving]:opacity-0"
      tone = if alert?
        "bg-[color-mix(in_oklab,var(--color-err)_10%,var(--color-surface))] text-err border border-err/30"
      else
        "bg-accent-soft text-accent border border-transparent"
      end
      "#{base} #{tone}"
    end

    def dot_tag
      content_tag(:span, "",
        class: "mt-[6px] w-[6px] h-[6px] rounded-pill bg-current shrink-0",
        aria: { hidden: true })
    end

    def message_tag
      content_tag(:span, message, class: "flex-1")
    end

    def dismiss_button
      content_tag(
        :button,
        safe_join([ close_icon, content_tag(:span, I18n.t("ui.flash.dismiss"), class: "sr-only") ]),
        type: "button",
        class: "absolute right-2 top-2 inline-flex h-7 w-7 items-center justify-center rounded-[7px] text-current opacity-70 hover:opacity-100 hover:bg-current/10 transition-opacity",
        data: { action: "click->flash-dismiss#dismiss" },
        "aria-label": I18n.t("ui.flash.dismiss")
      )
    end

    def close_icon
      content_tag(:svg, nil, width: 14, height: 14, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
        "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": true) do
        content_tag(:path, nil, d: "M18 6L6 18M6 6l12 12")
      end
    end
  end
end
