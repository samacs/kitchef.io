// WCAG 2.1 contrast utilities — JS mirror of `Ui::Contrast` in Ruby.
// Used by storefront / account-edit previews where text color needs
// to be picked against a brand background that may change at runtime.
//
//   import { bestInk, wcagRatio } from "lib/contrast"
//   button.style.color = bestInk("#0A5A3C")      // "#F8F6F1"
//   wcagRatio("#F8F6F1", "#0A5A3C")              // ≈ 6.78
//
// Stays in sync with the Ruby constants (INK_LIGHT = bone,
// INK_DARK = warm near-black); changes to the defaults should land
// in both files.

export const INK_LIGHT = "#F8F6F1"  // bone — on dark backgrounds
export const INK_DARK  = "#0E1714"  // warm near-black — on light backgrounds

export const WCAG_AA_BODY  = 4.5
export const WCAG_AA_LARGE = 3.0

// Relative luminance per WCAG 2.1 — number 0..1.
export function relativeLuminance(hex) {
  const parts = hex.replace("#", "").match(/../g).map(h => parseInt(h, 16) / 255)
  const linear = parts.map(c =>
    c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
  )
  return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
}

// WCAG contrast ratio between two hex colors — number 1..21.
export function wcagRatio(fg, bg) {
  const lfg = relativeLuminance(fg)
  const lbg = relativeLuminance(bg)
  const l1 = Math.max(lfg, lbg)
  const l2 = Math.min(lfg, lbg)
  return (l1 + 0.05) / (l2 + 0.05)
}

// Best-of-two ink token for a given background. See `good_enough`
// before trusting the result on mid-luminance primaries (mustard,
// peach) — some palettes need a hand-tuned ink to pass AA.
export function bestInk(background) {
  const dark  = wcagRatio(INK_DARK,  background)
  const light = wcagRatio(INK_LIGHT, background)
  return dark >= light ? INK_DARK : INK_LIGHT
}

export function goodEnough(background, { threshold = WCAG_AA_BODY } = {}) {
  const ratio = Math.max(
    wcagRatio(INK_DARK,  background),
    wcagRatio(INK_LIGHT, background)
  )
  return ratio >= threshold
}
