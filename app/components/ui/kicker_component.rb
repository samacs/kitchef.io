module Ui
  # Mono eyebrow label with a 20px horizontal rule prefix — DESIGN.md §3.2
  # and §5.6. Used above every section H2 and above the titles in auth +
  # dashboard surfaces.
  #
  #   <%= render Ui::KickerComponent.new(text: t("sessions.new.kicker")) %>
  #   <%= render Ui::KickerComponent.new(text: "Entrar", rule: false) %>
  class KickerComponent < ApplicationComponent
    option :text
    option :rule, default: -> { true }
    option :tag,  default: -> { :span }

    def call
      content_tag(tag, class: classes) do
        [
          (content_tag(:span, "", class: "inline-block w-5 h-px bg-accent", aria: { hidden: true }) if rule),
          content_tag(:span, text)
        ].compact.reduce(:+)
      end
    end

    private

    def classes
      [
        "inline-flex items-center gap-2",
        "font-mono text-[11.5px] font-medium",
        "tracking-[0.18em] uppercase text-accent"
      ].join(" ")
    end
  end
end
