import { Controller } from "@hotwired/stimulus"

// Onboarding plan-picker controller. Two responsibilities:
//
//   1. Visually toggle the selected card as the operator clicks Free
//      vs Pro (the underlying radios drive form submit; this just
//      paints the selected ring + ring-offset).
//   2. Inside the Pro card, swap monthly/yearly numbers + period
//      labels in place when the segmented toggle is clicked, and
//      keep the hidden `billing_period` field in sync so the form's
//      POST carries the right Stripe price ID.
//
// Targets:
//   - choiceRadio       — the two radio buttons (free + pro)
//   - planCard          — the surrounding card wrapper for each plan
//   - periodToggle      — Mensual / Anual segmented buttons (Pro only)
//   - billingPeriodInput — hidden input the segmented toggle writes to
//   - priceAmount        — element whose textContent is swapped from
//                          data-monthly / data-yearly
//   - pricePeriod        — same, for the period label / billed-note
//   - savingsBadge       — visible only in yearly mode
//
// Values:
//   - defaultPeriod ("monthly" | "yearly") — initial period when the
//     page loads (Pro card defaults to yearly per ROADMAP).
export default class extends Controller {
  static targets = [
    "choiceRadio",
    "planCard",
    "periodToggle",
    "billingPeriodInput",
    "priceAmount",
    "pricePeriod",
    "savingsBadge"
  ]

  static values = {
    defaultPeriod: { type: String, default: "yearly" }
  }

  connect() {
    this.#paintSelected()
    this.#applyPeriod(this.defaultPeriodValue)
  }

  // ── Public actions ────────────────────────────────────────────────

  // Click handler on the card wrappers. Lets the operator click the
  // whole card (not just the radio dot) to select a plan. Falls
  // through to the native radio change event so both keyboard and
  // mouse input land in the same place.
  selectPlan(event) {
    const card = event.currentTarget
    const value = card.dataset.choice
    const radio = this.choiceRadioTargets.find(r => r.value === value)
    if (radio && !radio.checked) {
      radio.checked = true
      radio.dispatchEvent(new Event("change", { bubbles: true }))
    }
    this.#paintSelected()
  }

  choiceChanged() {
    this.#paintSelected()
  }

  selectMonthly(event) {
    event?.preventDefault()
    this.#applyPeriod("monthly")
  }

  selectYearly(event) {
    event?.preventDefault()
    this.#applyPeriod("yearly")
  }

  // ── Internals ─────────────────────────────────────────────────────

  #paintSelected() {
    const selected = this.choiceRadioTargets.find(r => r.checked)?.value
    this.planCardTargets.forEach(card => {
      const isSelected = card.dataset.choice === selected
      card.dataset.selected = isSelected ? "true" : "false"
      card.setAttribute("aria-pressed", isSelected)
    })
  }

  #applyPeriod(period) {
    if (!["monthly", "yearly"].includes(period)) return

    this.periodToggleTargets.forEach(btn => {
      const matches = btn.dataset.period === period
      btn.dataset.active = matches ? "true" : "false"
      btn.setAttribute("aria-pressed", matches)
    })

    this.billingPeriodInputTargets.forEach(el => { el.value = period })
    this.priceAmountTargets.forEach(el => {
      const next = el.dataset[period]
      if (next) el.textContent = next
    })
    this.pricePeriodTargets.forEach(el => {
      const next = el.dataset[period]
      if (next) el.textContent = next
    })
    this.savingsBadgeTargets.forEach(el => {
      el.classList.toggle("hidden", period !== "yearly")
    })
  }
}
