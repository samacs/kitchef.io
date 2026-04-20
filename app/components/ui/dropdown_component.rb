module Ui
  # Generic accessible dropdown/popover — used for the user menu, the
  # panel sidebar identity card, and anywhere a trigger reveals a short
  # list of actions. The interaction logic lives in
  # app/javascript/controllers/dropdown_controller.js (toggle on click,
  # close on outside click / Escape / Turbo navigation, arrow-key menu
  # traversal).
  #
  # Slots:
  #   with_trigger { … }   required — the clickable surface
  #   with_menu    { … }   required — the popover contents
  #
  # Options:
  #   placement   :bottom_end (default), :bottom_start, :top_end, :top_start
  #   offset      pixel gap between trigger and panel (default 8)
  #   menu_width  tailwind width class for the panel (default w-[240px])
  #
  #   <%= render Ui::DropdownComponent.new(placement: :bottom_end) do |d| %>
  #     <% d.with_trigger do %>
  #       <button class="…">Open</button>
  #     <% end %>
  #     <% d.with_menu do %>
  #       <a role="menuitem" href="/account">Mi cocina</a>
  #       …
  #     <% end %>
  #   <% end %>
  class DropdownComponent < ApplicationComponent
    PLACEMENTS = %i[bottom_end bottom_start top_end top_start].freeze

    renders_one :trigger
    renders_one :menu

    option :placement,  default: -> { :bottom_end }
    option :offset,     default: -> { 8 }
    option :menu_width, default: -> { "w-[240px]" }
    option :menu_class, default: -> { "" }
    option :id,         optional: true

    def call
      content_tag(
        :div,
        class: "relative inline-flex",
        data: {
          controller: "dropdown",
          dropdown_placement_value: placement.to_s,
          dropdown_offset_value: offset
        }
      ) do
        safe_join([ trigger_wrapper, menu_wrapper ])
      end
    end

    private

    def trigger_wrapper
      # `class: "contents"` keeps the wrapper out of the visual flow so
      # the slot's real button/link owns layout. Stimulus dispatches
      # click/keydown from the wrapper (events bubble up from the inner
      # element), then sets ARIA on the inner interactive child so the
      # semantics stay on the focusable surface.
      content_tag(
        :div,
        trigger,
        class: "contents",
        data: {
          dropdown_target: "trigger",
          dropdown_panel_id_value_fallback: panel_id,
          action: "click->dropdown#toggle keydown->dropdown#triggerKeydown"
        }
      )
    end

    def menu_wrapper
      content_tag(
        :div,
        menu,
        id: panel_id,
        class: menu_classes,
        role: "menu",
        hidden: true,
        data: {
          dropdown_target: "menu",
          action: "keydown->dropdown#menuKeydown"
        }
      )
    end

    def menu_classes
      [
        "absolute z-50 mt-2 min-w-max",
        menu_width,
        "bg-surface border border-line rounded-card-sm shadow-lift",
        "p-1.5 flex flex-col gap-px",
        # Contain scroll inside the panel: overscroll-contain prevents the
        # page from scrolling when the menu reaches its top/bottom, and
        # overflow-y-auto lets long menus scroll internally. The actual
        # max-height is set at runtime by the Stimulus controller from
        # the space between the trigger and the viewport edge — this
        # class list just enables the overflow machinery.
        "overflow-y-auto overscroll-contain",
        "origin-top transition-[opacity,transform] duration-150",
        "data-[closed]:opacity-0 data-[closed]:scale-[0.98] data-[closed]:pointer-events-none",
        placement_classes,
        menu_class
      ].compact.join(" ")
    end

    def placement_classes
      case placement
      when :bottom_start then "top-full left-0"
      when :top_end      then "bottom-full right-0 origin-bottom"
      when :top_start    then "bottom-full left-0 origin-bottom"
      else                    "top-full right-0"
      end
    end

    def panel_id = id || "kc-dropdown-#{object_id}"
  end
end
