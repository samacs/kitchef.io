module Accounts
  # Live storefront preview shown next to the kitchen-configuration form.
  # Unlike the onboarding preview, this component renders *in the brand
  # palette* so what the operator sees here matches the public storefront
  # exactly — same cover gradient, same logo halo, same serif name, same
  # brand-colored CTA.
  #
  # The markup carries Stimulus `live-preview` targets so
  # `live_preview_source_controller` can push updates live as the
  # operator types or picks a new palette:
  #
  #   - name / slug / tagline / description   (text)
  #   - logo / cover                          (file → data URL)
  #   - palette / secondary_palette           (radio → CSS vars)
  #   - theme_default                         (radio → dark class toggle)
  class StorefrontPreviewComponent < ApplicationComponent
    option :account

    delegate :name, :slug, to: :account

    def tagline
      account.public_profile.tagline.to_s
    end

    def description
      account.public_profile.description.to_s
    end

    def logo_url
      return nil unless account.logo.attached?
      helpers.url_for(account.logo.variant(:card))
    end

    def cover_url
      return nil unless account.cover_photo.attached?
      helpers.url_for(account.cover_photo.variant(:card))
    end

    def palettes_json
      # Serialize the palette table so the Stimulus receiver can look up
      # {c, ink, soft, line} for any palette name + variant without
      # shipping a duplicate client-side copy. Uses only the fields
      # the preview needs (no labels).
      Storefronts::Palette::PALETTES.transform_values do |entry|
        {
          light: entry[:light],
          dark:  entry[:dark]
        }
      end.to_json
    end

    # Initial CSS vars for first paint — the server already knows the
    # current palette, so emit them inline to avoid a flash-of-wrong-color
    # before the Stimulus controller boots. We always emit the LIGHT
    # variant here because the preview itself is rendered inside the
    # operator app (always light chrome); only the public storefront
    # responds to the customer's dark preference.
    def initial_css_vars
      Storefronts::Palette.css_vars_for(account, dark: false)
    end
  end
end
