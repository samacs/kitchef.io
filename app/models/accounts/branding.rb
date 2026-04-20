module Accounts
  # Per-account storefront theme, persisted on `accounts.branding` (JSONB).
  #
  # Each kitchen picks a primary + secondary palette from the curated
  # 10-palette set (see `Storefronts::Palette`). Every palette ships with
  # pre-computed light and dark variants so customers always get a
  # readable contrast regardless of their own light/dark preference.
  #
  # The CUSTOMER controls the theme. The storefront layout's pre-paint
  # script seeds from system preference and lets the customer cycle via
  # the header theme toggle (auto → light → dark, persisted in
  # localStorage keyed by slug). We don't let the operator force a theme
  # on visitors — respecting a customer's `prefers-color-scheme` is the
  # accessible default.
  #
  # The operator app NEVER reads these variables — it ships the Kitchef
  # deep-green accent unchanged. Only storefront views/components consume
  # the `--brand-*` tokens.
  class Branding
    include StoreModel::Model

    PALETTES = %w[
      bosque
      terracota
      tinto
      cobalto
      mostaza
      cacao
      pizarra
      rosa
      durazno
      noroc
    ].freeze

    # Primary palette. Seed default is `bosque` (deep green, same family
    # as the Kitchef product palette so a brand-new account still looks
    # polished before the operator visits the branding settings).
    attribute :palette, :string, default: "bosque"

    # Secondary palette — used for icon accents, discount badges, and
    # any surface the design calls out in a complementary color. The
    # design prototype pairs Bosque with Terracota by default (warm
    # complement to the cool green). Operator-configurable from the
    # kitchen settings page.
    attribute :secondary_palette, :string, default: "terracota"

    # Pro-only flag — flipping to `true` removes the "Hecha con Kitchef"
    # attribution from the storefront footer. Enforced at the view layer,
    # not the model (free tier can't flip it without upgrading).
    attribute :hide_kitchef_branding, :boolean, default: false

    validates :palette,           inclusion: { in: PALETTES }
    validates :secondary_palette, inclusion: { in: PALETTES }
  end
end
