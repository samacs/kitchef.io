module Ui
  # Labeled checkbox — the label accepts HTML (already-marked html_safe)
  # so translations can embed inline links without escaping.
  #
  #   <%= render Ui::CheckboxComponent.new(
  #         name: "terms_accepted",
  #         label: t(".terms_accept_label_html",
  #                 terms_url:   legal_path(doc: "terms"),
  #                 privacy_url: legal_path(doc: "privacy")).html_safe,
  #         required: true,
  #         checked: @terms_accepted,
  #         error: @errors&.[](:terms_accepted)&.first
  #       ) %>
  class CheckboxComponent < ApplicationComponent
    option :name
    option :label
    option :value,     default: -> { "1" }
    option :checked,   default: -> { false }
    option :required,  default: -> { false }
    option :id,        optional: true
    option :error,     optional: true

    def call
      content_tag(:label, class: "flex items-start gap-3 cursor-pointer select-none", for: input_id) do
        safe_join([ hidden_tag, control_tag, label_stack ])
      end
    end

    private

    def input_id = id || "kc-#{name.to_s.tr('[]', '--')}"

    # Rails posts unchecked boxes as "0" when there's a hidden partner
    # — matches form_with semantics for handmade markup.
    def hidden_tag
      tag.input(type: "hidden", name: name, value: "0", autocomplete: "off")
    end

    # The native checkbox is kept for semantics and a11y but is drawn via
    # Tailwind — `appearance-none` strips the browser's blue tick so the
    # box can pick up our accent green + white check glyph via `:checked`
    # variants. The glyph is a sibling <svg> that fades in via `peer-*`.
    def control_tag
      content_tag(:span, class: "relative inline-flex items-center justify-center shrink-0 mt-[2px]") do
        safe_join([ input_tag, check_glyph_tag ])
      end
    end

    def input_tag
      attrs = {
        type: "checkbox",
        id: input_id,
        name: name,
        value: value,
        class: checkbox_classes
      }
      attrs[:checked] = "checked" if checked
      attrs[:required] = "required" if required
      attrs[:"aria-invalid"] = "true" if error.present?

      tag.input(**attrs)
    end

    def checkbox_classes
      [
        "peer appearance-none",
        "w-[18px] h-[18px] rounded-[5px]",
        "bg-surface border",
        (error.present? ? "border-err" : "border-line-2"),
        "hover:border-ink-2",
        "checked:bg-accent checked:border-accent",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/25 focus-visible:ring-offset-2 focus-visible:ring-offset-bg",
        "transition-colors"
      ].join(" ")
    end

    def check_glyph_tag
      helpers.lucide_icon(
        "check",
        class: "pointer-events-none absolute w-[12px] h-[12px] text-bg stroke-[3] opacity-0 scale-75 peer-checked:opacity-100 peer-checked:scale-100 transition-[opacity,transform] duration-150"
      )
    end

    def label_stack
      parts = [ content_tag(:span, label, class: "text-[13px] text-ink-2 leading-[1.55]") ]
      if error.present?
        parts << content_tag(:span, error, class: "block text-[12px] text-err font-medium mt-1")
      end
      content_tag(:span, safe_join(parts), class: "flex-1")
    end
  end
end
