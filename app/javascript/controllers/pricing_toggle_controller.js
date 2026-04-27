import { Controller } from "@hotwired/stimulus"

// Pricing-page billing-period toggle.
//
// Wires the "Mensual / Anual" segmented switch on the Pro card. Both
// price/period strings are rendered server-side as data-* values on
// the `priceMonthly` / `priceYearly` elements; the controller swaps
// the visible numbers in place and updates the CTA's hidden field
// (when there is one — the marketing-site cards don't have a form
// yet, but the in-app upgrade CTA in Slice 3 will).
//
// Targets:
//   - toggleMonthly / toggleYearly: the two segment buttons
//   - priceAmount: the big "$199" / "$1,990" element
//   - pricePeriod: the "/mes" / "/año" suffix
//   - savingsBadge: the "2 meses gratis" muted chip (hidden in monthly)
//   - hiddenInput (optional): a billing-period radio/hidden field on a
//     surrounding form so the toggle controls the eventual submit
//
// Values:
//   - default ("monthly" | "yearly") — initial period
//
// Events emitted:
//   - `pricing-toggle:change` with { detail: { period } } so other
//     widgets on the page (FAQ teasers, signup CTA copy) can react
//     without coupling to this controller.
export default class extends Controller {
  static targets = [
    "toggleMonthly",
    "toggleYearly",
    "priceAmount",
    "pricePeriod",
    "savingsBadge",
    "hiddenInput"
  ]

  static values = {
    default: { type: String, default: "monthly" }
  }

  connect() {
    this.#apply(this.defaultValue)
  }

  selectMonthly(event) {
    event?.preventDefault()
    this.#apply("monthly")
  }

  selectYearly(event) {
    event?.preventDefault()
    this.#apply("yearly")
  }

  // ── Internals ──────────────────────────────────────────────────────────

  #apply(period) {
    if (!["monthly", "yearly"].includes(period)) return

    this.#paintToggle(period)
    this.#paintPrices(period)
    this.#paintSavings(period)
    this.#paintHiddenInputs(period)
    this.#emitChange(period)
  }

  #paintToggle(period) {
    const monthlyOn = period === "monthly"
    if (this.hasToggleMonthlyTarget) {
      this.toggleMonthlyTarget.dataset.active = monthlyOn ? "true" : "false"
      this.toggleMonthlyTarget.setAttribute("aria-pressed", monthlyOn)
    }
    if (this.hasToggleYearlyTarget) {
      this.toggleYearlyTarget.dataset.active = !monthlyOn ? "true" : "false"
      this.toggleYearlyTarget.setAttribute("aria-pressed", !monthlyOn)
    }
  }

  #paintPrices(period) {
    this.priceAmountTargets.forEach(el => {
      const next = el.dataset[period === "monthly" ? "monthly" : "yearly"]
      if (next) el.textContent = next
    })
    this.pricePeriodTargets.forEach(el => {
      const next = el.dataset[period === "monthly" ? "monthly" : "yearly"]
      if (next) el.textContent = next
    })
  }

  #paintSavings(period) {
    this.savingsBadgeTargets.forEach(el => {
      el.classList.toggle("hidden", period !== "yearly")
    })
  }

  #paintHiddenInputs(period) {
    this.hiddenInputTargets.forEach(el => {
      el.value = period
    })
  }

  #emitChange(period) {
    this.element.dispatchEvent(new CustomEvent("pricing-toggle:change", {
      bubbles: true,
      detail: { period }
    }))
  }
}
