module Ui
  # WCAG 2.1 contrast math. Used to pick the most-readable text color
  # against an arbitrary background, in both Ruby (for server-rendered
  # templates and for validating `Storefronts::Palette` at boot) and
  # JavaScript (for live-preview panels and any runtime color picker).
  #
  # The `INK_*` constants are Kitchef's two default text tokens —
  # `INK_LIGHT` is bone (used on dark backgrounds), `INK_DARK` is the
  # warm near-black (used on light backgrounds). `best_ink` picks
  # whichever gives a higher contrast ratio.
  #
  # For palettes whose primary sits in the mid-luminance range
  # (mustard, peach) neither default passes WCAG AA body-text
  # (4.5:1) — the `Storefronts::Palette` table ships a hand-tuned
  # deep-brown ink for those two cases. This service is for
  # everywhere else: arbitrary hexes, user-picked colors, runtime
  # shading of brand backgrounds. Check `good_enough?` before
  # blindly trusting `best_ink`.
  module Contrast
    INK_LIGHT = "#F8F6F1".freeze  # bone — on dark primaries
    INK_DARK  = "#0E1714".freeze  # warm near-black — on light primaries

    # Minimum ratio for WCAG AA body text (normal-size).
    WCAG_AA_BODY = 4.5
    # Minimum ratio for WCAG AA large text (18pt / 14pt bold).
    WCAG_AA_LARGE = 3.0

    module_function

    # Relative luminance per WCAG 2.1 — floats 0..1.
    def relative_luminance(hex)
      r, g, b = hex.sub("#", "").scan(/../).map { |h| h.to_i(16) / 255.0 }
      linear = [ r, g, b ].map do |c|
        c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
      end
      (0.2126 * linear[0]) + (0.7152 * linear[1]) + (0.0722 * linear[2])
    end

    # WCAG contrast ratio — float 1..21. Order-independent.
    def wcag_ratio(fg, bg)
      lfg = relative_luminance(fg)
      lbg = relative_luminance(bg)
      l1, l2 = [ lfg, lbg ].max, [ lfg, lbg ].min
      (l1 + 0.05) / (l2 + 0.05)
    end

    # Best-of-two text color for a given background hex. Always returns
    # one of the Kitchef ink tokens — if you need a better contrast than
    # either default can offer (mustard-on-cream territory), fall back
    # to a per-palette hand-tuned value.
    def best_ink(background)
      dark  = wcag_ratio(INK_DARK,  background)
      light = wcag_ratio(INK_LIGHT, background)
      dark >= light ? INK_DARK : INK_LIGHT
    end

    # True when the best achievable ink against `background` passes
    # WCAG AA for body text. Use this to decide whether `best_ink` is
    # safe or whether the caller should supply a palette-specific ink.
    def good_enough?(background, threshold: WCAG_AA_BODY)
      ratio = [ wcag_ratio(INK_DARK, background), wcag_ratio(INK_LIGHT, background) ].max
      ratio >= threshold
    end
  end
end
