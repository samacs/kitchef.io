module Ui
  # Searchable select with an optional inline-create affordance. Renders
  # a real <input type="hidden"> so the form payload behaves like a plain
  # <select> — server-side controllers get `{ category_id: 42 }` without
  # caring that the UI is a combobox.
  #
  # Keyboard:
  #   type any characters  — filters options live
  #   ↓ / ↑                 — move highlighted row
  #   Enter                 — select highlighted row (or, with `create_path:`,
  #                           POST a new row when no match exists)
  #   Esc                   — close without changing
  #
  # Accessibility:
  #   role="combobox" + aria-autocomplete="list" on the visible input
  #   role="listbox" on the popover; role="option" on each row
  #   aria-activedescendant tracks the highlighted row id
  #
  # Create flow (Slice 1's "inline Agregar nueva"):
  #   When `create_path:` is set and the search string matches nothing,
  #   the popover shows a "↵ Agregar <term>" row. Enter fires a fetch()
  #   against `create_path` with `{ name:, kind: create_params[:kind] }`.
  #   The server returns JSON `{ id:, label:, kind: }` and the Stimulus
  #   controller appends the new option, selects it, and closes the
  #   popover — no navigation, no drawer, no reload.
  #
  # Example:
  #   <%= render Ui::ComboboxComponent.new(
  #         name: "ingredient[category_id]",
  #         id:   "ingredient_category_id",
  #         label: t("ingredients.form.category_label"),
  #         options: Category.picker_options_for(account: Current.account, kind: :ingredient),
  #         value: ingredient.category_id,
  #         placeholder: t("ingredients.form.category_placeholder"),
  #         create_path: categories_path,
  #         create_params: { kind: :ingredient }
  #       ) %>
  class ComboboxComponent < ApplicationComponent
    option :name
    option :label,         optional: true
    option :options,       default: -> { [] }  # Array of [label, id]
    option :value,         optional: true
    option :id,            optional: true
    option :placeholder,   optional: true
    option :hint,          optional: true
    option :error,         optional: true
    option :required,      default: -> { false }
    option :autofocus,     default: -> { false }
    option :create_path,   optional: true
    option :create_params, default: -> { {} }
    # Stable DOM id of the <datalist>-style option list so other UIs can
    # inject into it via Turbo Stream (e.g. `categories#create` appends
    # a new option when the operator creates a category inline).
    option :list_id,       optional: true

    def input_id
      id || "kc-combobox-#{SecureRandom.hex(4)}"
    end

    def list_dom_id
      list_id || "#{input_id}_options"
    end

    def selected_label
      return nil if value.blank?
      pair = options.find { |_, v| v.to_s == value.to_s }
      pair&.first
    end

    def selected_id
      value.to_s
    end

    def create_payload
      return nil if create_path.blank?
      { path: create_path, params: create_params.to_h }
    end

    def create_json
      create_payload&.to_json
    end
  end
end
