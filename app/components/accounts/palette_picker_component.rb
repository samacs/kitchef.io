module Accounts
  # Visual palette picker — a row of swatch circles backed by radio
  # inputs. Mirrors the design-prototype's Tweaks panel swatch row
  # (tmp/kitchef-design/project/Kitchef Storefront.html) but renders as
  # real form controls so keyboard users + accessibility tools work.
  #
  #   <%= render Accounts::PalettePickerComponent.new(
  #         form: f, attribute: :palette, selected: account.branding.palette,
  #         live_preview_field: "palette") %>
  #
  # `live_preview_field` is optional — when present, each radio carries
  # `data-action="change->live-preview-source#emit"` plus a
  # `live-preview-source-field-param` so the storefront preview panel
  # updates in real time as the operator picks a swatch.
  class PalettePickerComponent < ApplicationComponent
    option :form
    option :attribute
    option :selected
    option :live_preview_field, optional: true

    def palettes
      Storefronts::Palette::PALETTES
    end

    def field_id(name)
      [ form.object_name.to_s.tr("[]", "_"), attribute.to_s, name ].join("_")
    end

    def field_name
      "#{form.object_name}[#{attribute}]"
    end

    def radio_data(name)
      return {} if live_preview_field.blank?
      {
        action: "change->live-preview-source#emit",
        live_preview_source_field_param: live_preview_field
      }
    end
  end
end
