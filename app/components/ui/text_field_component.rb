module Ui
  # Labeled form field used across auth pages and the panel forms. Wraps a
  # real <input> so Rails form_with's `form.text_field :foo` can still be
  # used when preferred; this component is for the cases where you're
  # laying out the markup directly and want the label/input/hint/error
  # stack styled to tokens.
  #
  #   <%= render Ui::TextFieldComponent.new(
  #         name: "email_address",
  #         label: t(".email_label"),
  #         type: :email,
  #         placeholder: t(".email_placeholder"),
  #         autocomplete: "username",
  #         required: true
  #       ) %>
  class TextFieldComponent < ApplicationComponent
    option :name
    option :label
    option :type,          default: -> { :text }
    option :value,         optional: true
    option :placeholder,   optional: true
    option :hint,          optional: true
    option :error,         optional: true
    option :autocomplete,  optional: true
    option :autofocus,     default: -> { false }
    option :required,      default: -> { false }
    option :maxlength,     optional: true
    option :id,            optional: true
    option :input_class,   optional: true
    option :leading_icon,  optional: true
    option :trailing,      optional: true
    option :data,          default: -> { {} }

    def call
      content_tag(:label, class: "flex flex-col gap-2", for: input_id) do
        safe_join([ label_row, field_wrapper, hint_or_error ].compact)
      end
    end

    private

    def input_id = id || "kc-#{name.to_s.tr('[]', '--')}"

    def label_row
      content_tag(:span, label, class: "text-[13px] font-medium text-ink leading-none")
    end

    def field_wrapper
      content_tag(:span, class: "relative flex items-center") do
        safe_join(
          [
            (leading_icon_tag if leading_icon),
            input_tag,
            (content_tag(:span, trailing, class: "absolute right-3 top-1/2 -translate-y-1/2 text-muted") if trailing)
          ].compact
        )
      end
    end

    def leading_icon_tag
      content_tag(
        :span,
        helpers.icon(leading_icon, size: :sm),
        class: "absolute left-3 top-1/2 -translate-y-1/2 text-muted pointer-events-none"
      )
    end

    def input_tag
      tag.input(
        **input_attrs,
        class: input_classes,
        data: data
      )
    end

    def input_attrs
      attrs = {
        type: type.to_s,
        name: name,
        id: input_id,
        placeholder: placeholder,
        autocomplete: autocomplete,
        autofocus: autofocus,
        maxlength: maxlength,
        value: value
      }
      attrs[:required] = "required" if required
      attrs[:"aria-invalid"] = "true" if error.present?
      attrs.compact
    end

    def input_classes
      [
        "w-full bg-surface text-ink placeholder:text-muted",
        "border rounded-input",
        (error.present? ? "border-err" : "border-line hover:border-line-2"),
        "px-3.5 py-2.5 text-[14px] leading-[1.3]",
        "transition-[border-color,box-shadow] outline-none",
        "focus:border-accent focus:ring-2 focus:ring-accent/20",
        (leading_icon ? "pl-10" : nil),
        (trailing ? "pr-10" : nil),
        input_class
      ].compact.join(" ")
    end

    def hint_or_error
      return content_tag(:span, error, class: "text-[12px] text-err font-medium") if error.present?
      return content_tag(:span, hint, class: "text-[12px] text-muted") if hint.present?
      nil
    end
  end
end
