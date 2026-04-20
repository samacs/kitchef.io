module Ui
  # A single menu item inside a Ui::DropdownComponent menu slot. Renders
  # as <a> by default; pass `method:` to get a Rails `button_to` form
  # (for destructive actions like sign-out) that still looks identical.
  #
  #   <%= render Ui::MenuItemComponent.new(label: "Mi cocina", icon: :home, href: account_path) %>
  #   <%= render Ui::MenuItemComponent.new(label: "Cerrar sesión", icon: :log_out,
  #         href: destroy_session_path, method: :delete, danger: true) %>
  class MenuItemComponent < ApplicationComponent
    option :label
    option :icon,     optional: true
    option :href,     optional: true
    option :method,   optional: true
    option :danger,   default: -> { false }
    option :trailing, optional: true

    def call
      return anchor_link if method.blank? || href.blank?

      # button_to wraps a <button type="submit"> in a <form>, automatically
      # inserting the _method override and CSRF authenticity_token hidden
      # fields INSIDE the form — which is what a previous hand-rolled
      # implementation got wrong (fields rendered as siblings of the
      # form never get submitted). Using button_to keeps that invariant
      # centralized in Rails itself.
      helpers.button_to(
        href,
        method: method,
        form: { class: "contents" },
        class: classes,
        role: "menuitem",
        tabindex: "-1",
        data: { action: "click->dropdown#close" }
      ) { body }
    end

    private

    def anchor_link
      content_tag(:a, body,
        href: href || "#", class: classes, role: "menuitem", tabindex: "-1",
        data: { action: "click->dropdown#close" })
    end

    def classes
      [
        "group flex items-center gap-2.5 w-full text-left",
        "px-2.5 py-2 rounded-[7px]",
        "text-[13.5px] font-medium leading-none",
        (danger ? "text-err hover:bg-[color-mix(in_oklab,var(--color-err)_8%,transparent)]" : "text-ink-2 hover:bg-bg-2 hover:text-ink"),
        "transition-colors focus:outline-none focus-visible:bg-bg-2 focus-visible:text-ink"
      ].join(" ")
    end

    def body
      safe_join([
        (icon_tag if icon),
        content_tag(:span, label, class: "flex-1"),
        (content_tag(:span, trailing, class: "text-[11px] font-mono text-muted") if trailing)
      ].compact)
    end

    def icon_tag
      content_tag(:span,
        helpers.icon(icon, size: :sm),
        class: [
          "inline-flex shrink-0",
          (danger ? "text-err" : "text-muted group-hover:text-accent transition-colors")
        ].join(" ")
      )
    end
  end
end
