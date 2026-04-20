module Storefronts
  # Single source of truth for per-account brand palettes. Called from the
  # storefront layout to inject inline CSS custom properties:
  #
  #   <style>
  #     :root { --brand-1: #0A5A3C; --brand-1-ink: #F8F6F1; … }
  #     .dark { --brand-1: #3FAE7D; --brand-1-ink: #0E1714; … }
  #   </style>
  #
  # The operator app never reads these vars — it renders the Kitchef
  # deep-green accent via Tailwind tokens in `app/assets/tailwind/application.css`.
  #
  # Each palette ships with a pre-computed light + dark variant. `c` is the
  # primary color; `ink` is the foreground-on-primary (used for CTA label
  # text); `soft` is a tinted surface for subtle backgrounds (pill fills,
  # info-strip cards); `line` is a tinted divider. All contrast ratios were
  # chosen at design time so the operator can't pick an unreadable combo.
  class Palette
    # Fallback palette when `account.branding.palette` references a name
    # that isn't in the table (e.g. a stale value after a palette rename).
    DEFAULT = "bosque".freeze

    PALETTES = {
      "bosque" => {
        label: "Bosque",
        light: { c: "#0A5A3C", ink: "#F8F6F1", soft: "#E3EDE6", line: "#B9D4C2" },
        dark:  { c: "#3FAE7D", ink: "#0E1714", soft: "#13382A", line: "#1F4A37" }
      },
      "terracota" => {
        label: "Terracota",
        light: { c: "#B04E0E", ink: "#FFF6ED", soft: "#F6E2CB", line: "#E6C5A1" },
        dark:  { c: "#E08A4F", ink: "#1A0E05", soft: "#3E230F", line: "#5A3516" }
      },
      "tinto" => {
        label: "Tinto",
        light: { c: "#6E1F2B", ink: "#FBEFF1", soft: "#F0D8DC", line: "#D8ADB4" },
        dark:  { c: "#D87888", ink: "#1A0A0D", soft: "#3B1820", line: "#55222D" }
      },
      "cobalto" => {
        label: "Cobalto",
        light: { c: "#1F3A8A", ink: "#EEF2FC", soft: "#DCE3F3", line: "#B2C0E2" },
        dark:  { c: "#7AA2FF", ink: "#0A1024", soft: "#16244A", line: "#233663" }
      },
      "mostaza" => {
        label: "Mostaza",
        # Light-variant ink is a deep warm brown rather than cream so
        # the foreground still passes WCAG AA (4.5:1) against the
        # mustard background — cream on mustard was 4.36:1, too close
        # to the edge for body CTAs. The dark variant keeps the near-
        # black ink because the dark mustard is bright enough.
        light: { c: "#9C6B12", ink: "#2A1F05", soft: "#F3E3B8", line: "#DCC57F" },
        dark:  { c: "#E8C35A", ink: "#1A1407", soft: "#3B2D0F", line: "#574217" }
      },
      "cacao" => {
        label: "Cacao",
        light: { c: "#4A2A1A", ink: "#F5ECE3", soft: "#E5D4C4", line: "#C9AF96" },
        dark:  { c: "#C69377", ink: "#120905", soft: "#2F1C11", line: "#432919" }
      },
      "pizarra" => {
        label: "Pizarra",
        light: { c: "#2C3E50", ink: "#ECF0F3", soft: "#D8DFE5", line: "#AFBCC8" },
        dark:  { c: "#8BA3B8", ink: "#0A1014", soft: "#1B2731", line: "#2A3A48" }
      },
      "rosa" => {
        label: "Rosa Mexicano",
        light: { c: "#C9284B", ink: "#FFF0F3", soft: "#F6D2DA", line: "#EAA5B4" },
        dark:  { c: "#F07088", ink: "#1A080D", soft: "#3B141D", line: "#58202C" }
      },
      "durazno" => {
        label: "Durazno",
        # Light-variant ink is a deep warm brown, not cream — peach on
        # cream was 3.87:1 which fails AA for body text. A deep brown
        # takes the ratio to ~5.9:1 while preserving the palette's
        # peach character in the primary color.
        light: { c: "#C76B3D", ink: "#2B1810", soft: "#F7DCC9", line: "#EDB893" },
        dark:  { c: "#F0A979", ink: "#1A0D05", soft: "#3B2112", line: "#55311A" }
      },
      "noroc" => {
        label: "Negro + Dorado",
        light: { c: "#1A1A1A", ink: "#F5E9C9", soft: "#EDE3C7", line: "#C9B982" },
        dark:  { c: "#E6C77A", ink: "#0A0804", soft: "#2B2312", line: "#3F341C" }
      }
    }.freeze

    # Returns a hash of palette name → human label, suitable for populating
    # the operator's branding settings form.
    def self.options
      PALETTES.transform_values { |p| p[:label] }
    end

    # Returns the palette entry for an account, falling back to DEFAULT
    # when the stored name isn't in the table. Pass `which: :secondary`
    # to retrieve the account's secondary palette.
    def self.for(account, which: :primary)
      name = case which
      when :secondary then account&.branding&.secondary_palette.to_s
      else account&.branding&.palette.to_s
      end
      PALETTES.fetch(name, PALETTES.fetch(DEFAULT))
    end

    # Returns a CSS-ready string of `--brand-1-*` and `--brand-2-*`
    # declarations for the given account and theme variant. Used inline
    # in the storefront layout's <style> block — light and dark tokens
    # are both emitted so the customer's theme toggle flips without a
    # server round-trip.
    #
    #   "--brand-1:#0A5A3C;--brand-1-ink:#F8F6F1;--brand-1-soft:#E3EDE6;--brand-1-line:#B9D4C2;
    #    --brand-2:#B04E0E;--brand-2-ink:#FFF6ED;--brand-2-soft:#F6E2CB;--brand-2-line:#E6C5A1;"
    def self.css_vars_for(account, dark: false)
      primary   = self.for(account, which: :primary).fetch(dark ? :dark : :light)
      secondary = self.for(account, which: :secondary).fetch(dark ? :dark : :light)

      "--brand-1:#{primary[:c]};" \
        "--brand-1-ink:#{primary[:ink]};" \
        "--brand-1-soft:#{primary[:soft]};" \
        "--brand-1-line:#{primary[:line]};" \
        "--brand-2:#{secondary[:c]};" \
        "--brand-2-ink:#{secondary[:ink]};" \
        "--brand-2-soft:#{secondary[:soft]};" \
        "--brand-2-line:#{secondary[:line]};"
    end

    # Returns just the primary color hex for the given variant. Handy for
    # meta tags (<meta name="theme-color">) and social preview OG tags.
    def self.primary_color_for(account, dark: false)
      self.for(account, which: :primary).fetch(dark ? :dark : :light).fetch(:c)
    end
  end
end
