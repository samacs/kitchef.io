module Ui
  # Flash notice / alert banner — one per message. Sits above forms or
  # at the top of a section. Uses the accent-soft / err-soft palette
  # (DESIGN.md §2.2) with a matching status dot prefix.
  #
  #   <%= render Ui::FlashComponent.new(kind: :notice, message: flash[:notice]) %>
  #   <%= render Ui::FlashComponent.new(kind: :alert,  message: flash[:alert]) %>
  class FlashComponent < ApplicationComponent
    KINDS = %i[notice alert].freeze

    option :kind
    option :message

    def render?
      message.present?
    end

    def call
      content_tag(
        :div,
        safe_join([ dot_tag, content_tag(:span, message, class: "flex-1") ]),
        role: (alert? ? "alert" : "status"),
        class: classes
      )
    end

    private

    def alert? = kind == :alert

    def classes
      base = "flex items-start gap-2.5 px-4 py-3 rounded-[10px] text-[13px] font-medium leading-[1.4]"
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
  end
end
